extends "res://tests/test_case.gd"
## The load-bearing test.
##
## If this suite fails, replays, save games, balance regression runs and bug
## reproduction all stop working. Treat a failure here as a release blocker, not
## as a flaky test to be retried.

const Types := preload("res://sim/sim_types.gd")
const SimulationScript := preload("res://sim/simulation.gd")
const Fixtures := preload("res://tests/support/fixtures.gd")

## Commands as {tick, action, cell, tower}. Replayed identically into both runs.
const SCRIPTED_COMMANDS := [
	{"tick": 0, "action": "build", "x": 2, "y": 1, "tower": "test_tower"},
	{"tick": 0, "action": "wave"},
	{"tick": 20, "action": "build", "x": 5, "y": 1, "tower": "test_tower"},
	{"tick": 45, "action": "sell", "x": 2, "y": 1},
	{"tick": 60, "action": "build", "x": 7, "y": 2, "tower": "test_tower"},
]


func _new_sim(seed_value: int):
	var groups: Array = [Fixtures.make_group("test_enemy", 5, 0, 12)]
	var catalog = Fixtures.make_catalog(
		{"damage": 12, "range_world": 7.0, "fire_interval_ticks": 11},
		{"max_hp": 130, "speed": 3.0},
		groups
	)
	var sim = SimulationScript.new()
	assert_true(sim.setup(catalog.first_map(), catalog, seed_value), sim.setup_error)
	return sim


func _apply_commands(sim, at_tick: int) -> void:
	for command in SCRIPTED_COMMANDS:
		if int(command["tick"]) != at_tick:
			continue
		match str(command["action"]):
			"build":
				sim.try_build(Vector2i(int(command["x"]), int(command["y"])), str(command["tower"]))
			"sell":
				sim.try_sell(Vector2i(int(command["x"]), int(command["y"])))
			"wave":
				sim.start_next_wave()


## Runs the scripted match and returns the hash after every tick.
func _run(seed_value: int, ticks: int) -> PackedInt64Array:
	var sim = _new_sim(seed_value)
	var hashes := PackedInt64Array()
	_apply_commands(sim, 0)
	for t in range(1, ticks + 1):
		sim.step()
		_apply_commands(sim, t)
		hashes.append(sim.snapshot_hash())
	return hashes


func test_identical_runs_produce_identical_hashes() -> void:
	var a: PackedInt64Array = _run(1234, 400)
	var b: PackedInt64Array = _run(1234, 400)
	assert_eq(a.size(), b.size())
	for i in a.size():
		if a[i] != b[i]:
			_fail("state diverged at tick %d: %d vs %d" % [i + 1, a[i], b[i]])
			return
	assert_true(true, "400 ticks matched")


func test_hash_reacts_to_state_changes() -> void:
	var sim = _new_sim(1234)
	var before: int = sim.snapshot_hash()
	sim.start_next_wave()
	sim.step()
	assert_ne(sim.snapshot_hash(), before, "spawning an enemy must change the hash")


func test_hash_is_stable_without_stepping() -> void:
	var sim = _new_sim(1234)
	assert_eq(sim.snapshot_hash(), sim.snapshot_hash(), "hashing must have no side effects")


func test_tick_count_is_independent_of_batch_size() -> void:
	# Whether the caller steps 1 tick or 200 in a frame, the sim must agree.
	var single = _new_sim(7)
	var batched = _new_sim(7)
	single.start_next_wave()
	batched.start_next_wave()

	for i in 200:
		single.step()
	for i in 4:
		for j in 50:
			batched.step()

	assert_eq(single.tick, batched.tick)
	assert_eq(single.snapshot_hash(), batched.snapshot_hash())


func test_hash_sees_a_status_change() -> void:
	# A slow only reaches distance_travelled a tick later, and cancels out
	# entirely if it expires between two samples - so before slow_percent and
	# slow_ticks_left were hashed, a status bug could run a whole match without
	# the strongest verification tool in the project noticing.
	var groups: Array = [Fixtures.make_group("test_enemy", 1, 0, 30)]
	var catalog = Fixtures.make_catalog(
		{"damage": 1, "range_world": 8.0, "fire_interval_ticks": 10,
			"slow_percent": 40, "slow_ticks": 120},
		{"max_hp": 100000, "speed": 3.0},
		groups
	)
	var sim = SimulationScript.new()
	assert_true(sim.setup(catalog.first_map(), catalog, 1), sim.setup_error)
	sim.try_build(Vector2i(2, 1), "test_tower")
	sim.start_next_wave()

	# Step until the tower has fired and the enemy is slowed.
	for i in 60:
		sim.step()
	var enemy = sim.enemies[0]
	assert_gt(enemy.slow_ticks_left, 0, "the enemy should be slowed by now")

	var hashed: int = sim.snapshot_hash()
	enemy.slow_ticks_left -= 1
	assert_ne(sim.snapshot_hash(), hashed, "slow_ticks_left must reach the hash")

	enemy.slow_ticks_left += 1
	assert_eq(sim.snapshot_hash(), hashed, "and restoring it must restore the hash")

	enemy.slow_percent += 1
	assert_ne(sim.snapshot_hash(), hashed, "slow_percent must reach the hash")


func test_rng_state_advances_only_through_the_sim_rng() -> void:
	var sim = _new_sim(99)
	var state_before: int = sim.rng.get_state()
	sim.start_next_wave()
	for i in 120:
		sim.step()
	# Nothing in the current rules rolls dice. If you add randomness, this
	# assertion should be updated deliberately, not deleted.
	assert_eq(sim.rng.get_state(), state_before, "unexpected RNG consumption")
