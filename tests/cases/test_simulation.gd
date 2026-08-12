extends "res://tests/test_case.gd"

const Types := preload("res://sim/sim_types.gd")
const SimulationScript := preload("res://sim/simulation.gd")
const Fixtures := preload("res://tests/support/fixtures.gd")

## Test map is 10x3 with a straight 10-cell path along row 0.
## cell_size 2.0, so the route is 18 world units long.
const BUILD_CELL := Vector2i(2, 1)
const PATH_CELL := Vector2i(2, 0)


func _make(tower_overrides: Dictionary = {}, enemy_overrides: Dictionary = {}, groups: Array = []) -> Dictionary:
	var catalog = Fixtures.make_catalog(tower_overrides, enemy_overrides, groups)
	var sim = SimulationScript.new()
	var ok: bool = sim.setup(catalog.first_map(), catalog, 1)
	assert_true(ok, "setup failed: %s" % sim.setup_error)
	return {"sim": sim, "catalog": catalog}


func _advance(sim, ticks: int) -> void:
	for i in ticks:
		sim.step()


func test_setup_builds_grid_and_path() -> void:
	var sim = _make()["sim"]
	assert_eq(sim.grid.width, 10)
	assert_eq(sim.waypoints.size(), 10)
	assert_eq(sim.phase, int(Types.Phase.BUILD))
	assert_eq(sim.economy.credits, 500)
	assert_eq(sim.economy.lives, 10)


func test_setup_rejects_a_broken_map() -> void:
	var catalog = Fixtures.make_catalog({}, {}, [], {"layout_inline": "S...G"})
	var sim = SimulationScript.new()
	assert_false(sim.setup(catalog.first_map(), catalog, 1), "an unreachable goal must fail setup")
	assert_ne(sim.setup_error, "")


func test_building_costs_credits() -> void:
	var sim = _make()["sim"]
	assert_true(sim.try_build(BUILD_CELL, "test_tower"))
	assert_eq(sim.economy.credits, 400)
	assert_eq(sim.towers.size(), 1)
	assert_not_null(sim.tower_at(BUILD_CELL))


func test_cannot_build_on_the_path() -> void:
	var sim = _make()["sim"]
	assert_ne(sim.build_blocked_reason(PATH_CELL, "test_tower"), "")
	assert_false(sim.try_build(PATH_CELL, "test_tower"))
	assert_eq(sim.economy.credits, 500, "a rejected build must not charge")


func test_cannot_stack_two_towers() -> void:
	var sim = _make()["sim"]
	sim.try_build(BUILD_CELL, "test_tower")
	assert_false(sim.try_build(BUILD_CELL, "test_tower"))
	assert_eq(sim.towers.size(), 1)


func test_cannot_build_an_unknown_tower() -> void:
	var sim = _make()["sim"]
	assert_false(sim.try_build(BUILD_CELL, "no_such_tower"))


func test_cannot_build_without_credits() -> void:
	var sim = _make({"cost": 9000})["sim"]
	assert_eq(sim.build_blocked_reason(BUILD_CELL, "test_tower"), "not enough credits")
	assert_false(sim.try_build(BUILD_CELL, "test_tower"))


func test_selling_refunds_and_frees_the_cell() -> void:
	var sim = _make()["sim"]
	sim.try_build(BUILD_CELL, "test_tower")
	assert_true(sim.try_sell(BUILD_CELL))
	assert_eq(sim.economy.credits, 470, "70% of 100 credits comes back")
	assert_empty(sim.towers)
	assert_null(sim.tower_at(BUILD_CELL))
	assert_false(sim.try_sell(BUILD_CELL), "selling an empty cell does nothing")


func test_wave_must_be_started_explicitly() -> void:
	var sim = _make()["sim"]
	_advance(sim, 120)
	assert_empty(sim.enemies, "nothing spawns until the wave starts")
	assert_true(sim.start_next_wave())
	assert_eq(sim.phase, int(Types.Phase.COMBAT))
	assert_false(sim.start_next_wave(), "a wave cannot be started twice")


func test_enemy_walks_the_path_and_leaks() -> void:
	var sim = _make()["sim"]
	sim.start_next_wave()
	_advance(sim, 1)
	assert_eq(sim.enemies.size(), 1)
	var start_x: float = sim.enemies[0].position.x

	_advance(sim, 60)
	assert_gt(sim.enemies[0].position.x, start_x, "the enemy should advance along the path")

	# 18 units at 6 units/second is 3 seconds; 300 ticks is comfortably enough.
	_advance(sim, 300)
	assert_empty(sim.enemies)
	assert_eq(sim.economy.lives, 9, "a leak costs one life")


