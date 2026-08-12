class_name TowerState
extends RefCounted
## Plain data for a placed tower.

var id: int = 0
var def_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var position: Vector3 = Vector3.ZERO

var range_world: float = 8.0
var damage: int = 10
var damage_type: int = 0
var fire_interval_ticks: int = 30
var cooldown_ticks: int = 0
var fire_mode: int = 0
var projectile_speed: float = 30.0
var splash_radius: float = 0.0
var slow_percent: int = 0
var slow_ticks: int = 0
var target_mode: int = 0
## False for every Frost Mortar tier. Fliers are invisible to such a tower:
## it will not select one, and its splash will not touch one.
var can_target_air: bool = true

var credits_invested: int = 0
var kills: int = 0
var damage_dealt: int = 0
## Facing angle in radians, kept in the sim so replays reproduce turret rotation.
var facing: float = 0.0


func range_squared() -> float:
	return range_world * range_world


func is_ready() -> bool:
	return cooldown_ticks <= 0


func tick_cooldown() -> void:
	if cooldown_ticks > 0:
		cooldown_ticks -= 1


func start_cooldown() -> void:
	cooldown_ticks = maxi(fire_interval_ticks, 1)


func shots_per_second() -> float:
	return 60.0 / float(maxi(fire_interval_ticks, 1))


## Headline number for the build menu. Ignores armour matchups on purpose.
func nominal_dps() -> float:
	return float(damage) * shots_per_second()
