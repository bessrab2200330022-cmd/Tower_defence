extends "res://tests/test_case.gd"

const Types := preload("res://sim/sim_types.gd")
const GridScript := preload("res://sim/grid.gd")
const Fixtures := preload("res://tests/support/fixtures.gd")

var grid


func before_each() -> void:
	grid = GridScript.new()


func test_parses_layout_dimensions() -> void:
	assert_eq(grid.load_from_layout(Fixtures.STRAIGHT_LAYOUT, 2.0), "")
	assert_eq(grid.width, 10)
	assert_eq(grid.height, 3)
	assert_eq(grid.cell_size, 2.0)


func test_finds_spawn_and_goal() -> void:
	grid.load_from_layout(Fixtures.STRAIGHT_LAYOUT, 2.0)
	assert_eq(grid.spawn, Vector2i(0, 0))
	assert_eq(grid.goal, Vector2i(9, 0))
	assert_true(grid.is_walkable(grid.spawn), "spawn must be walkable")
	assert_true(grid.is_walkable(grid.goal), "goal must be walkable")


func test_cell_classification() -> void:
	grid.load_from_layout(Fixtures.STRAIGHT_LAYOUT, 2.0)
	assert_true(grid.is_walkable(Vector2i(4, 0)))
	assert_false(grid.is_buildable(Vector2i(4, 0)), "path cells are not buildable")
	assert_true(grid.is_buildable(Vector2i(4, 1)))
	assert_false(grid.is_walkable(Vector2i(4, 1)))


func test_rejects_ragged_rows() -> void:
	var error: String = grid.load_from_layout("S###G\n....", 2.0)
	assert_ne(error, "", "ragged layouts must be rejected")


func test_rejects_unknown_glyph() -> void:
	var error: String = grid.load_from_layout("S##?G", 2.0)
	assert_ne(error, "", "unknown glyphs must be rejected")


func test_requires_spawn_and_goal() -> void:
	assert_ne(grid.load_from_layout("#####", 2.0), "", "missing spawn must be rejected")
	assert_ne(grid.load_from_layout("S####", 2.0), "", "missing goal must be rejected")


func test_world_conversion_round_trips() -> void:
	grid.load_from_layout(Fixtures.STRAIGHT_LAYOUT, 2.0)
	var cell := Vector2i(3, 2)
	var world: Vector3 = grid.cell_to_world(cell)
	assert_almost_eq(world.x, 7.0)
	assert_almost_eq(world.z, 5.0)
	assert_eq(grid.world_to_cell(world), cell)


func test_out_of_bounds_reads_as_blocked() -> void:
	grid.load_from_layout(Fixtures.STRAIGHT_LAYOUT, 2.0)
	assert_eq(grid.get_cell(Vector2i(-1, 0)), int(Types.Cell.BLOCKED))
	assert_eq(grid.get_cell(Vector2i(0, 99)), int(Types.Cell.BLOCKED))
	assert_false(grid.in_bounds(Vector2i(10, 0)))


func test_neighbour_order_is_fixed() -> void:
	grid.load_from_layout(Fixtures.STRAIGHT_LAYOUT, 2.0)
	var neighbours: Array[Vector2i] = grid.neighbours4(Vector2i(2, 1))
	assert_eq(neighbours.size(), 4)
	assert_eq(neighbours[0], Vector2i(3, 1))
	assert_eq(neighbours[1], Vector2i(1, 1))
	assert_eq(neighbours[2], Vector2i(2, 2))
	assert_eq(neighbours[3], Vector2i(2, 0))


func test_duplicate_is_independent() -> void:
	grid.load_from_layout(Fixtures.STRAIGHT_LAYOUT, 2.0)
	var copy = grid.duplicate_grid()
	copy.set_cell(Vector2i(4, 1), Types.Cell.BLOCKED)
	assert_true(grid.is_buildable(Vector2i(4, 1)), "original must not change")
	assert_false(copy.is_buildable(Vector2i(4, 1)))
