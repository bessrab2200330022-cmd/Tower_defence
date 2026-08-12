extends "res://tests/test_case.gd"
## Enemy abilities (ROADMAP 2.6) and the air lane (2.5).
##
## Three of the four abilities mutate entity state outside the damage path, so
## most of what matters here is determinism: a replay that diverges on a healed
## hit point or an aura membership diverges silently, several seconds after the
## cause.

const Types := preload("res://sim/sim_types.gd")
const SimulationScript := preload("res://sim/simulation.gd")
const DamageScript := preload("res://sim/damage.gd")
const CatalogScript := preload("res://data/catalog.gd")
const Fixtures := preload("res://tests/support/fixtures.gd")
const FakeCatalogScript := preload("res://tests/support/fake_catalog.gd")
const EnemyDefScript := preload("res://data/schemas/enemy_def.gd")

const BUILD_CELL := Vector2i(2, 1)


## A catalog with a plain enemy plus one extra def, so ability interactions can
## be built without leaning on shipped balance.
func _catalog_with(extra_defs: Array, groups: Array, tower_overrides: Dictionary = {},
		enemy_overrides: Dictionary = {}, map_overrides: Dictionary = {}):
	var catalog = FakeCatalogScript.new()
	var tower = Fixtures.make_tower(tower_overrides)
	var enemy = Fixtures.make_enemy(enemy_overrides)
	catalog.towers[tower.id] = tower
	catalog.enemies[enemy.id] = enemy
	for def in extra_defs:
		catalog.enemies[def.id] = def
	var wave = Fixtures.make_wave("test_wave", groups)
	catalog.waves[wave.id] = wave
	var map_def = Fixtures.make_map(map_overrides)
	catalog.maps[map_def.id] = map_def
	return catalog


func _make_ability_def(id: String, overrides: Dictionary):
	var def = EnemyDefScript.new()
	def.id = id
	def.display_name = id
	def.max_hp = 1000
	def.speed = 3.0
	def.armor_type = 1
	def.bounty = 10
	def.leak_damage = 1
	for key in overrides:
		def.set(key, overrides[key])
	return def


func _sim(catalog):
	var sim = SimulationScript.new()
	assert_true(sim.setup(catalog.first_map(), catalog, 1), sim.setup_error)
	return sim


func _drain(sim, event_type: int) -> Array:
	var out: Array = []
	for event in sim.drain_events():
		if int(event["type"]) == event_type:
			out.append(event)
	return out


func _enemy_with_def(sim, def_id: String):
	for enemy in sim.enemies:
		if enemy.def_id == def_id:
			return enemy
	return null


# ---------------------------------------------------------------------------
# AURA - the fold must be a single division
# ---------------------------------------------------------------------------

func test_aura_folds_into_one_division() -> void:
	# 100 base, medium armour (100%), 60% aura. One division gives 60; two
	# divisions would also give 60 here, so pick numbers where they differ:
	# 105 x 70% x 60% = 44.1 -> 44 in one division. Two divisions floor to
	# 73 then 43, quietly handing the target an extra point of protection.
	assert_eq(DamageScript.compute_with_aura(105, Types.DamageType.KINETIC,
		Types.ArmorType.HEAVY, 60), 44)
	var two_step: int = DamageScript.compute(105, Types.DamageType.KINETIC,
		Types.ArmorType.HEAVY) * 60 / 100
	assert_eq(two_step, 43, "the naive two-division result, for contrast")


func test_aura_percent_of_100_is_identical_to_no_aura() -> void:
	for armour in 4:
		for base in [7, 40, 90, 340, 1180]:
			assert_eq(DamageScript.compute_with_aura(base, Types.DamageType.ENERGY, armour, 100),
				DamageScript.compute(base, Types.DamageType.ENERGY, armour))


func test_splash_folds_armour_falloff_and_aura_together() -> void:
	assert_eq(DamageScript.compute_splash_with_aura(200, Types.DamageType.EXPLOSIVE,
		Types.ArmorType.LIGHT, 100, 100),
		DamageScript.compute_splash(200, Types.DamageType.EXPLOSIVE, Types.ArmorType.LIGHT, 100))
	# 200 x 130% x 50% x 60% = 78
	assert_eq(DamageScript.compute_splash_with_aura(200, Types.DamageType.EXPLOSIVE,
		Types.ArmorType.LIGHT, 50, 60), 78)


