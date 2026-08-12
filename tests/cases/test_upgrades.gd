extends "res://tests/test_case.gd"
## The three-tier upgrade system (ROADMAP 2.2, docs/design/upgrades.md).
##
## An upgraded tower simply *is* its new def: same id, same cell, new stats. The
## tests that matter here are the ones about what must NOT change - footprint,
## cell, accumulated record - and the ones about refusal, because an upgrade
## command arrives from a replay log as readily as from a button.

const Types := preload("res://sim/sim_types.gd")
const SimulationScript := preload("res://sim/simulation.gd")
const CatalogScript := preload("res://data/catalog.gd")
const Fixtures := preload("res://tests/support/fixtures.gd")
const FakeCatalogScript := preload("res://tests/support/fake_catalog.gd")

const BUILD_CELL := Vector2i(2, 1)

## Fixture ladder: base 100 -> t2 (+120) -> t3a (+150) / t3b (+150).
## Hand-built rather than shipped, so a balance tune cannot redden this suite.
func _ladder_catalog(overrides: Dictionary = {}):
	var catalog = FakeCatalogScript.new()

	var base = Fixtures.make_tower({"id": "t1", "cost": 100, "damage": 20,
		"fire_interval_ticks": 30, "range_world": 6.0})
	base.upgrade_ids = PackedStringArray(["t2"])
	base.tier = 1
	base.buildable = true

	var t2 = Fixtures.make_tower({"id": "t2", "cost": 120, "damage": 50,
		"fire_interval_ticks": 20, "range_world": 8.0})
	t2.upgrade_ids = PackedStringArray(["t3a", "t3b"])
	t2.tier = 2
	t2.buildable = false

	var t3a = Fixtures.make_tower({"id": "t3a", "cost": 150, "damage": 90,
		"fire_interval_ticks": 20, "range_world": 9.0, "target_mode": 3})
	t3a.tier = 3
	t3a.buildable = false

	var t3b = Fixtures.make_tower({"id": "t3b", "cost": 150, "damage": 30,
		"fire_interval_ticks": 10, "range_world": 8.0, "splash_radius": 2.0})
	t3b.tier = 3
	t3b.buildable = false

	for def in [base, t2, t3a, t3b]:
		catalog.towers[def.id] = def
	var enemy = Fixtures.make_enemy()
	catalog.enemies[enemy.id] = enemy
	var wave = Fixtures.make_wave("test_wave", [Fixtures.make_group(enemy.id, 1, 0, 30)])
	catalog.waves[wave.id] = wave
	var map_overrides: Dictionary = {"starting_credits": 1000}
	map_overrides.merge(overrides, true)
	var map_def = Fixtures.make_map(map_overrides)
	catalog.maps[map_def.id] = map_def
	return catalog


func _sim_with_tower(overrides: Dictionary = {}) -> Dictionary:
	var catalog = _ladder_catalog(overrides)
	var sim = SimulationScript.new()
	assert_true(sim.setup(catalog.first_map(), catalog, 1), sim.setup_error)
	assert_true(sim.try_build(BUILD_CELL, "t1"))
	return {"sim": sim, "catalog": catalog, "tower": sim.tower_at(BUILD_CELL)}


func _drain(sim, event_type: int) -> Array:
	var out: Array = []
	for event in sim.drain_events():
		if int(event["type"]) == event_type:
			out.append(event)
	return out


# ---------------------------------------------------------------------------
# Buying a tier
# ---------------------------------------------------------------------------

func test_upgrade_costs_credits_and_changes_stats() -> void:
	var bundle: Dictionary = _sim_with_tower()
	var sim = bundle["sim"]
	var tower = bundle["tower"]
	var credits_before: int = sim.economy.credits

	assert_eq(tower.damage, 20)
	assert_true(sim.try_upgrade(tower.id, "t2"))

	assert_eq(sim.economy.credits, credits_before - 120, "the tier's cost is an increment")
	assert_eq(tower.def_id, "t2")
	assert_eq(tower.damage, 50)
	assert_eq(tower.fire_interval_ticks, 20)
	assert_almost_eq(tower.range_world, 8.0)


func test_upgrade_accrues_into_credits_invested() -> void:
	var bundle: Dictionary = _sim_with_tower()
	var sim = bundle["sim"]
	var tower = bundle["tower"]
	assert_eq(tower.credits_invested, 100)
	assert_true(sim.try_upgrade(tower.id, "t2"))
	assert_eq(tower.credits_invested, 220)
	assert_true(sim.try_upgrade(tower.id, "t3a"))
	assert_eq(tower.credits_invested, 370, "base + both tiers")


