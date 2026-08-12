class_name Targeting
extends RefCounted
## Target selection. Every mode has a deterministic tie-break on enemy id so two
## identical runs pick the same enemy in the same tick.

const Types := preload("res://sim/sim_types.gd")


## Returns the chosen enemy, or null if nothing is in range.
## `enemies` is the live enemy array from Simulation.
static func select(tower, enemies: Array):
	var best = null
	var best_score: float = 0.0
	var range_sq: float = tower.range_squared()

	for enemy in enemies:
		if not enemy.alive or enemy.reached_goal:
			continue
		if enemy.flies and not tower.can_target_air:
			continue
		var offset: Vector3 = enemy.position - tower.position
		var distance_sq: float = offset.x * offset.x + offset.z * offset.z
		if distance_sq > range_sq:
			continue

		var score: float = _score_for(tower.target_mode, enemy, distance_sq)
		if best == null or score > best_score or (score == best_score and enemy.id < best.id):
			best = enemy
			best_score = score

	return best


## Higher score always wins, whatever the mode. Keeps the comparison in one place.
static func _score_for(mode: int, enemy, distance_sq: float) -> float:
	match mode:
		Types.TargetMode.FIRST:
			return enemy.progress()
		Types.TargetMode.LAST:
			return -enemy.progress()
		Types.TargetMode.CLOSEST:
			return -distance_sq
		Types.TargetMode.STRONGEST:
			return float(enemy.hp)
		Types.TargetMode.WEAKEST:
			return -float(enemy.hp)
		_:
			return enemy.progress()


## Everything alive within `radius` of `centre`, for splash damage.
##
## `include_air` is false for a tower that cannot target air, so a mortar shell
## landing under a Skiff does not clip it on the way past. Distance is measured
## on the XZ plane throughout, so cruise altitude never affects who is hit.
static func in_radius(enemies: Array, centre: Vector3, radius: float,
		include_air: bool = true) -> Array:
	var out: Array = []
	if radius <= 0.0:
		return out
	var radius_sq: float = radius * radius
	for enemy in enemies:
		if not enemy.alive or enemy.reached_goal:
			continue
		if enemy.flies and not include_air:
			continue
		var offset: Vector3 = enemy.position - centre
		if offset.x * offset.x + offset.z * offset.z <= radius_sq:
			out.append(enemy)
	return out
