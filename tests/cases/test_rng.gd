extends "res://tests/test_case.gd"

const RngScript := preload("res://sim/rng.gd")


func test_same_seed_gives_same_sequence() -> void:
	var a = RngScript.new(4242)
	var b = RngScript.new(4242)
	for i in 200:
		assert_eq(a.next_uint(), b.next_uint(), "diverged at draw %d" % i)


func test_different_seeds_diverge() -> void:
	var a = RngScript.new(1)
	var b = RngScript.new(2)
	var identical: int = 0
	for i in 50:
		if a.next_uint() == b.next_uint():
			identical += 1
	assert_lt(identical, 5, "different seeds should not track each other")


func test_zero_seed_is_normalised() -> void:
	var rng = RngScript.new(0)
	assert_ne(rng.get_state(), 0, "a zero state would lock the generator")
	assert_gt(rng.next_uint(), 0)


func test_output_stays_in_32_bits() -> void:
	var rng = RngScript.new(99)
	for i in 500:
		var value: int = rng.next_uint()
		assert_true(value >= 0 and value <= RngScript.MASK, "value %d out of range" % value)


func test_randi_range_respects_bounds() -> void:
	var rng = RngScript.new(7)
	var seen_min: bool = false
	var seen_max: bool = false
	for i in 1000:
		var value: int = rng.randi_range(3, 7)
		assert_true(value >= 3 and value <= 7, "got %d" % value)
		seen_min = seen_min or value == 3
		seen_max = seen_max or value == 7
	assert_true(seen_min and seen_max, "range endpoints should both be reachable")


func test_randi_range_handles_degenerate_span() -> void:
	var rng = RngScript.new(7)
	assert_eq(rng.randi_range(5, 5), 5)
	assert_eq(rng.randi_range(9, 2), 9)


func test_randf_is_unit_interval() -> void:
	var rng = RngScript.new(11)
	for i in 500:
		var value: float = rng.randf()
		assert_true(value >= 0.0 and value < 1.0, "got %f" % value)


func test_weighted_index_ignores_zero_weights() -> void:
	var rng = RngScript.new(13)
	var weights := PackedInt32Array([0, 5, 0])
	for i in 100:
		assert_eq(rng.weighted_index(weights), 1)
	assert_eq(rng.weighted_index(PackedInt32Array([0, 0])), -1)


func test_state_can_be_saved_and_restored() -> void:
	var rng = RngScript.new(2024)
	for i in 10:
		rng.next_uint()
	var saved: int = rng.get_state()
	var expected: int = rng.next_uint()

	rng.set_state(saved)
	assert_eq(rng.next_uint(), expected, "restoring state must replay the sequence")