func test_aura_protects_allies_in_radius_but_never_its_bearer() -> void:
	var warden = _make_ability_def("warden", {"ability": Types.Ability.AURA,
		"ability_radius": 4.0, "ability_percent": 60, "max_hp": 100000, "speed": 3.0})
	var catalog = _catalog_with([warden],
		[Fixtures.make_group("warden", 1, 0, 30), Fixtures.make_group("test_enemy", 1, 0, 30)],
		{}, {"max_hp": 100000, "speed": 3.0})
	var sim = _sim(catalog)
	sim.start_next_wave()
	sim.step()

	var ally = _enemy_with_def(sim, "test_enemy")
	var bearer = _enemy_with_def(sim, "warden")
	assert_not_null(ally)
	assert_eq(ally.aura_percent, 60, "an ally beside the Warden is protected")
	assert_eq(bearer.aura_percent, 100, "the Warden never protects itself")


func test_two_auras_do_not_stack() -> void:
	var warden = _make_ability_def("warden", {"ability": Types.Ability.AURA,
		"ability_radius": 6.0, "ability_percent": 60, "max_hp": 100000, "speed": 3.0})
	var catalog = _catalog_with([warden],
		[Fixtures.make_group("warden", 2, 0, 1), Fixtures.make_group("test_enemy", 1, 0, 1)],
		{}, {"max_hp": 100000, "speed": 3.0})
	var sim = _sim(catalog)
	sim.start_next_wave()
	for i in 4:
		sim.step()

	var ally = _enemy_with_def(sim, "test_enemy")
	assert_not_null(ally)
	assert_eq(ally.aura_percent, 60, "overlapping auras apply once, not 60%% of 60%%")
	for enemy in sim.enemies:
		if enemy.ability == Types.Ability.AURA:
			assert_eq(enemy.aura_percent, 100, "aura-bearers never protect each other")


func test_aura_falls_away_when_the_bearer_dies() -> void:
	# Enough HP to survive a few shots, so the test can observe the aura BEFORE
	# it observes the aura lifting.
	var warden = _make_ability_def("warden", {"ability": Types.Ability.AURA,
		"ability_radius": 6.0, "ability_percent": 60, "max_hp": 1500, "speed": 0.1})
	var catalog = _catalog_with([warden],
		[Fixtures.make_group("warden", 1, 0, 1), Fixtures.make_group("test_enemy", 1, 0, 1)],
		{"damage": 500, "range_world": 9.0, "fire_interval_ticks": 5},
		{"max_hp": 100000, "speed": 0.1})
	var sim = _sim(catalog)
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	for i in 3:
		sim.step()
	var ally = _enemy_with_def(sim, "test_enemy")
	assert_eq(ally.aura_percent, 60)

	for i in 40:
		sim.step()
	assert_null(_enemy_with_def(sim, "warden"), "the Warden should be dead")
	assert_eq(ally.aura_percent, 100, "protection must lift the moment the bearer dies")


func test_aura_applied_is_edge_triggered() -> void:
	var warden = _make_ability_def("warden", {"ability": Types.Ability.AURA,
		"ability_radius": 6.0, "ability_percent": 60, "max_hp": 100000, "speed": 3.0})
	var catalog = _catalog_with([warden],
		[Fixtures.make_group("warden", 1, 0, 1), Fixtures.make_group("test_enemy", 1, 0, 1)],
		{}, {"max_hp": 100000, "speed": 3.0})
	var sim = _sim(catalog)
	sim.start_next_wave()
	for i in 3:
		sim.step()
	sim.drain_events()

	for i in 20:
		sim.step()
	assert_empty(_drain(sim, Types.Event.AURA_APPLIED),
		"steady-state protection must not re-emit every tick")


# ---------------------------------------------------------------------------
# HEAL_PULSE
# ---------------------------------------------------------------------------

