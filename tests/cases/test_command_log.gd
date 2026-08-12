extends "res://tests/test_case.gd"
## `Simulation.apply_command` - the single entry point every player command goes
## through, so that a save can be `seed + map id + an ordered command log` and a
## load can be replaying it.
##
## The load-bearing test here is `test_golden_hash_sequence_is_unchanged`. The
## GOLDEN_* values below were captured from the simulation BEFORE the four
## `try_*` methods were routed through `apply_command`. They are the evidence
## that the refactor moved routing and nothing else. If they fail, behaviour
## changed - fix the cause, do not re-capture the constants.
##
## Fixtures rather than shipped `.tres` balance on purpose: pinning a hash to
## `data/` would turn every future balance tweak into a false failure here.

const Types := preload("res://sim/sim_types.gd")
const SimulationScript := preload("res://sim/simulation.gd")
const Fixtures := preload("res://tests/support/fixtures.gd")

const TICKS: int = 400

## See the note above before touching these.
##
## REGENERATED three times, each time `snapshot_hash()` widened: for
## `slow_percent`/`slow_ticks_left`, for the tower's `def_id`, and for
## `aura_percent`/`ability_next_tick`. Each widens
## the fingerprint of every state without altering any state - the scripted
## match has ended on phase COMBAT with 48 lives, 280 credits, 2 towers and 9
## enemies alive through all three revisions, which is the check that says a
## regeneration was legitimate. Verify that before ever regenerating again: if
## the end state moved, the hash is telling you something and the constants are
## not the thing to edit.
##
## These pin behaviour from here on; they are no longer evidence about the
## original apply_command refactor. `_run(false)` vs `_run(true)` carries that.
const GOLDEN_TICK_100: int = 939216219
const GOLDEN_TICK_200: int = 1666505771
const GOLDEN_TICK_300: int = 3210885404
const GOLDEN_TICK_400: int = 2335257322
const GOLDEN_FOLD: int = 1063462439

## One scripted match, expressed as the {tick, action, args} shape a saved
## command log will use. Exercises all four commands, including a sell of a
## tower built mid-match and two target-mode changes.
const SCRIPT := [
	{"tick": 0, "action": "build", "x": 2, "y": 1, "tower": "test_tower"},
	{"tick": 0, "action": "start_wave"},
	{"tick": 20, "action": "build", "x": 5, "y": 1, "tower": "test_tower"},
	{"tick": 45, "action": "set_target_mode", "x": 2, "y": 1, "mode": 1},
	{"tick": 60, "action": "build", "x": 7, "y": 2, "tower": "test_tower"},
	{"tick": 90, "action": "sell", "x": 5, "y": 1},
	{"tick": 150, "action": "set_target_mode", "x": 7, "y": 2, "mode": 3},
]


func _new_sim():
	var groups: Array = [Fixtures.make_group("test_enemy", 12, 0, 20)]
	var catalog = Fixtures.make_catalog(
		{"damage": 12, "range_world": 7.0, "fire_interval_ticks": 11},
		{"max_hp": 130, "speed": 3.0},
		groups,
		{"starting_lives": 50}
	)
	var sim = SimulationScript.new()
	assert_true(sim.setup(catalog.first_map(), catalog, 1234), sim.setup_error)
	return sim


## Drives the scripted commands due at `at_tick` through the legacy wrappers.
func _apply_via_wrappers(sim, at_tick: int) -> void:
	for command in SCRIPT:
		if int(command["tick"]) != at_tick:
			continue
		var cell := Vector2i(int(command["x"] if command.has("x") else 0),
			int(command["y"] if command.has("y") else 0))
		match str(command["action"]):
			"build":
				sim.try_build(cell, str(command["tower"]))
			"sell":
				sim.try_sell(cell)
			"start_wave":
				sim.start_next_wave()
			"set_target_mode":
				sim.set_target_mode(cell, int(command["mode"]))


## The same commands as a replayed log would deliver them: straight into
## apply_command, with no help from the typed wrappers.
func _apply_via_command_log(sim, at_tick: int) -> void:
	for command in SCRIPT:
		if int(command["tick"]) != at_tick:
			continue
		var action: String = str(command["action"])
		var args: Dictionary = {}
		if command.has("x"):
			args["cell"] = Vector2i(int(command["x"]), int(command["y"]))
		if command.has("tower"):
			args["tower_id"] = str(command["tower"])
		if command.has("mode"):
			args["mode"] = int(command["mode"])
		sim.apply_command(action, args)


## Plays the scripted match and returns the hash after every tick.
func _run(use_command_log: bool) -> PackedInt64Array:
	var sim = _new_sim()
	var hashes := PackedInt64Array()
	if use_command_log:
		_apply_via_command_log(sim, 0)
	else:
		_apply_via_wrappers(sim, 0)
	for t in range(1, TICKS + 1):
		sim.step()
		if use_command_log:
			_apply_via_command_log(sim, t)
		else:
			_apply_via_wrappers(sim, t)
		hashes.append(sim.snapshot_hash())
	return hashes


static func _fold(hashes: PackedInt64Array) -> int:
	var h: int = 1469598103
	for value in hashes:
		var mixed: int = (h ^ value) & 0xFFFFFFFF
		h = (mixed * 16777619) & 0xFFFFFFFF
	return h