func test_leak_damage_comes_from_the_definition() -> void:
	var sim = _make({}, {"leak_damage": 4})["sim"]
	sim.start_next_wave()
	_advance(sim, 400)
	assert_eq(sim.economy.lives, 6)


func test_tower_kills_enemy_and_pays_bounty() -> void:
	var sim = _make({"damage": 50, "range_world": 8.0})["sim"]
	assert_true(sim.try_build(BUILD_CELL, "test_tower"))
	sim.start_next_wave()
	_advance(sim, 200)

	assert_empty(sim.enemies)
	assert_eq(sim.economy.lives, 10, "nothing should have leaked")
	# 500 start - 100 tower + 10 bounty + 25 wave clear bonus
	assert_eq(sim.economy.credits, 435)
	assert_eq(sim.towers[0].kills, 1)
	assert_eq(sim.towers[0].damage_dealt, 100)


func test_clearing_the_last_wave_wins() -> void:
	var sim = _make({"damage": 50, "range_world": 8.0})["sim"]
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	_advance(sim, 200)
	assert_eq(sim.phase, int(Types.Phase.WON))
	assert_true(sim.is_over())


func test_running_out_of_lives_loses() -> void:
	var groups: Array = [Fixtures.make_group("test_enemy", 12, 0, 5)]
	var sim = _make({}, {"leak_damage": 1}, groups)["sim"]
	sim.start_next_wave()
	_advance(sim, 500)
	assert_eq(sim.phase, int(Types.Phase.LOST))
	assert_eq(sim.economy.lives, 0)


func test_armour_matchup_changes_the_outcome() -> void:
	# Kinetic vs shielded is 50%, so 20 base damage lands as 10.
	var sim = _make({"damage": 20, "range_world": 8.0}, {"armor_type": 3, "max_hp": 1000})["sim"]
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	_advance(sim, 40)
	var enemy = sim.enemies[0]
	assert_eq(enemy.max_hp - enemy.hp, 20, "two shots of 10 after the shield multiplier")


func test_splash_hits_multiple_enemies() -> void:
	var groups: Array = [Fixtures.make_group("test_enemy", 3, 0, 2)]
	var sim = _make({
		"damage": 30,
		"range_world": 8.0,
		"splash_radius": 4.0,
		"fire_interval_ticks": 6,
	}, {"max_hp": 1000, "speed": 1.0}, groups)["sim"]
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	_advance(sim, 30)

	var damaged: int = 0
	for enemy in sim.enemies:
		if enemy.hp < enemy.max_hp:
			damaged += 1
	assert_gt(damaged, 1, "splash should hit more than the primary target")


func test_slow_effect_is_applied_and_expires() -> void:
	var sim = _make({
		"damage": 1,
		"range_world": 8.0,
		"slow_percent": 50,
		"slow_ticks": 60,
	}, {"max_hp": 10000})["sim"]
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	_advance(sim, 5)

	var enemy = sim.enemies[0]
	assert_eq(enemy.slow_percent, 50)
	assert_almost_eq(enemy.current_speed(), 3.0, 0.001)
	assert_lt(enemy.slow_ticks_left, 61)


func test_events_are_drained_once() -> void:
	var sim = _make()["sim"]
	sim.start_next_wave()
	_advance(sim, 2)
	var first: Array = sim.drain_events()
	assert_gt(first.size(), 0)
	assert_empty(sim.drain_events(), "draining must clear the queue")


func test_spawn_event_carries_what_the_view_needs() -> void:
	var sim = _make()["sim"]
	sim.start_next_wave()
	_advance(sim, 1)
	var spawn_events: Array = []
	for event in sim.drain_events():
		if int(event["type"]) == int(Types.Event.ENEMY_SPAWNED):
			spawn_events.append(event)
	assert_eq(spawn_events.size(), 1)
	assert_true(spawn_events[0].has("def_id"))
	assert_true(spawn_events[0].has("position"))
	assert_true(spawn_events[0].has("max_hp"))


func test_target_mode_can_be_changed_on_a_built_tower() -> void:
	var sim = _make()["sim"]
	sim.try_build(BUILD_CELL, "test_tower")
	assert_true(sim.set_target_mode(BUILD_CELL, int(Types.TargetMode.WEAKEST)))
	assert_eq(sim.tower_at(BUILD_CELL).target_mode, int(Types.TargetMode.WEAKEST))