func _mender_catalog(interval: int = 120):
	var mender = _make_ability_def("mender", {"ability": Types.Ability.HEAL_PULSE,
		"ability_radius": 4.5, "ability_amount": 300, "ability_interval": interval,
		"max_hp": 100000, "speed": 3.0})
	# The ally is listed first so it spawns with the lower id and FIRST targeting
	# shoots it rather than the Mender - otherwise nothing is ever wounded and
	# there is nothing for a pulse to heal.
	return _catalog_with([mender],
		[Fixtures.make_group("test_enemy", 1, 0, 1), Fixtures.make_group("mender", 1, 0, 1)],
		# One big hit early, then a long silence: sustained fire would simply
		# out-damage the pulse and the heal would be invisible in the totals.
		{"damage": 800, "range_world": 9.0, "fire_interval_ticks": 500},
		{"max_hp": 5000, "speed": 3.0})


func test_heal_pulse_restores_hp_and_emits_the_event() -> void:
	var sim = _sim(_mender_catalog())
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	for i in 60:
		sim.step()
	var ally = _enemy_with_def(sim, "test_enemy")
	assert_lt(ally.hp, ally.max_hp, "the tower should have chipped it first")
	var wounded: int = ally.hp
	sim.drain_events()

	for i in 70:
		sim.step()
	var healed: Array = _drain(sim, Types.Event.ENEMY_HEALED)
	assert_gt(healed.size(), 0, "a pulse should have landed by tick 130")
	assert_eq(int(healed[0]["enemy_id"]), ally.id)
	assert_gt(int(healed[0]["amount"]), 0)
	assert_eq(int(healed[0]["hp"]), ally.hp)
	assert_gt(ally.hp, wounded)


func test_heal_never_exceeds_max_hp() -> void:
	var sim = _sim(_mender_catalog(30))
	sim.start_next_wave()
	for i in 200:
		sim.step()
	for enemy in sim.enemies:
		assert_lt(enemy.hp, enemy.max_hp + 1, "'%s' healed past its cap" % enemy.def_id)


func test_a_mender_heals_neither_itself_nor_another_mender() -> void:
	var mender = _make_ability_def("mender", {"ability": Types.Ability.HEAL_PULSE,
		"ability_radius": 6.0, "ability_amount": 300, "ability_interval": 30,
		"max_hp": 5000, "speed": 3.0})
	var catalog = _catalog_with([mender], [Fixtures.make_group("mender", 2, 0, 1)],
		{"damage": 100, "range_world": 9.0, "fire_interval_ticks": 10})
	var sim = _sim(catalog)
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	for i in 120:
		sim.step()
	assert_empty(_drain(sim, Types.Event.ENEMY_HEALED),
		"no mutual-tank loops: Menders never heal each other or themselves")


func test_each_mender_pulses_on_its_own_spawn_tick() -> void:
	# ROADMAP trap 2: a schedule anchored on a global clock would make two
	# Menders spawned 40 ticks apart fire together forever.
	var mender = _make_ability_def("mender", {"ability": Types.Ability.HEAL_PULSE,
		"ability_radius": 30.0, "ability_amount": 300, "ability_interval": 60,
		"max_hp": 100000, "speed": 0.1})
	var catalog = _catalog_with([mender],
		[Fixtures.make_group("test_enemy", 1, 0, 1), Fixtures.make_group("mender", 2, 0, 40)],
		{"damage": 100, "range_world": 9.0, "fire_interval_ticks": 3},
		{"max_hp": 100000, "speed": 0.1})
	var sim = _sim(catalog)
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()

	var pulse_ticks: Array = []
	for i in 200:
		sim.step()
		if not _drain(sim, Types.Event.ENEMY_HEALED).is_empty():
			pulse_ticks.append(sim.tick)
	assert_gt(pulse_ticks.size(), 2, "several pulses should have landed")
	var gaps: Dictionary = {}
	for i in range(1, pulse_ticks.size()):
		gaps[int(pulse_ticks[i]) - int(pulse_ticks[i - 1])] = true
	assert_gt(gaps.size(), 1,
		"two Menders spawned 40 ticks apart must not pulse in lockstep")


# ---------------------------------------------------------------------------
# SPLIT_ON_DEATH - the release gate for the Crawler
# ---------------------------------------------------------------------------

