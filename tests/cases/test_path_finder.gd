extends "res://tests/test_case.gd"

const GridScript := preload("res://sim/grid.gd")
const PathFinderScript := preload("res://sim/path_finder.gd")
const Fixtures := preload("res://tests/support/fixtures.gd")

var grid
var finder


func before_each() -> void:
	grid = GridScript.new()
	finder = PathFinderScript.new()


func test_finds_straight_path() -> void:
	grid.load_from_layout(Fixtures.STRAIGHT_LAYOUT, 2.0)
	assert_true(finder.build(grid, grid.spawn, grid.goal), finder.last_error)
	assert_eq(finder.path.size(), 10)
	assert_eq(finder.path[0], Vector2i(0, 0))
	assert_eq(finder.path[9], Vector2i(9, 0))


func test_path_is_contiguous() -> void:
	grid.load_from_layout(Fixtures.STRAIGHT_LAYOUT, 2.0)
	finder.build(grid, grid.spawn, grid.goal)
	for i in range(1, finder.path.size()):
		var step: Vector2i = finder.path[i] - finder.path[i - 1]
		assert_eq(absi(step.x) + absi(step.y), 1, "step %d is not a single cell move" % i)


func test_distance_field_counts_steps_to_goal() -> void:
	grid.load_from_layout(Fixtures.STRAIGHT_LAYOUT, 2.0)
	finder.build(grid, grid.spawn, grid.goal)
	assert_eq(finder.steps_to_goal(grid, Vector2i(9, 0)), 0)
	assert_eq(finder.steps_to_goal(grid, Vector2i(0, 0)), 9)
	assert_eq(finder.steps_to_goal(grid, Vector2i(5, 0)), 4)
	assert_eq(finder.steps_to_goal(grid, Vector2i(5, 1)), PathFinderScript.UNREACHABLE)


func test_reports_unreachable_goal() -> void:
	grid.load_from_layout(Fixtures.BLOCKED_LAYOUT, 2.0)
	assert_false(finder.build(grid, grid.spawn, grid.goal))
	assert_ne(finder.last_error, "")
	assert_empty(finder.path)


func test_world_length_matches_cell_size() -> void:
	grid.load_from_layout(Fixtures.STRAIGHT_LAYOUT, 2.0)
	finder.build(grid, grid.spawn, grid.goal)
	assert_almost_eq(finder.world_length(grid), 18.0)


func test_shipped_map_has_a_valid_route() -> void:
	var map_def = load("res://data/maps/crossing.tres")
	assert_not_null(map_def, "crossing.tres must load")
	assert_eq(map_def.is_valid(), "")
	assert_eq(grid.load_from_layout(map_def.get_layout(), map_def.cell_size), "")
	assert_true(finder.build(grid, grid.spawn, grid.goal), finder.last_error)
	assert_gt(finder.path.size(), 40, "the shipped map should be a long route")


func test_build_is_deterministic() -> void:
	var map_def = load("res://data/maps/crossing.tres")
	grid.load_from_layout(map_def.get_layout(), map_def.cell_size)
	var second = PathFinderScript.new()
	finder.build(grid, grid.spawn, grid.goal)
	second.build(grid, grid.spawn, grid.goal)
	assert_eq(str(finder.path), str(second.path), "same input must yield the same path")
