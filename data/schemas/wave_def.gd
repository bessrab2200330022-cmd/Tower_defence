class_name WaveDef
extends Resource
## One wave: an ordered list of SpawnGroup sub-resources.
##
## `groups` is deliberately an untyped Array so the .tres files parse without
## depending on the global class cache. Elements must be SpawnGroup resources.

@export var id: String = ""
@export var display_name: String = ""
@export var groups: Array = []


func total_enemies() -> int:
	var total: int = 0
	for group in groups:
		total += maxi(int(group.count), 0)
	return total


func duration_ticks() -> int:
	var longest: int = 0
	for group in groups:
		longest = maxi(longest, group.duration_ticks())
	return longest


func is_valid() -> String:
	if id.strip_edges() == "":
		return "wave has an empty id"
	if groups.is_empty():
		return "wave '%s' has no spawn groups" % id
	for group in groups:
		if group == null:
			return "wave '%s' contains a null spawn group" % id
		var group_error: String = group.is_valid()
		if group_error != "":
			return "wave '%s': %s" % [id, group_error]
	return ""