func _crawler_catalog():
	var child = _make_ability_def("child", {"max_hp": 400, "speed": 6.5, "bounty": 4})
	var crawler = _make_ability_def("crawler", {"ability": Types.Ability.SPLIT_ON_DEATH,
		"max_hp": 600, "speed": 3.0, "bounty": 12, "leak_damage": 2})
	crawler.spawn_on_death = PackedStringArray(["child", "child"])
	return _catalog_with([child, crawler], [Fixtures.make_group("crawler", 1, 0, 30)],
		{"damage": 200, "range_world": 9.0, "fire_interval_ticks": 10})


func test_split_spawns_children_at_the_parents_exact_progress() -> void:
	var sim = _sim(_crawler_catalog())
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()

	var parent = null
	for i in 200:
		sim.step()
		if parent == null:
			parent = _enemy_with_def(sim, "crawler")
		if _enemy_with_def(sim, "child") != null:
			break
	assert_not_null(parent, "the crawler should have spawned")

	var children: Array = []
	for enemy in sim.enemies:
		if enemy.def_id == "child":
			children.append(enemy)
	assert_eq(children.size(), 2, "exactly two children")
	for child in children:
		assert_eq(child.path_index, parent.path_index, "children inherit path progress")
		assert_eq(child.position, parent.position)
		assert_almost_eq(child.distance_travelled, parent.distance_travelled)
	assert_lt(children[0].id, children[1].id, "ids are assigned in fixed order")


func test_split_event_order_is_killed_then_spawned_then_split() -> void:
	var sim = _sim(_crawler_catalog())
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()

	var order: Array = []
	for i in 200:
		sim.step()
		for event in sim.drain_events():
			var kind: int = int(event["type"])
			if kind == Types.Event.ENEMY_KILLED or kind == Types.Event.ENEMY_SPAWNED \
					or kind == Types.Event.ENEMY_SPLIT:
				order.append(kind)
		if order.has(Types.Event.ENEMY_SPLIT):
			break

	var killed: int = order.find(Types.Event.ENEMY_KILLED)
	var split: int = order.find(Types.Event.ENEMY_SPLIT)
	assert_gt(killed, -1, "the parent should have died")
	assert_gt(split, killed, "ENEMY_SPLIT comes after the parent's death")
	assert_eq(order.slice(killed + 1, split), [Types.Event.ENEMY_SPAWNED, Types.Event.ENEMY_SPAWNED],
		"exactly two spawns between the death and the split")


func test_split_event_names_the_ids_it_spawned() -> void:
	var sim = _sim(_crawler_catalog())
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	var split: Dictionary = {}
	for i in 200:
		sim.step()
		var found: Array = _drain(sim, Types.Event.ENEMY_SPLIT)
		if not found.is_empty():
			split = found[0]
			break
	assert_false(split.is_empty())
	var spawned: PackedInt32Array = split["spawned"]
	assert_eq(spawned.size(), 2)
	for id in spawned:
		var seen: bool = false
		for enemy in sim.enemies:
			if enemy.id == int(id):
				seen = true
		assert_true(seen, "split named id %d, which is not a live enemy" % int(id))


func test_a_leaked_parent_does_not_split() -> void:
	# Leak arithmetic is deliberately neutral: 2 for the parent either way, so
	# there must be no incentive to let a Crawler through.
	var sim = _sim(_crawler_catalog())
	sim.start_next_wave()
	for i in 600:
		sim.step()
		if sim.is_over():
			break
	assert_null(_enemy_with_def(sim, "child"), "a Crawler that leaks releases nothing")


# ---------------------------------------------------------------------------
# The air lane
# ---------------------------------------------------------------------------

func _skiff_catalog(can_target_air: bool):
	var skiff = _make_ability_def("skiff", {"max_hp": 100000, "speed": 2.0, "flies": true})
	return _catalog_with([skiff], [Fixtures.make_group("skiff", 1, 0, 30)],
		{"damage": 100, "range_world": 30.0, "fire_interval_ticks": 5,
			"can_target_air": can_target_air})


## A board with a bend in it. On the straight fixture map the chord and the walk
## are the same 18 units, so the assertion below could not fail however wrong
## the air lane was.
const BENT_LAYOUT := "S####.....\n....#.....\n....#####G"


