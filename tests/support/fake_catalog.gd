extends RefCounted
## Same surface as data/catalog.gd, filled by hand in tests.
## Lets simulation tests pin exact numbers instead of depending on live balance
## data - so a balance tweak never breaks a logic test.

var towers: Dictionary = {}
var enemies: Dictionary = {}
var waves: Dictionary = {}
var maps: Dictionary = {}


func get_tower(id: String):
	return towers.get(id, null)


func get_enemy(id: String):
	return enemies.get(id, null)


func get_wave(id: String):
	return waves.get(id, null)


func get_map(id: String):
	return maps.get(id, null)


func tower_ids() -> Array:
	var ids: Array = towers.keys()
	ids.sort()
	return ids


func first_map():
	var ids: Array = maps.keys()
	if ids.is_empty():
		return null
	ids.sort()
	return maps[ids[0]]


func validate() -> PackedStringArray:
	return PackedStringArray()
