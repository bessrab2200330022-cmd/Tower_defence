class_name Economy
extends RefCounted
## All currency is integer credits. Floats are banned here - rounding drift is
## the classic source of "the same replay produced a different result" bugs.

var credits: int = 0
var lives: int = 0
var total_earned: int = 0
var total_spent: int = 0


func _init(starting_credits: int = 0, starting_lives: int = 0) -> void:
	credits = maxi(starting_credits, 0)
	lives = maxi(starting_lives, 0)


func can_afford(cost: int) -> bool:
	return cost >= 0 and credits >= cost


## Returns true if the spend happened.
func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	credits -= cost
	total_spent += cost
	return true


func earn(amount: int) -> void:
	if amount <= 0:
		return
	credits += amount
	total_earned += amount


## Refund for selling, floored. Percent is an integer 0..100.
static func refund_for(cost: int, refund_percent: int) -> int:
	var pct: int = clampi(refund_percent, 0, 100)
	return (maxi(cost, 0) * pct) / 100


## Returns the number of lives actually lost (clamped at zero).
func lose_lives(amount: int) -> int:
	var lost: int = clampi(amount, 0, lives)
	lives -= lost
	return lost


func is_defeated() -> bool:
	return lives <= 0