func test_fliers_take_the_chord_not_the_path() -> void:
	var skiff = _make_ability_def("skiff", {"max_hp": 100000, "speed": 2.0, "flies": true})
	var catalog = _catalog_with([skiff], [Fixtures.make_group("skiff", 1, 0, 30)],
		{}, {}, {"layout_inline": BENT_LAYOUT})
	var sim = _sim(catalog)
	assert_eq(sim.air_waypoints.size(), 2, "spawn and goal, nothing between")
	assert_almost_eq(sim.air_waypoints[0].y, Types.AIR_CRUISE_HEIGHT)
	assert_almost_eq(sim.air_waypoints[1].y, Types.AIR_CRUISE_HEIGHT)

	var chord: float = sim.air_waypoints[0].distance_to(sim.air_waypoints[1])
	var walked: float = 0.0
	for i in range(1, sim.waypoints.size()):
		walked += sim.waypoints[i - 1].distance_to(sim.waypoints[i])
	assert_lt(chord, walked, "the chord must be shorter than the walk")


func test_a_flier_cruises_at_altitude() -> void:
	var sim = _sim(_skiff_catalog(true))
	sim.start_next_wave()
	for i in 30:
		sim.step()
	var skiff = _enemy_with_def(sim, "skiff")
	assert_not_null(skiff)
	assert_almost_eq(skiff.position.y, Types.AIR_CRUISE_HEIGHT, 0.001,
		"altitude is where the health bar hangs")


func test_a_tower_without_can_target_air_never_touches_a_flier() -> void:
	var sim = _sim(_skiff_catalog(false))
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	for i in 200:
		sim.step()
	var skiff = _enemy_with_def(sim, "skiff")
	assert_not_null(skiff, "the skiff should still be flying")
	assert_eq(skiff.hp, skiff.max_hp, "a ground-only tower must not scratch it")


func test_splash_from_a_ground_only_tower_ignores_fliers() -> void:
	var skiff = _make_ability_def("skiff", {"max_hp": 100000, "speed": 0.5, "flies": true})
	var catalog = _catalog_with([skiff],
		[Fixtures.make_group("skiff", 1, 0, 1), Fixtures.make_group("test_enemy", 1, 0, 1)],
		{"damage": 300, "range_world": 30.0, "fire_interval_ticks": 5,
			"splash_radius": 30.0, "can_target_air": false},
		{"max_hp": 100000, "speed": 0.5})
	var sim = _sim(catalog)
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	for i in 120:
		sim.step()
	var flier = _enemy_with_def(sim, "skiff")
	var ground = _enemy_with_def(sim, "test_enemy")
	assert_lt(ground.hp, ground.max_hp, "the ground unit should be taking splash")
	assert_eq(flier.hp, flier.max_hp, "a mortar shell must not clip a Skiff on the way past")


func test_a_tower_with_can_target_air_does_shoot_fliers() -> void:
	var sim = _sim(_skiff_catalog(true))
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	for i in 200:
		sim.step()
	var skiff = _enemy_with_def(sim, "skiff")
	assert_not_null(skiff)
	assert_lt(skiff.hp, skiff.max_hp, "flak has to work, or the Skiff is unanswerable")


# ---------------------------------------------------------------------------
# Determinism across all of it
# ---------------------------------------------------------------------------

func _mixed_catalog():
	var warden = _make_ability_def("warden", {"ability": Types.Ability.AURA,
		"ability_radius": 4.0, "ability_percent": 60, "max_hp": 2600, "speed": 3.0})
	var mender = _make_ability_def("mender", {"ability": Types.Ability.HEAL_PULSE,
		"ability_radius": 4.5, "ability_amount": 300, "ability_interval": 120,
		"max_hp": 1800, "speed": 3.2})
	var child = _make_ability_def("child", {"max_hp": 450, "speed": 6.5})
	var crawler = _make_ability_def("crawler", {"ability": Types.Ability.SPLIT_ON_DEATH,
		"max_hp": 2200, "speed": 3.0})
	crawler.spawn_on_death = PackedStringArray(["child", "child"])
	var skiff = _make_ability_def("skiff", {"max_hp": 900, "speed": 4.0, "flies": true})
	return _catalog_with([warden, mender, child, crawler, skiff], [
			Fixtures.make_group("warden", 1, 0, 30),
			Fixtures.make_group("mender", 1, 20, 30),
			Fixtures.make_group("crawler", 2, 40, 40),
			Fixtures.make_group("skiff", 2, 60, 40),
			Fixtures.make_group("test_enemy", 4, 10, 25),
		],
		{"damage": 120, "range_world": 9.0, "fire_interval_ticks": 9},
		{"max_hp": 1700, "speed": 3.4})


