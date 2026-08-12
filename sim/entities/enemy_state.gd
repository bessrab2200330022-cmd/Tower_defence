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
## Monotonic progress along the route, in world units.
var distance_travelled: float = 0.0
## Length of the route this enemy is walking or flying. Fliers take a much
## shorter chord than walkers take path, so raw distance is not comparable
## between them - see progress().
var route_length: float = 1.0

var alive: bool = true
var reached_goal: bool = false

## Status effects. Slow is a percentage reduction, 0..90.
var slow_percent: int = 0
var slow_ticks_left: int = 0

## Ability, copied from the def at spawn so the sim never reaches back into the
## catalog mid-tick. See SimTypes.Ability.
var ability: int = 0
var ability_radius: float = 0.0
var ability_percent: int = 100
var ability_amount: int = 0
var ability_interval: int = 0
var spawn_on_death: PackedStringArray = PackedStringArray()
## Next tick this enemy's ability fires. Anchored on the enemy's OWN spawn tick,
## not on a global clock, so two Menders that spawned 40 ticks apart pulse 40
## ticks apart forever. ROADMAP trap 2 is this going wrong once already.
var ability_next_tick: int = 0

## Flies a straight spawn-goal chord instead of walking the path.
var flies: bool = false
## Recomputed every tick from aura sources, in fixed entity-array order. Kept on
## the entity rather than in a side dictionary so it lands in snapshot_hash with
## everything else about this enemy.
var aura_percent: int = 100
## Which aura-bearer is protecting this enemy, and what the view was last
## told. AURA_APPLIED is edge-triggered off the second of these.
var aura_source_id: int = 0
var aura_reported_percent: int = 100


## Percent of computed damage this enemy takes. 100 when unprotected.
func incoming_percent() -> int:
	return aura_percent


## Fraction of this enemy's own route completed, 0..1. FIRST and LAST target
## modes score on THIS rather than on raw distance: a Skiff's chord is a third
## of a walker's tour, so under raw distance every ground enemy on the board
## outranked every flier and a tower on FIRST would never once select a Skiff -
## which made fliers unanswerable rather than merely hard. For a board with one
## lane this is the same ordering as raw distance, since it differs only by a
## constant divisor.
func progress() -> float:
	return distance_travelled / maxf(route_length, 0.001)


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


## Restores hit points, never above max_hp. Returns the amount actually healed,
## which is what the view needs - a pulse that healed 0 should draw no glow.
func heal(amount: int) -> int:
	if not alive or amount <= 0:
		return 0
	var healed: int = mini(amount, max_hp - hp)
	hp += healed
	return healed


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
