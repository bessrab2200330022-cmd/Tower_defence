class_name Catalog
extends RefCounted
## Loads every .tres definition under data/ into id-keyed dictionaries.
##
## Content is discovered by scanning directories, so adding a tower/enemy/wave
## is exactly one new file with no registry to update.

const TOWER_DIR := "res://data/towers"
const ENEMY_DIR := "res://data/enemies"
const WAVE_DIR := "res://data/waves"
const MAP_DIR := "res://data/maps"

var towers: Dictionary = {}
var enemies: Dictionary = {}
var waves: Dictionary = {}
var maps: Dictionary = {}
var load_errors: PackedStringArray = PackedStringArray()


## Loaded by path rather than by class name so a fresh checkout with no import
## cache still works.
static func load_default() -> RefCounted:
	var script: GDScript = load("res://data/catalog.gd")
	var catalog: RefCounted = script.new()
	catalog.reload()
	return catalog


func reload() -> void:
	# Reset first: _load_dir appends, so without this a second reload() reports
	# every error twice and validate() sees phantom problems.
	load_errors = PackedStringArray()
	towers = _load_dir(TOWER_DIR)
	enemies = _load_dir(ENEMY_DIR)
	waves = _load_dir(WAVE_DIR)
	maps = _load_dir(MAP_DIR)


func _load_dir(dir_path: String) -> Dictionary:
	var out: Dictionary = {}
	if not DirAccess.dir_exists_absolute(dir_path):
		load_errors.append("missing directory %s" % dir_path)
		return out

	var file_names: PackedStringArray = DirAccess.get_files_at(dir_path)
	# Sorted so load order - and therefore any downstream iteration - is stable.
	var names: Array = Array(file_names)
	names.sort()
	for raw_name in names:
		var file_name: String = str(raw_name)
		if file_name.ends_with(".remap"):
			file_name = file_name.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var resource = ResourceLoader.load(dir_path + "/" + file_name)
		if resource == null:
			load_errors.append("failed to load %s/%s" % [dir_path, file_name])
			continue
		var resource_id: String = str(resource.id)
		if resource_id == "":
			load_errors.append("%s/%s has an empty id" % [dir_path, file_name])
			continue
		if out.has(resource_id):
			load_errors.append("duplicate id '%s' in %s" % [resource_id, dir_path])
			continue
		out[resource_id] = resource
	return out


func get_tower(id: String):
	return towers.get(id, null)


func get_enemy(id: String):
	return enemies.get(id, null)


func get_wave(id: String):
	return waves.get(id, null)


func get_map(id: String):
	return maps.get(id, null)


## Ids for the build bar: base towers only. Upgrade tiers are loaded and
## addressable through get_tower(), but they are not purchasable directly - their
## `cost` is an increment, not a price.
func tower_ids() -> Array:
	var ids: Array = []
	for id in towers:
		if towers[id].buildable:
			ids.append(id)
	ids.sort()
	return ids


## Every tower def including upgrade tiers. For validation, tests and tooling
## that needs the whole ladder rather than the shop window.
func all_tower_ids() -> Array:
	var ids: Array = towers.keys()
	ids.sort()
	return ids


func first_map():
	var ids: Array = maps.keys()
	if ids.is_empty():
		return null
	ids.sort()
	return maps[ids[0]]


## Runs every definition's own is_valid() plus cross-reference checks.
## Returns a list of problems; empty means the content set is coherent.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for e in load_errors:
		problems.append(e)

	for id in towers:
		var message: String = towers[id].is_valid()
		if message != "":
			problems.append(message)
		# The whole safety net for a data-driven upgrade tree: a tier id that
		# does not resolve would otherwise surface as an upgrade button that
		# silently does nothing, at whatever wave the player first pressed it.
		for upgrade_id in towers[id].upgrade_ids:
			if not towers.has(str(upgrade_id)):
				problems.append("tower '%s' lists unknown upgrade '%s'" % [id, str(upgrade_id)])
			elif towers[str(upgrade_id)].buildable:
				problems.append("tower '%s' lists '%s' as an upgrade, but it is still marked buildable"
					% [id, str(upgrade_id)])
	for id in enemies:
		var message: String = enemies[id].is_valid()
		if message != "":
			problems.append(message)

	for id in waves:
		var wave = waves[id]
		var message: String = wave.is_valid()
		if message != "":
			problems.append(message)
			continue
		for group in wave.groups:
			if not enemies.has(str(group.enemy_id)):
				problems.append("wave '%s' references unknown enemy '%s'" % [id, str(group.enemy_id)])

	for id in maps:
		var map_def = maps[id]
		var message: String = map_def.is_valid()
		if message != "":
			problems.append(message)
			continue
		for wave_id in map_def.wave_ids:
			if not waves.has(str(wave_id)):
				problems.append("map '%s' references unknown wave '%s'" % [id, str(wave_id)])

	return problems