func _run_mixed(ticks: int) -> PackedInt64Array:
	var sim = _sim(_mixed_catalog())
	sim.try_build(BUILD_CELL, "test_tower")
	sim.try_build(Vector2i(6, 1), "test_tower")
	sim.start_next_wave()
	var hashes := PackedInt64Array()
	for i in ticks:
		sim.step()
		hashes.append(sim.snapshot_hash())
	return hashes


func test_a_wave_of_every_ability_is_reproducible() -> void:
	var a: PackedInt64Array = _run_mixed(400)
	var b: PackedInt64Array = _run_mixed(400)
	assert_eq(a.size(), b.size())
	for i in a.size():
		if a[i] != b[i]:
			_fail("ability wave diverged at tick %d: %d vs %d" % [i + 1, a[i], b[i]])
			return
	assert_true(true, "400 ticks of auras, heals, splits and fliers matched")


func test_hash_sees_aura_membership() -> void:
	var sim = _sim(_mixed_catalog())
	sim.start_next_wave()
	for i in 60:
		sim.step()
	var protected = null
	for enemy in sim.enemies:
		if enemy.aura_percent < 100:
			protected = enemy
	assert_not_null(protected, "someone should be inside the Warden's aura by now")

	var hashed: int = sim.snapshot_hash()
	protected.aura_percent = 100
	assert_ne(sim.snapshot_hash(), hashed, "aura membership must reach the hash")


func test_hash_sees_a_healers_private_schedule() -> void:
	var sim = _sim(_mixed_catalog())
	sim.start_next_wave()
	for i in 60:
		sim.step()
	var mender = _enemy_with_def(sim, "mender")
	assert_not_null(mender)
	var hashed: int = sim.snapshot_hash()
	mender.ability_next_tick += 1
	assert_ne(sim.snapshot_hash(), hashed, "the pulse schedule must reach the hash")


# ---------------------------------------------------------------------------
# Shipped content
# ---------------------------------------------------------------------------

func test_shipped_roster_validates_including_the_split_only_enemy() -> void:
	var catalog = CatalogScript.load_default()
	assert_empty(catalog.validate(), str(catalog.validate()))
	# fission_spawn appears in no wave anywhere; it is reachable only through
	# fission_crawler's spawn_on_death, and that must be enough.
	assert_not_null(catalog.get_enemy("fission_spawn"))
	var crawler = catalog.get_enemy("fission_crawler")
	assert_eq(crawler.ability, int(Types.Ability.SPLIT_ON_DEATH))
	assert_eq(crawler.spawn_on_death.size(), 2)
	for child_id in crawler.spawn_on_death:
		assert_not_null(catalog.get_enemy(str(child_id)))


func test_no_frost_mortar_tier_can_ever_target_air() -> void:
	# upgrades.md 6 declares this hole as the mortar family's price, and the
	# Skiff is what collects it. A tier that gains air is a design change.
	var catalog = CatalogScript.load_default()
	for id in catalog.all_tower_ids():
		var def = catalog.get_tower(id)
		if str(id).begins_with("frost_mortar"):
			assert_false(def.can_target_air, "'%s' must never target air" % id)
		else:
			assert_true(def.can_target_air, "'%s' should answer fliers" % id)


func test_support_units_outrank_the_escorts_they_travel_with() -> void:
	# Both gaps exist so Strongest targeting picks the support out of its pack.
	# They are tuning invariants, not coincidences (enemies.md 2).
	var catalog = CatalogScript.load_default()
	assert_gt(catalog.get_enemy("warden").max_hp, catalog.get_enemy("shielded_scout").max_hp,
		"the Warden must outrank the Shielded Scouts it escorts")
	assert_gt(catalog.get_enemy("mender").max_hp, catalog.get_enemy("walker").max_hp,
		"the Mender must outrank the Walkers it marches with")
