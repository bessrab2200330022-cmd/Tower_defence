class_name ProjectileState
extends RefCounted
## An in-flight shot. Homes on its target; detonates at the last known position
## if the target dies first, so splash still lands where the player expects.

var id: int = 0
var owner_tower_id: int = 0
var target_enemy_id: int = -1

var position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var speed: float = 30.0

var damage: int = 0
var damage_type: int = 0
var splash_radius: float = 0.0
var slow_percent: int = 0
var slow_ticks: int = 0

var alive: bool = true
## Safety valve so a projectile can never live forever if its target vanishes.
var ticks_left: int = 300


func step_towards(destination: Vector3, delta: float) -> bool:
	target_position = destination
	var to_target: Vector3 = destination - position
	var distance: float = to_target.length()
	var travel: float = speed * delta
	if distance <= travel or distance <= 0.0001:
		position = destination
		return true
	position += to_target / distance * travel
	return false
