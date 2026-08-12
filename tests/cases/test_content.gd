extends "res://tests/test_case.gd"
## Guards the shipped .tres content. These catch typos in data files, which is
## the most common way a data-driven project breaks.

const Types := preload("res://sim/sim_types.gd")
const CatalogScript := preload("res://data/catalog.gd")
const SimulationScript := preload("res://sim/simulation.gd")

var catalog


func before_each() -> void:
	catalog = CatalogScript.load_default()


func test_catalog_loads_without_errors() -> void:
	assert_empty(catalog.load_errors, str(catalog.load_errors))


func test_content_cross_references_resolve() -> void:
	var problems: PackedStringArray = catalog.validate()
	assert_empty(problems, str(problems))


func test_expected_content_is_present() -> void:
	assert_gt(catalog.towers.size(), 2, "at least three towers ship with the slice")
	assert_gt(catalog.enemies.size(), 3, "at least four enemy types ship with the slice")
	assert_gt(catalog.waves.size(), 4, "at least five waves ship with the slice")
	assert_gt(catalog.maps.size(), 0)


func test_every_damage_type_is_represented() -> void:
	var seen: Dictionary = {}
	for id in catalog.towers:
		seen[catalog.towers[id].damage_type] = true
	assert_true(seen.has(int(Types.DamageType.KINETIC)), "no kinetic tower")
	assert_true(seen.has(int(Types.DamageType.ENERGY)), "no energy tower")
	assert_true(seen.has(int(Types.DamageType.EXPLOSIVE)), "no explosive tower")


func test_every_armour_type_is_represented() -> void:
	var seen: Dictionary = {}
	for id in catalog.enemies:
		seen[catalog.enemies[id].armor_type] = true
	assert_eq(seen.size(), 4, "each armour type needs at least one enemy to justify it")


func test_tower_ids_are_sorted_and_stable() -> void:
	var first: Array = catalog.tower_ids()
	var second: Array = catalog.tower_ids()
	assert_eq(str(first), str(second), "build bar order must not shuffle between frames")


func test_every_shipped_map_starts_a_simulation() -> void:
	# MapDef.is_valid() checks the ASCII shape but never runs the pathfinder, so
	# a board whose route is severed passes validation and only fails here.
	# Every map has to boot, not just the one the menu happens to open first.
	assert_gt(catalog.maps.size(), 0)
	for id in catalog.maps:
		var map_def = catalog.maps[id]
		var sim = SimulationScript.new()
		assert_true(sim.setup(map_def, catalog, 20260810),
			"map '%s' failed setup: %s" % [id, sim.setup_error])
		assert_gt(sim.waypoints.size(), 1, "map '%s' has a degenerate path" % id)
		assert_eq(sim.economy.credits, map_def.starting_credits)


func test_the_opening_map_is_a_real_board() -> void:
	var map_def = catalog.first_map()
	assert_not_null(map_def)
	var sim = SimulationScript.new()
	assert_true(sim.setup(map_def, catalog, 20260810), sim.setup_error)
	assert_gt(sim.waypoints.size(), 40)


func test_first_wave_is_survivable_with_two_towers() -> void:
	# A smoke test for balance drift: the opening wave should not be a wall.
	var sim = SimulationScript.new()
	assert_true(sim.setup(catalog.first_map(), catalog, 1), sim.setup_error)
	var built: int = 0
	for cell in [Vector2i(2, 2), Vector2i(4, 2), Vector2i(16, 5)]:
		if sim.try_build(cell, "arc_cannon"):
			built += 1
	assert_gt(built, 1, "the opening map must have buildable ground near the path")

	sim.start_next_wave()
	for i in 4000:
		sim.step()
		if sim.phase != int(Types.Phase.COMBAT):
			break
	assert_ne(sim.phase, int(Types.Phase.COMBAT), "wave 1 should resolve within 4000 ticks")
	assert_gt(sim.economy.lives, 0, "wave 1 should not end the run")


func test_first_wave_is_not_trivially_free() -> void:
	# With no towers at all, the player must actually lose ground.
	var sim = SimulationScript.new()
	sim.setup(catalog.first_map(), catalog, 1)
	sim.start_next_wave()
	for i in 4000:
		sim.step()
		if sim.phase != int(Types.Phase.COMBAT):
			break
	assert_lt(sim.economy.lives, sim.map_def.starting_lives, "undefended waves must cost lives")
