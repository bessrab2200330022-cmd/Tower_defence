extends "res://tests/test_case.gd"

const WaveDirectorScript := preload("res://sim/wave_director.gd")
const Fixtures := preload("res://tests/support/fixtures.gd")


func _director(groups: Array):
	return WaveDirectorScript.new([Fixtures.make_wave("w1", groups)])


## Collects every spawn emitted over `ticks`, starting the wave at tick 0.
func _run(director, ticks: int) -> Array:
	director.start_next(0)
	var spawns: Array = []
	for t in range(1, ticks + 1):
		for enemy_id in director.step(t):
			spawns.append({"tick": t, "id": enemy_id})
	return spawns


func test_spawns_the_exact_count() -> void:
	var director = _director([Fixtures.make_group("drone", 5, 0, 10)])
	var spawns: Array = _run(director, 600)
	assert_eq(spawns.size(), 5)


func test_respects_the_interval() -> void:
	var director = _director([Fixtures.make_group("drone", 3, 0, 10)])
	var spawns: Array = _run(director, 200)
	assert_eq(spawns[0]["tick"], 1, "the first enemy appears on the first tick")
	assert_eq(spawns[1]["tick"], 11)
	assert_eq(spawns[2]["tick"], 21)


func test_respects_the_start_delay() -> void:
	var director = _director([Fixtures.make_group("brute", 2, 100, 20)])
	var spawns: Array = _run(director, 300)
	assert_eq(spawns.size(), 2)
	assert_eq(spawns[0]["tick"], 100)
	assert_eq(spawns[1]["tick"], 120)


func test_groups_run_in_parallel_and_in_order() -> void:
	var director = _director([
		Fixtures.make_group("drone", 2, 0, 50),
		Fixtures.make_group("brute", 2, 0, 50),
	])
	var spawns: Array = _run(director, 200)
	assert_eq(spawns.size(), 4)
	assert_eq(spawns[0]["id"], "drone", "group order must be stable")
	assert_eq(spawns[1]["id"], "brute")


func test_catches_up_after_a_gap() -> void:
	# A stalled frame must not silently drop spawns.
	var director = _director([Fixtures.make_group("drone", 4, 0, 10)])
	director.start_next(0)
	var spawned: Array = director.step(100)
	assert_eq(spawned.size(), 4, "all overdue spawns are released at once")


func test_reports_when_spawning_is_finished() -> void:
	var director = _director([Fixtures.make_group("drone", 2, 0, 10)])
	director.start_next(0)
	assert_false(director.spawning_finished())
	for t in range(1, 60):
		director.step(t)
	assert_true(director.spawning_finished())


func test_tracks_wave_progression() -> void:
	var director = WaveDirectorScript.new([
		Fixtures.make_wave("w1", [Fixtures.make_group("drone", 1)]),
		Fixtures.make_wave("w2", [Fixtures.make_group("drone", 1)]),
	])
	assert_eq(director.wave_count(), 2)
	assert_eq(director.wave_index, -1)
	assert_true(director.has_next_wave())

	assert_true(director.start_next(0))
	assert_eq(director.wave_index, 0)
	assert_true(director.has_next_wave())

	assert_true(director.start_next(500))
	assert_eq(director.wave_index, 1)
	assert_false(director.has_next_wave())
	assert_false(director.start_next(900), "there is no third wave")


func test_counts_totals() -> void:
	var director = _director([
		Fixtures.make_group("drone", 6, 0, 10),
		Fixtures.make_group("brute", 2, 0, 10),
	])
	director.start_next(0)
	assert_eq(director.total_enemies_in_wave(), 8)
	assert_eq(director.spawned_so_far(), 0)
	director.step(1)
	assert_eq(director.spawned_so_far(), 2)


func test_does_nothing_before_the_wave_starts() -> void:
	var director = _director([Fixtures.make_group("drone", 3, 0, 10)])
	assert_empty(director.step(5))
