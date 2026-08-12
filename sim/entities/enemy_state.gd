class_name EnemyState
extends RefCounted
## Plain data. No behaviour beyond trivial helpers, no engine dependencies.

var id: int = 0
var def_id: String = ""

var max_hp: int = 1
var hp: int = 1
var base_speed: float = 4.0
var armor_type: int = 0
var bounty: int = 0
var leak_damage: int = 1

## World-space position on the ground plane (y is always 0 in the sim).
var position: Vector3 = Vector3.ZERO
## Index of the waypoint the enemy is currently walking towards.
var path_index: int = 0
## Monotonic progress along the path, in world units. Used by FIRST/LAST targeting.
var distance_travelled: float = 0.0

var alive: bool = true
var reached_goal: bool = false

## Status effects. Slow is a percentage reduction, 0..90.
var slow_percent: int = 0
var slow_ticks_left: int = 0


func current_speed() -> float:
	if slow_ticks_left <= 0:
		return base_speed
	var pct: int = clampi(slow_percent, 0, 90)
	return base_speed * float(100 - pct) / 100.0


func apply_slow(percent: int, ticks: int) -> void:
	# Strongest slow wins; equal slows refresh the duration.
	if percent > slow_percent or (percent == slow_percent and ticks > slow_ticks_left):
		slow_percent = clampi(percent, 0, 90)
		slow_ticks_left = maxi(ticks, 0)


func tick_status() -> void:
	if slow_ticks_left > 0:
		slow_ticks_left -= 1
		if slow_ticks_left == 0:
			slow_percent = 0


## Returns damage actually dealt (never more than remaining HP).
func take_damage(amount: int) -> int:
	if not alive or amount <= 0:
		return 0
	var dealt: int = mini(amount, hp)
	hp -= dealt
	if hp <= 0:
		hp = 0
		alive = false
	return dealt


func health_fraction() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)
