extends "res://tests/test_case.gd"

const Types := preload("res://sim/sim_types.gd")
const DamageScript := preload("res://sim/damage.gd")


func test_kinetic_beats_light_armour() -> void:
	assert_eq(DamageScript.compute(100, Types.DamageType.KINETIC, Types.ArmorType.LIGHT), 110)


func test_kinetic_is_poor_against_shields() -> void:
	assert_eq(DamageScript.compute(100, Types.DamageType.KINETIC, Types.ArmorType.SHIELDED), 50)


func test_energy_is_the_shield_answer() -> void:
	var energy: int = DamageScript.compute(100, Types.DamageType.ENERGY, Types.ArmorType.SHIELDED)
	var kinetic: int = DamageScript.compute(100, Types.DamageType.KINETIC, Types.ArmorType.SHIELDED)
	assert_gt(energy, kinetic, "energy must out-damage kinetic against shields")
	assert_eq(energy, 150)


func test_explosive_favours_light_targets() -> void:
	assert_eq(DamageScript.compute(100, Types.DamageType.EXPLOSIVE, Types.ArmorType.LIGHT), 130)
	assert_eq(DamageScript.compute(100, Types.DamageType.EXPLOSIVE, Types.ArmorType.HEAVY), 60)


func test_damage_is_never_fully_absorbed() -> void:
	assert_eq(DamageScript.compute(1, Types.DamageType.EXPLOSIVE, Types.ArmorType.SHIELDED), 1)


func test_zero_damage_stays_zero() -> void:
	assert_eq(DamageScript.compute(0, Types.DamageType.KINETIC, Types.ArmorType.LIGHT), 0)
	assert_eq(DamageScript.compute(-5, Types.DamageType.KINETIC, Types.ArmorType.LIGHT), 0)


func test_unknown_types_fall_back_to_neutral() -> void:
	assert_eq(DamageScript.multiplier_percent(99, 0), 100)
	assert_eq(DamageScript.multiplier_percent(0, 99), 100)


func test_splash_falls_off_with_distance() -> void:
	assert_eq(DamageScript.splash_percent_at(0.0, 4.0), 100)
	assert_eq(DamageScript.splash_percent_at(2.0, 4.0), 63)
	assert_eq(DamageScript.splash_percent_at(4.0, 4.0), 0)
	assert_eq(DamageScript.splash_percent_at(9.0, 4.0), 0)


func test_zero_radius_means_full_damage() -> void:
	assert_eq(DamageScript.splash_percent_at(0.0, 0.0), 100)


func test_splash_folds_armour_and_falloff_into_one_division() -> void:
	# 160 explosive vs shielded (40%) at 25% falloff is 16 exactly. Applying the
	# two percentages separately truncated twice and produced less.
	assert_eq(DamageScript.compute_splash(160, Types.DamageType.EXPLOSIVE,
		Types.ArmorType.SHIELDED, 25), 16)


func test_splash_at_full_falloff_matches_a_direct_hit() -> void:
	var direct: int = DamageScript.compute(340, Types.DamageType.ENERGY, Types.ArmorType.HEAVY)
	var splash: int = DamageScript.compute_splash(340, Types.DamageType.ENERGY,
		Types.ArmorType.HEAVY, 100)
	assert_eq(splash, direct, "100% falloff is the same as no falloff at all")


func test_splash_on_the_rim_deals_nothing() -> void:
	# The usual "never fully immune" floor of 1 must not apply here, or standing
	# outside the blast would still cost health.
	assert_eq(DamageScript.compute_splash(160, Types.DamageType.EXPLOSIVE,
		Types.ArmorType.LIGHT, 0), 0)


func test_splash_never_rounds_a_real_hit_down_to_nothing() -> void:
	assert_eq(DamageScript.compute_splash(1, Types.DamageType.EXPLOSIVE,
		Types.ArmorType.SHIELDED, 1), 1)


func test_splash_ignores_non_positive_base_damage() -> void:
	assert_eq(DamageScript.compute_splash(0, Types.DamageType.KINETIC, Types.ArmorType.LIGHT, 100), 0)
	assert_eq(DamageScript.compute_splash(-5, Types.DamageType.KINETIC, Types.ArmorType.LIGHT, 100), 0)


func test_table_shape_is_consistent() -> void:
	assert_eq(DamageScript.MULTIPLIER_PERCENT.size(), 3, "one row per damage type")
	for row in DamageScript.MULTIPLIER_PERCENT:
		assert_eq(row.size(), 4, "one column per armour type")
