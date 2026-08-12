class_name SimGrid
extends RefCounted
## Flat byte grid on the XZ plane. Y is always the up axis; the sim is 2D data
## rendered in 3D. Cell (0,0) sits at world origin, extending +X and +Z.

const Types := preload("res://sim/sim_types.gd")

const LEGEND_BUILDABLE := "."
const LEGEND_PATH := "#"
const LEGEND_BLOCKED := "X"
const LEGEND_SPAWN := "S"
const LEGEND_GOAL := "G"

var width: int = 0
var height: int = 0
var cell_size: float = 2.0
var cells: PackedByteArray = PackedByteArray()
var spawn: Vector2i = Vector2i(-1, -1)
var goal: Vector2i = Vector2i(-1, -1)


func _init(w: int = 0, h: int = 0, size: float = 2.0) -> void:
	cell_size = size
	resize(w, h)


func resize(w: int, h: int) -> void:
	width = maxi(w, 0)
	height = maxi(h, 0)
	cells = PackedByteArray()
	cells.resize(width * height)
	cells.fill(Types.Cell.BUILDABLE)


## Builds the grid from an ASCII layout. Rows are separated by newlines and must
## all be the same length. See LEGEND_* constants for the characters.
## Returns an empty string on success, or a human-readable error.
func load_from_layout(layout: String, size: float = 2.0) -> String:
	var rows: PackedStringArray = layout.strip_edges().split("\n", false)
	if rows.is_empty():
		return "layout is empty"
	var row_width: int = rows[0].strip_edges().length()
	if row_width == 0:
		return "layout row 0 is empty"

	resize(row_width, rows.size())
	cell_size = size
	spawn = Vector2i(-1, -1)
	goal = Vector2i(-1, -1)

	for y in rows.size():
		var row: String = rows[y].strip_edges()
		if row.length() != row_width:
			return "layout row %d has width %d, expected %d" % [y, row.length(), row_width]
		for x in row_width:
			var glyph: String = row[x]
			var cell_value: int = Types.Cell.BUILDABLE
			match glyph:
				LEGEND_BUILDABLE:
					cell_value = Types.Cell.BUILDABLE
				LEGEND_PATH:
					cell_value = Types.Cell.PATH
				LEGEND_BLOCKED:
					cell_value = Types.Cell.BLOCKED
				LEGEND_SPAWN:
					cell_value = Types.Cell.PATH
					spawn = Vector2i(x, y)
				LEGEND_GOAL:
					cell_value = Types.Cell.PATH
					goal = Vector2i(x, y)
				_:
					return "unknown layout glyph '%s' at (%d,%d)" % [glyph, x, y]
			cells[y * width + x] = cell_value

	if spawn.x < 0:
		return "layout has no spawn cell ('%s')" % LEGEND_SPAWN
	if goal.x < 0:
		return "layout has no goal cell ('%s')" % LEGEND_GOAL
	return ""


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func index_of(c: Vector2i) -> int:
	return c.y * width + c.x


func get_cell(c: Vector2i) -> int:
	if not in_bounds(c):
		return Types.Cell.BLOCKED
	return cells[index_of(c)]


func set_cell(c: Vector2i, value: int) -> void:
	if in_bounds(c):
		cells[index_of(c)] = value


func is_walkable(c: Vector2i) -> bool:
	return get_cell(c) == Types.Cell.PATH


func is_buildable(c: Vector2i) -> bool:
	return get_cell(c) == Types.Cell.BUILDABLE


## Centre of the cell, on the ground plane.
func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * cell_size, 0.0, (float(c.y) + 0.5) * cell_size)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / cell_size)), int(floor(p.z / cell_size)))


## Fixed order: right, left, down, up. Order matters for path determinism.
func neighbours4(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.append(Vector2i(c.x + 1, c.y))
	out.append(Vector2i(c.x - 1, c.y))
	out.append(Vector2i(c.x, c.y + 1))
	out.append(Vector2i(c.x, c.y - 1))
	return out


func world_extent() -> Vector3:
	return Vector3(float(width) * cell_size, 0.0, float(height) * cell_size)


## Deep copy. Uses get_script() rather than the class name so this file never
## depends on the global class cache being present (matters in fresh CI checkouts).
func duplicate_grid() -> RefCounted:
	var script: GDScript = get_script()
	var copy: RefCounted = script.new(width, height, cell_size)
	copy.cells = cells.duplicate()
	copy.spawn = spawn
	copy.goal = goal
	return copy