func test_upgrade_never_changes_footprint_or_identity() -> void:
	var bundle: Dictionary = _sim_with_tower()
	var sim = bundle["sim"]
	var tower = bundle["tower"]
	var id_before: int = tower.id
	var cell_before: Vector2i = tower.cell
	var position_before: Vector3 = tower.position

	sim.try_upgrade(tower.id, "t2")
	sim.try_upgrade(tower.id, "t3b")

	assert_eq(tower.id, id_before)
	assert_eq(tower.cell, cell_before)
	assert_eq(tower.position, position_before)
	assert_eq(sim.towers.size(), 1, "an upgrade must not create a second tower")
	assert_eq(sim.tower_at(cell_before), tower, "the cell index must still resolve")


func test_upgrade_keeps_the_towers_record() -> void:
	# kills and damage_dealt are the tower's history, not its stats.
	var bundle: Dictionary = _sim_with_tower()
	var sim = bundle["sim"]
	var tower = bundle["tower"]
	tower.kills = 7
	tower.damage_dealt = 1234
	sim.try_upgrade(tower.id, "t2")
	assert_eq(tower.kills, 7)
	assert_eq(tower.damage_dealt, 1234)


func test_the_fork_offers_two_branches_and_takes_one() -> void:
	var bundle: Dictionary = _sim_with_tower()
	var sim = bundle["sim"]
	var tower = bundle["tower"]
	sim.try_upgrade(tower.id, "t2")

	assert_true(sim.try_upgrade(tower.id, "t3a"))
	assert_eq(tower.def_id, "t3a")
	assert_false(sim.try_upgrade(tower.id, "t3b"), "the fork is permanent; respec is selling")
	assert_eq(tower.def_id, "t3a")


func test_a_tier_three_offers_nothing_further() -> void:
	var bundle: Dictionary = _sim_with_tower()
	var sim = bundle["sim"]
	var tower = bundle["tower"]
	sim.try_upgrade(tower.id, "t2")
	sim.try_upgrade(tower.id, "t3a")
	assert_false(sim.try_upgrade(tower.id, "t2"), "no going back down the ladder")
	assert_false(sim.try_upgrade(tower.id, "t3b"))


# ---------------------------------------------------------------------------
# Selling
# ---------------------------------------------------------------------------

func test_selling_at_tier_three_refunds_70_percent_of_everything() -> void:
	var bundle: Dictionary = _sim_with_tower()
	var sim = bundle["sim"]
	var tower = bundle["tower"]
	sim.try_upgrade(tower.id, "t2")
	sim.try_upgrade(tower.id, "t3a")
	assert_eq(tower.credits_invested, 370)

	var credits_before: int = sim.economy.credits
	assert_true(sim.try_sell(BUILD_CELL))
	# 370 * 70 / 100 = 259, on the whole ladder rather than the last rung.
	assert_eq(sim.economy.credits, credits_before + 259)
	assert_empty(sim.towers)


# ---------------------------------------------------------------------------
# Refusal. Every one of these can arrive from a replay log.
# ---------------------------------------------------------------------------

func _assert_untouched(sim, tower, hashed: int, credits: int, message: String) -> void:
	assert_eq(tower.def_id, "t1", message)
	assert_eq(sim.economy.credits, credits, message)
	assert_eq(sim.snapshot_hash(), hashed, message)


func test_an_upgrade_the_current_def_does_not_offer_is_rejected() -> void:
	var bundle: Dictionary = _sim_with_tower()
	var sim = bundle["sim"]
	var tower = bundle["tower"]
	var hashed: int = sim.snapshot_hash()
	var credits: int = sim.economy.credits

	# Skipping tier 2 would buy a tier 3 for one increment.
	assert_false(sim.try_upgrade(tower.id, "t3a"), "cannot jump the ladder")
	assert_false(sim.try_upgrade(tower.id, "no_such_def"))
	assert_false(sim.try_upgrade(tower.id, "t1"), "cannot upgrade into itself")
	assert_false(sim.try_upgrade(999, "t2"), "no such tower")
	_assert_untouched(sim, tower, hashed, credits, "a rejected upgrade must not mutate state")