func test_target_mode_needs_a_tower() -> void:
	var sim = _make()["sim"]
	assert_false(sim.set_target_mode(BUILD_CELL, int(Types.TargetMode.LAST)), "no tower there")


func test_target_mode_rejects_values_outside_the_enum() -> void:
	# Targeting falls back to FIRST for anything it does not recognise, so an
	# accepted-but-meaningless mode would look like it worked and never apply.
	var sim = _make()["sim"]
	sim.try_build(BUILD_CELL, "test_tower")
	var original: int = sim.tower_at(BUILD_CELL).target_mode
	assert_false(sim.set_target_mode(BUILD_CELL, 99))
	assert_false(sim.set_target_mode(BUILD_CELL, -1))
	assert_eq(sim.tower_at(BUILD_CELL).target_mode, original, "a rejected mode must not stick")


func test_target_mode_is_refused_once_the_match_is_over() -> void:
	var sim = _make({"damage": 50, "range_world": 8.0})["sim"]
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	_advance(sim, 200)
	assert_true(sim.is_over())
	assert_false(sim.set_target_mode(BUILD_CELL, int(Types.TargetMode.LAST)))


## A tower whose shells crawl slower than the enemies walk, firing into a wave
## long enough that the match cannot end mid-test. Nothing it fires can land.
func _make_stranded_shots():
	var groups: Array = [Fixtures.make_group("test_enemy", 30, 0, 60)]
	return _make({
		"fire_mode": int(Types.FireMode.PROJECTILE),
		"projectile_speed": 1.0,
		"range_world": 8.0,
		"damage": 1,
	}, {"max_hp": 100000, "leak_damage": 0}, groups)["sim"]


## Counts the projectile lifecycle events over `ticks`, draining as it goes.
func _count_projectile_events(sim, ticks: int) -> Dictionary:
	var counts: Dictionary = {"spawned": 0, "hit": 0, "expired": 0}
	for i in ticks:
		sim.step()
		for event in sim.drain_events():
			match int(event["type"]):
				Types.Event.PROJECTILE_SPAWNED:
					counts["spawned"] += 1
				Types.Event.PROJECTILE_HIT:
					counts["hit"] += 1
				Types.Event.PROJECTILE_EXPIRED:
					counts["expired"] += 1
	return counts


func test_every_projectile_ends_in_exactly_one_terminal_event() -> void:
	# PROJECTILE_SPAWNED adds a view node; only HIT and EXPIRED remove one. If
	# these counts ever stop balancing, the renderer is leaking meshes.
	var sim = _make_stranded_shots()
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	var counts: Dictionary = _count_projectile_events(sim, 900)

	assert_gt(counts["spawned"], 0, "the tower should have fired")
	assert_eq(counts["hit"] + counts["expired"] + sim.projectiles.size(), counts["spawned"],
		"every projectile is either in the air or accounted for by an event")


func test_a_projectile_that_outlives_its_fuse_reports_expiry() -> void:
	var sim = _make_stranded_shots()
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	var counts: Dictionary = _count_projectile_events(sim, 900)
	assert_gt(counts["expired"], 0, "a shot that never lands must still be retired")


func test_projectiles_in_the_air_are_retired_when_the_match_ends() -> void:
	# step() goes inert once the match is over, so a shell still in flight would
	# freeze mid-air with its view node parented for the whole results screen.
	var sim = _make({
		"fire_mode": int(Types.FireMode.PROJECTILE),
		"projectile_speed": 1.0,
		"range_world": 8.0,
		"damage": 1,
	}, {"max_hp": 100000})["sim"]
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	var counts: Dictionary = _count_projectile_events(sim, 400)

	assert_true(sim.is_over(), "the lone enemy leaks and ends the match")
	assert_gt(counts["spawned"], 0, "the tower should have fired before the enemy leaked")
	assert_empty(sim.projectiles, "nothing may still be in the air after the match ends")
	assert_eq(counts["hit"] + counts["expired"], counts["spawned"])


func test_valid_content_never_drops_a_spawn() -> void:
	var sim = _make()["sim"]
	sim.start_next_wave()
	_advance(sim, 300)
	assert_eq(sim.dropped_spawns, 0)


func test_step_is_inert_once_the_match_is_over() -> void:
	var sim = _make({"damage": 50, "range_world": 8.0})["sim"]
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	_advance(sim, 200)
	var frozen_tick: int = sim.tick
	_advance(sim, 30)
	assert_eq(sim.tick, frozen_tick, "time must stop after the match ends")
