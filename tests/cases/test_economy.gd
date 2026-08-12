extends "res://tests/test_case.gd"

const EconomyScript := preload("res://sim/economy.gd")

var economy


func before_each() -> void:
	economy = EconomyScript.new(100, 5)


func test_starts_with_configured_values() -> void:
	assert_eq(economy.credits, 100)
	assert_eq(economy.lives, 5)
	assert_eq(economy.total_spent, 0)
	assert_eq(economy.total_earned, 0)


func test_negative_start_is_clamped() -> void:
	var broke = EconomyScript.new(-50, -3)
	assert_eq(broke.credits, 0)
	assert_eq(broke.lives, 0)


func test_spend_deducts_and_tracks() -> void:
	assert_true(economy.spend(40))
	assert_eq(economy.credits, 60)
	assert_eq(economy.total_spent, 40)


func test_cannot_overspend() -> void:
	assert_false(economy.spend(101))
	assert_eq(economy.credits, 100, "a failed spend must not change the balance")


func test_earn_ignores_non_positive() -> void:
	economy.earn(0)
	economy.earn(-10)
	assert_eq(economy.credits, 100)
	economy.earn(25)
	assert_eq(economy.credits, 125)
	assert_eq(economy.total_earned, 25)


func test_refund_floors_instead_of_rounding() -> void:
	assert_eq(EconomyScript.refund_for(100, 70), 70)
	assert_eq(EconomyScript.refund_for(99, 70), 69)
	assert_eq(EconomyScript.refund_for(1, 70), 0)


func test_refund_percent_is_clamped() -> void:
	assert_eq(EconomyScript.refund_for(100, 250), 100)
	assert_eq(EconomyScript.refund_for(100, -20), 0)


func test_lives_never_go_negative() -> void:
	assert_eq(economy.lose_lives(3), 3)
	assert_eq(economy.lives, 2)
	assert_eq(economy.lose_lives(9), 2, "only the remaining lives can be lost")
	assert_eq(economy.lives, 0)
	assert_true(economy.is_defeated())