func test_an_unaffordable_upgrade_is_rejected() -> void:
	var bundle: Dictionary = _sim_with_tower({"starting_credits": 150})
	var sim = bundle["sim"]
	var tower = bundle["tower"]
	# 150 - 100 spent on the base leaves 50, short of the 120 tier.
	var hashed: int = sim.snapshot_hash()
	assert_eq(sim.economy.credits, 50)
	assert_false(sim.try_upgrade(tower.id, "t2"))
	_assert_untouched(sim, tower, hashed, 50, "an unaffordable upgrade must not part-charge")


func test_upgrades_are_refused_once_the_match_is_over() -> void:
	# "Exactly as available as build/sell" - and build/sell stop when the match does.
	var bundle: Dictionary = _sim_with_tower()
	var sim = bundle["sim"]
	var tower = bundle["tower"]
	sim.phase = Types.Phase.LOST
	assert_false(sim.try_upgrade(tower.id, "t2"))
	assert_ne(sim.upgrade_blocked_reason(tower.id, "t2"), "")
	assert_eq(tower.def_id, "t1")


func test_malformed_upgrade_args_are_rejected_rather_than_crashing() -> void:
	var bundle: Dictionary = _sim_with_tower()
	var sim = bundle["sim"]
	var hashed: int = sim.snapshot_hash()
	assert_false(sim.apply_command("upgrade", {}))
	assert_false(sim.apply_command("upgrade", {"tower_id": 1}), "no def_id")
	assert_false(sim.apply_command("upgrade", {"def_id": "t2"}), "no tower_id")
	assert_false(sim.apply_command("upgrade", {"tower_id": "1", "def_id": "t2"}))
	assert_false(sim.apply_command("upgrade", {"tower_id": 1, "def_id": 7}))
	assert_false(sim.apply_command("upgrade", {"tower_id": 1.0, "def_id": "t2"}))
	assert_eq(sim.snapshot_hash(), hashed)


# ---------------------------------------------------------------------------
# The seam, and the replay contract
# ---------------------------------------------------------------------------

func test_upgrade_emits_tower_upgraded_with_the_new_def_and_tier() -> void:
	var bundle: Dictionary = _sim_with_tower()
	var sim = bundle["sim"]
	var tower = bundle["tower"]
	sim.drain_events()

	assert_true(sim.try_upgrade(tower.id, "t2"))
	var events: Array = _drain(sim, Types.Event.TOWER_UPGRADED)
	assert_eq(events.size(), 1, "exactly one upgrade event per purchase")
	var event: Dictionary = events[0]
	assert_eq(int(event["tower_id"]), tower.id)
	assert_eq(str(event["def_id"]), "t2")
	assert_eq(int(event["tier"]), 2)


func test_a_rejected_upgrade_emits_nothing() -> void:
	var bundle: Dictionary = _sim_with_tower()
	var sim = bundle["sim"]
	var tower = bundle["tower"]
	sim.drain_events()
	sim.try_upgrade(tower.id, "t3a")
	assert_empty(_drain(sim, Types.Event.TOWER_UPGRADED))


func test_snapshot_hash_covers_the_towers_tier() -> void:
	# Without def_id in the hash a replayed upgrade diverges silently: the
	# credits are spent identically either way, so the economy still matches and
	# only the damage drifts, several ticks later and far from the cause.
	var a = _sim_with_tower()["sim"]
	var b = _sim_with_tower()["sim"]
	assert_eq(a.snapshot_hash(), b.snapshot_hash(), "identical sims must agree")

	a.try_upgrade(a.tower_at(BUILD_CELL).id, "t2")
	assert_ne(a.snapshot_hash(), b.snapshot_hash(), "an upgrade must move the hash")

	b.try_upgrade(b.tower_at(BUILD_CELL).id, "t2")
	assert_eq(a.snapshot_hash(), b.snapshot_hash(), "and the same upgrade must re-converge")


func test_upgrade_replays_identically_through_the_command_log() -> void:
	var live = _sim_with_tower()["sim"]
	var replay = _sim_with_tower()["sim"]
	var live_tower = live.tower_at(BUILD_CELL)
	var replay_tower = replay.tower_at(BUILD_CELL)

	live.start_next_wave()
	replay.start_next_wave()
	for t in range(1, 121):
		live.step()
		replay.step()
		if t == 30:
			live.try_upgrade(live_tower.id, "t2")
			replay.apply_command("upgrade", {"tower_id": replay_tower.id, "def_id": "t2"})
		if t == 60:
			live.try_upgrade(live_tower.id, "t3b")
			replay.apply_command("upgrade", {"tower_id": replay_tower.id, "def_id": "t3b"})
		if live.snapshot_hash() != replay.snapshot_hash():
			_fail("wrapper and command-log upgrade diverged at tick %d" % t)
			return
	assert_true(true, "120 ticks matched through both entry points")


