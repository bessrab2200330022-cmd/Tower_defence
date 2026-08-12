extends Node3D
## Floating damage numbers, pooled.
##
## ENEMY_DAMAGED already carries `amount`, `hp`, `max_hp` and `position`, so
## nothing in `sim/` changes to support this - which is the whole reason it is
## cheap enough to be worth doing.
##
## Same discipline as game/views/effects.gd: a fixed pool, hand-ticked from
## step() on the render delta, never a Tween or a Timer. A wave being watched at
## 4x produces damage events four times as fast, and a pool that grows on demand
## would quietly become a few thousand Label3D nodes.

## Labels are recycled round-robin. Twenty-eight is comfortably more than can be
## read at once, which is the real limit - past that it is visual noise and the
## right behaviour is to overwrite the oldest.
const POOL_SIZE: int = 28

const RISE: float = 1.35
const LIFETIME: float = 0.72
## Damage below this fraction of the enemy's max HP is a chip; at or above it the
## number is bigger and warmer. Without a split every hit looks equally
## important, which is exactly the information a damage number should carry.
const HEAVY_FRACTION: float = 0.22

## Numbers are shown on the simulation's own scale, matching the HUD, which
## already prints raw values ("225 dps"). If the 10x scale is ever hidden from
## the player this is the single place that changes.
const DISPLAY_DIVISOR: int = 1

const COLOR_LIGHT := Color(1.0, 0.95, 0.82)
const COLOR_HEAVY := Color(1.0, 0.72, 0.32)
## Green and signed, so a heal cannot be misread as a small hit at a glance.
const COLOR_HEAL := Color(0.45, 1.0, 0.62)

## Sideways drift, from a fixed table rather than randf(), so two runs of the
## same match produce the same picture and a screenshot comparison stays
## meaningful. Same reasoning as effects.gd's debris directions.
const DRIFT: Array = [-0.42, 0.31, -0.16, 0.47, -0.30, 0.12, 0.38, -0.51]

var _labels: Array[Label3D] = []
var _life: PackedFloat32Array = PackedFloat32Array()
var _origin: PackedVector3Array = PackedVector3Array()
var _drift: PackedFloat32Array = PackedFloat32Array()
var _next: int = 0


func build() -> void:
	for i in POOL_SIZE:
		var label := Label3D.new()
		label.name = "Damage%d" % i
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# Read through the terrain it is standing behind. A damage number that
		# can be occluded is a damage number you miss.
		label.no_depth_test = true
		# Fixed size, so a number stays readable whether the camera is at the
		# 10-unit zoom limit or the 80-unit one. pixel_size then reads as a
		# screen-space scale rather than a world one.
		label.fixed_size = true
		label.font_size = 48
		label.outline_size = 6
		label.outline_modulate = Color(0.05, 0.04, 0.06, 0.9)
		label.visible = false
		add_child(label)
		_labels.append(label)
		_life.append(0.0)
		_origin.append(Vector3.ZERO)
		_drift.append(0.0)


## One ENEMY_DAMAGED event. Zero-damage hits are dropped: the sim emits them for
## a shot that was fully absorbed, and "0" floating off an enemy reads as a bug.
func show_hit(at: Vector3, amount: int, max_hp: int) -> void:
	if amount <= 0 or _labels.is_empty():
		return

	var index: int = _next
	_next = (_next + 1) % _labels.size()

	var heavy: bool = max_hp > 0 and float(amount) / float(max_hp) >= HEAVY_FRACTION
	var label: Label3D = _labels[index]
	label.text = str(maxi(amount / DISPLAY_DIVISOR, 1))
	label.modulate = COLOR_HEAVY if heavy else COLOR_LIGHT
	label.pixel_size = 0.00130 if heavy else 0.00100
	label.visible = true

	_life[index] = LIFETIME
	_origin[index] = at
	_drift[index] = DRIFT[index % DRIFT.size()]
	label.position = at


## A Mender pulse landing. Same pool as damage - a heal and a hit on the same
## enemy in the same frame should queue against each other rather than be drawn
## by two systems with independent budgets.
func show_heal(at: Vector3, amount: int) -> void:
	if amount <= 0 or _labels.is_empty():
		return
	var index: int = _next
	_next = (_next + 1) % _labels.size()

	var label: Label3D = _labels[index]
	label.text = "+%d" % maxi(amount / DISPLAY_DIVISOR, 1)
	label.modulate = COLOR_HEAL
	label.pixel_size = 0.00110
	label.visible = true

	_life[index] = LIFETIME
	_origin[index] = at
	_drift[index] = DRIFT[index % DRIFT.size()]
	label.position = at


## Driven from game/level.gd::sync() on the render delta, like effects.gd.
func step(delta: float) -> void:
	for i in _labels.size():
		if _life[i] <= 0.0:
			continue
		_life[i] = maxf(_life[i] - delta, 0.0)
		var label: Label3D = _labels[i]
		if _life[i] <= 0.0:
			label.visible = false
			continue

		# age runs 0 -> 1 over the life.
		var age: float = 1.0 - _life[i] / LIFETIME
		# Decelerating rise: most of the travel happens early, so the number
		# arrives quickly and then hangs where it can be read.
		var lift: float = RISE * (1.0 - (1.0 - age) * (1.0 - age))
		label.position = _origin[i] + Vector3(_drift[i] * age, lift, 0.0)
		# Hold full opacity for the first third, then fade. Fading from frame one
		# makes every number look faint.
		label.modulate.a = 1.0 - clampf((age - 0.35) / 0.65, 0.0, 1.0)


func live_count() -> int:
	var live: int = 0
	for value in _life:
		if value > 0.0:
			live += 1
	return live
