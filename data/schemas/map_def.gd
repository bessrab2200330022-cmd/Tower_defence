class_name MapDef
extends Resource
## One playable map.
##
## The board is an ASCII grid kept in its own .txt file next to this resource.
## That is deliberate: map art stays a real text file that a coding agent (and a
## human) can read and diff line by line, instead of an escaped blob inside .tres.
##
## Legend:
##   .  buildable ground
##   #  enemy path
##   X  blocked scenery
##   S  spawn (also a path cell) - exactly one
##   G  goal  (also a path cell) - exactly one
##
## Rows must all be the same length.

@export var id: String = ""
@export var display_name: String = ""
## res:// path to the .layout.txt file holding the ASCII board.
@export_file("*.txt") var layout_path: String = ""
## Optional inline fallback, used only when layout_path is empty. Prefer the file.
@export_multiline var layout_inline: String = ""
@export var cell_size: float = 2.0

@export_group("Rules")
@export var starting_credits: int = 300
@export var starting_lives: int = 20
## Paid on top of individual bounties when a wave is fully cleared. Lives here
## rather than as a constant in `sim/simulation.gd` because it is balance, and
## balance belongs in data where the harness can sweep it.
@export var wave_clear_bonus: int = 25
@export var wave_ids: PackedStringArray = PackedStringArray()

@export_group("Presentation")
@export var ground_color: Color = Color(0.20, 0.26, 0.22)
@export var path_color: Color = Color(0.42, 0.36, 0.28)
@export var blocked_color: Color = Color(0.16, 0.18, 0.20)

var _layout_cache: String = ""


## The ASCII board. Cached after the first read.
func get_layout() -> String:
	if _layout_cache != "":
		return _layout_cache
	if layout_path != "" and FileAccess.file_exists(layout_path):
		var file := FileAccess.open(layout_path, FileAccess.READ)
		if file != null:
			_layout_cache = file.get_as_text()
			file.close()
			return _layout_cache
	_layout_cache = layout_inline
	return _layout_cache


func layout_rows() -> PackedStringArray:
	return get_layout().strip_edges().split("\n", false)


func is_valid() -> String:
	if id.strip_edges() == "":
		return "map has an empty id"
	if wave_ids.is_empty():
		return "map '%s' has no wave_ids" % id
	if cell_size <= 0.0:
		return "map '%s' has non-positive cell_size" % id
	if wave_clear_bonus < 0:
		return "map '%s' has a negative wave_clear_bonus" % id
	if layout_path != "" and not FileAccess.file_exists(layout_path):
		return "map '%s' layout_path '%s' does not exist" % [id, layout_path]

	var rows: PackedStringArray = layout_rows()
	if rows.is_empty():
		return "map '%s' has an empty layout" % id
	var expected: int = rows[0].strip_edges().length()
	if expected == 0:
		return "map '%s' has a zero-width first row" % id

	var spawns: int = 0
	var goals: int = 0
	for i in rows.size():
		var row: String = rows[i].strip_edges()
		if row.length() != expected:
			return "map '%s' row %d is %d wide, expected %d" % [id, i, row.length(), expected]
		spawns += row.count("S")
		goals += row.count("G")
	if spawns != 1:
		return "map '%s' has %d spawn cells, expected exactly 1" % [id, spawns]
	if goals != 1:
		return "map '%s' has %d goal cells, expected exactly 1" % [id, goals]
	return ""