# ---------------------------------------------------------------------------
# Hitscan splash - upgrades.md 4's implementation flag for Hailstorm
# ---------------------------------------------------------------------------

func test_hitscan_splash_damages_neighbours() -> void:
	# Hailstorm is the first hitscan tower with a splash radius; until it, only
	# the Frost Mortar's projectile path exercised splash at all. This is the
	# verification A2 asked for.
	var catalog = Fixtures.make_catalog(
		{"damage": 100, "range_world": 8.0, "fire_interval_ticks": 10,
			"splash_radius": 3.0, "fire_mode": int(Types.FireMode.HITSCAN)},
		{"max_hp": 100000, "speed": 1.0},
		[Fixtures.make_group("test_enemy", 3, 0, 1)]
	)
	var sim = SimulationScript.new()
	assert_true(sim.setup(catalog.first_map(), catalog, 1), sim.setup_error)
	assert_true(sim.try_build(BUILD_CELL, "test_tower"))
	sim.start_next_wave()

	# Three enemies spawn a tick apart at 1.0 u/s, so they stay bunched well
	# inside a 3.0 splash while the tower fires.
	for i in 40:
		sim.step()
	assert_eq(sim.enemies.size(), 3, "the enemies should still be alive to measure")

	var damaged: int = 0
	for enemy in sim.enemies:
		if enemy.hp < enemy.max_hp:
			damaged += 1
	assert_gt(damaged, 1, "a hitscan shot with splash_radius must damage more than its target")


func test_hitscan_without_splash_hits_only_its_target() -> void:
	var catalog = Fixtures.make_catalog(
		{"damage": 100, "range_world": 8.0, "fire_interval_ticks": 10,
			"splash_radius": 0.0, "fire_mode": int(Types.FireMode.HITSCAN)},
		{"max_hp": 100000, "speed": 1.0},
		[Fixtures.make_group("test_enemy", 3, 0, 1)]
	)
	var sim = SimulationScript.new()
	assert_true(sim.setup(catalog.first_map(), catalog, 1), sim.setup_error)
	sim.try_build(BUILD_CELL, "test_tower")
	sim.start_next_wave()
	for i in 40:
		sim.step()

	var damaged: int = 0
	for enemy in sim.enemies:
		if enemy.hp < enemy.max_hp:
			damaged += 1
	assert_eq(damaged, 1, "without a splash radius only the selected target is hit")


# ---------------------------------------------------------------------------
# Shipped content
# ---------------------------------------------------------------------------

func test_shipped_ladders_resolve_and_stay_out_of_the_build_bar() -> void:
	var catalog = CatalogScript.load_default()
	assert_empty(catalog.validate(), str(catalog.validate()))

	var buildable: Array = catalog.tower_ids()
	var everything: Array = catalog.all_tower_ids()
	assert_gt(everything.size(), buildable.size(), "the tier defs still load")
	# Stated as a rule rather than a count: another agent adding a fourth base
	# tower is normal, a tier def reaching the build bar is not.
	for id in buildable:
		assert_eq(int(catalog.get_tower(id).tier), 1,
			"'%s' is in the build bar, so it must be a base tower" % id)

	for id in everything:
		var def = catalog.get_tower(id)
		for upgrade_id in def.upgrade_ids:
			var next_def = catalog.get_tower(str(upgrade_id))
			assert_not_null(next_def, "'%s' lists missing upgrade '%s'" % [id, str(upgrade_id)])
			assert_eq(int(next_def.tier), int(def.tier) + 1,
				"'%s' should be exactly one tier above '%s'" % [str(upgrade_id), id])
			assert_false(next_def.buildable, "tier '%s' must not be in the build bar" % str(upgrade_id))


func test_shipped_tiers_keep_per_shot_damage_above_the_truncation_floor() -> void:
	# difficulty.md 7: below ~40, the integer armour table starts losing its own
	# effect to truncation. Worst case is the weakest multiplier in the table.
	const DamageScript := preload("res://sim/damage.gd")
	var catalog = CatalogScript.load_default()
	for id in catalog.all_tower_ids():
		var def = catalog.get_tower(id)
		for armour in 4:
			var per_shot: int = DamageScript.compute(def.damage, def.damage_type, armour)
			assert_gt(per_shot, 39, "'%s' deals %d per shot into armour %d" % [id, per_shot, armour])
