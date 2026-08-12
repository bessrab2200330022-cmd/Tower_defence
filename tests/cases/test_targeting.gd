extends "res://tests/test_case.gd"

const Types := preload("res://sim/sim_types.gd")
const TargetingScript := preload("res://sim/targeting.gd")
const Fixtures := preload("res://tests/support/fixtures.gd")

var enemies: Array


func before_each() -> void:
	# Three enemies in a line, 2 units apart, increasing path progress.
	enemies = [
		Fixtures.make_enemy_state(1, Vector3(2.0, 0.0, 0.0), 100, 10.0),
		Fixtures.make_enemy_state(2, Vector3(4.0, 0.0, 0.0), 40, 20.0),
		Fixtures.make_enemy_state(3, Vector3(6.0, 0.0, 0.0), 250, 30.0),
	]


func _tower(mode: int, range_world: float = 10.0):
	return Fixtures.make_tower_state(Vector3.ZERO, range_world, mode)


func test_first_picks_furthest_along_path() -> void:
	var target = TargetingScript.select(_tower(Types.TargetMode.FIRST), enemies)
	assert_not_null(target)
	assert_eq(target.id, 3)


func test_last_picks_least_far_along_path() -> void:
	var target = TargetingScript.select(_tower(Types.TargetMode.LAST), enemies)
	assert_eq(target.id, 1)


func test_closest_picks_nearest() -> void:
	var target = TargetingScript.select(_tower(Types.TargetMode.CLOSEST), enemies)
	assert_eq(target.id, 1)


func test_strongest_picks_highest_hp() -> void:
	var target = TargetingScript.select(_tower(Types.TargetMode.STRONGEST), enemies)
	assert_eq(target.id, 3)


func test_weakest_picks_lowest_hp() -> void:
	var target = TargetingScript.select(_tower(Types.TargetMode.WEAKEST), enemies)
	assert_eq(target.id, 2)


func test_range_is_respected() -> void:
	var target = TargetingScript.select(_tower(Types.TargetMode.FIRST, 3.0), enemies)
	assert_not_null(target)
	assert_eq(target.id, 1, "only the enemy at 2 units is inside a 3 unit range")


func test_returns_null_when_nothing_in_range() -> void:
	assert_null(TargetingScript.select(_tower(Types.TargetMode.FIRST, 1.0), enemies))


func test_ignores_dead_and_leaked_enemies() -> void:
	enemies[2].alive = false
	enemies[1].reached_goal = true
	var target = TargetingScript.select(_tower(Types.TargetMode.FIRST), enemies)
	assert_eq(target.id, 1)


func test_ties_break_on_lowest_id() -> void:
	var tied: Array = [
		Fixtures.make_enemy_state(9, Vector3(3.0, 0.0, 0.0), 100, 5.0),
		Fixtures.make_enemy_state(4, Vector3(0.0, 0.0, 3.0), 100, 5.0),
	]
	var target = TargetingScript.select(_tower(Types.TargetMode.FIRST), tied)
	assert_eq(target.id, 4, "identical scores must resolve to the lower id")


func test_height_is_ignored_for_range() -> void:
	var airborne: Array = [Fixtures.make_enemy_state(1, Vector3(2.0, 50.0, 0.0), 100, 1.0)]
	var target = TargetingScript.select(_tower(Types.TargetMode.FIRST, 3.0), airborne)
	assert_not_null(target, "range is measured on the ground plane only")


func test_in_radius_collects_splash_victims() -> void:
	var hit: Array = TargetingScript.in_radius(enemies, Vector3(4.0, 0.0, 0.0), 2.5)
	assert_eq(hit.size(), 3)
	var narrow: Array = TargetingScript.in_radius(enemies, Vector3(4.0, 0.0, 0.0), 1.0)
	assert_eq(narrow.size(), 1)
	assert_empty(TargetingScript.in_radius(enemies, Vector3.ZERO, 0.0))