# ---------------------------------------------------------------------------
# The gate
# ---------------------------------------------------------------------------

func test_golden_hash_sequence_is_unchanged() -> void:
	var hashes: PackedInt64Array = _run(false)
	assert_eq(hashes.size(), TICKS)
	assert_eq(hashes[99], GOLDEN_TICK_100, "tick 100 diverged from pre-refactor behaviour")
	assert_eq(hashes[199], GOLDEN_TICK_200, "tick 200 diverged from pre-refactor behaviour")
	assert_eq(hashes[299], GOLDEN_TICK_300, "tick 300 diverged from pre-refactor behaviour")
	assert_eq(hashes[399], GOLDEN_TICK_400, "tick 400 diverged from pre-refactor behaviour")
	assert_eq(_fold(hashes), GOLDEN_FOLD, "the 400-tick hash sequence diverged")


func test_command_log_matches_the_wrappers_tick_for_tick() -> void:
	var via_wrappers: PackedInt64Array = _run(false)
	var via_log: PackedInt64Array = _run(true)
	assert_eq(via_wrappers.size(), via_log.size())
	for i in via_wrappers.size():
		if via_wrappers[i] != via_log[i]:
			_fail("wrapper and command-log runs diverged at tick %d: %d vs %d"
				% [i + 1, via_wrappers[i], via_log[i]])
			return
	assert_true(true, "%d ticks matched through both entry points" % TICKS)


# ---------------------------------------------------------------------------
# Rejecting nonsense
# ---------------------------------------------------------------------------

func test_unknown_action_returns_false_without_mutating_state() -> void:
	var sim = _new_sim()
	var before: int = sim.snapshot_hash()
	assert_false(sim.apply_command("demolish_everything", {"cell": Vector2i(2, 1)}))
	assert_false(sim.apply_command(""))
	assert_false(sim.apply_command("BUILD", {"cell": Vector2i(2, 1), "tower_id": "test_tower"}),
		"actions are case-sensitive")
	assert_eq(sim.snapshot_hash(), before, "a rejected command must leave the sim untouched")
	assert_empty(sim.towers, "nothing may have been built")


func test_malformed_args_return_false_rather_than_crashing() -> void:
	var sim = _new_sim()
	var before: int = sim.snapshot_hash()

	# Missing keys.
	assert_false(sim.apply_command("build", {}))
	assert_false(sim.apply_command("build", {"cell": Vector2i(2, 1)}), "no tower_id")
	assert_false(sim.apply_command("build", {"tower_id": "test_tower"}), "no cell")
	assert_false(sim.apply_command("sell", {}))
	assert_false(sim.apply_command("set_target_mode", {"cell": Vector2i(2, 1)}), "no mode")

	# Wrong types. A float where a cell belongs means a corrupt log, not a
	# rounding opportunity.
	assert_false(sim.apply_command("build", {"cell": "2,1", "tower_id": "test_tower"}))
	assert_false(sim.apply_command("build", {"cell": Vector2(2.0, 1.0), "tower_id": "test_tower"}))
	assert_false(sim.apply_command("build", {"cell": Vector2i(2, 1), "tower_id": 7}))
	assert_false(sim.apply_command("sell", {"cell": 5}))
	assert_false(sim.apply_command("set_target_mode", {"cell": Vector2i(2, 1), "mode": "last"}))
	assert_false(sim.apply_command("set_target_mode", {"cell": Vector2i(2, 1), "mode": 1.5}))

	assert_eq(sim.snapshot_hash(), before, "malformed commands must leave the sim untouched")
	assert_empty(sim.towers, "nothing may have been built")


func test_extra_args_are_ignored() -> void:
	# A newer save carrying a field this build does not know about should still
	# replay, rather than refusing the whole log.
	var sim = _new_sim()
	assert_true(sim.apply_command("build",
		{"cell": Vector2i(2, 1), "tower_id": "test_tower", "upgrade_tier": 3}))
	assert_eq(sim.towers.size(), 1)


func test_start_wave_needs_no_args() -> void:
	var sim = _new_sim()
	assert_true(sim.apply_command("start_wave"))
	assert_eq(sim.phase, Types.Phase.COMBAT)
	assert_false(sim.apply_command("start_wave"), "a wave cannot be started twice")


func test_wrappers_still_return_what_callers_expect() -> void:
	# game/main.gd and the whole suite call these; the refactor must be invisible.
	var sim = _new_sim()
	assert_true(sim.try_build(Vector2i(2, 1), "test_tower"))
	assert_false(sim.try_build(Vector2i(2, 1), "test_tower"), "cell already occupied")
	assert_false(sim.try_build(Vector2i(0, 0), "test_tower"), "not buildable")
	assert_true(sim.set_target_mode(Vector2i(2, 1), int(Types.TargetMode.WEAKEST)))
	assert_false(sim.set_target_mode(Vector2i(2, 1), 99), "mode out of range")
	assert_true(sim.try_sell(Vector2i(2, 1)))
	assert_false(sim.try_sell(Vector2i(2, 1)), "nothing left to sell")
	assert_true(sim.start_next_wave())
