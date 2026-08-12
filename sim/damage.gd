class_name DamageTable
extends RefCounted
## Damage-type vs armour-type effectiveness.
##
## Multipliers are integer percentages so damage is exact integer arithmetic.
## This is the single balance lever that makes tower variety matter - edit this
## table before you start editing individual tower numbers.
##
## Because the arithmetic is integer, every division truncates, and the loss is
## proportionally worst on small base damage. Shipped tower damage and enemy HP
## are therefore held at a 10x scale (a 9-damage turret is `damage = 90`), which
## keeps the percentages above honest: 90 kinetic vs heavy is exactly 63, where
## 9 vs heavy would floor 6.3 to 6 and quietly hand the player a 4.8% penalty
## the table never asked for. Keep new content on the same scale.

const Types := preload("res://sim/sim_types.gd")

##                        LIGHT MEDIUM HEAVY SHIELDED
const MULTIPLIER_PERCENT := [
	[110, 100, 70, 50],   # KINETIC   - shreds light, bounces off shields
	[80, 100, 120, 150],  # ENERGY    - the shield answer
	[130, 90, 60, 40],    # EXPLOSIVE - crowd clearing, poor single-target
]


static func multiplier_percent(damage_type: int, armor_type: int) -> int:
	if damage_type < 0 or damage_type >= MULTIPLIER_PERCENT.size():
		return 100
	var row: Array = MULTIPLIER_PERCENT[damage_type]
	if armor_type < 0 or armor_type >= row.size():
		return 100
	return int(row[armor_type])


## Final integer damage. Always at least 1 so nothing is fully immune.
static func compute(base_damage: int, damage_type: int, armor_type: int) -> int:
	if base_damage <= 0:
		return 0
	var pct: int = multiplier_percent(damage_type, armor_type)
	return maxi(1, (base_damage * pct) / 100)


## Final integer damage for a splash hit: armour matchup and distance falloff
## folded into one division.
##
## Applying the two percentages separately truncates twice, which on a rim hit
## used to cost more than the falloff itself. Returns 0 - not the usual floor of
## 1 - when falloff is 0, so an enemy exactly on the rim takes nothing.
static func compute_splash(base_damage: int, damage_type: int, armor_type: int,
		falloff_percent: int) -> int:
	if base_damage <= 0 or falloff_percent <= 0:
		return 0
	var armour_pct: int = multiplier_percent(damage_type, armor_type)
	return maxi(1, (base_damage * armour_pct * falloff_percent) / 10000)


## Final integer damage with an aura folded in as a THIRD percentage in the same
## single division: base x armour% x aura% / 10000.
##
## Applying the aura as its own division after the armour one truncates twice and
## re-opens the wound the 10x rescale closed - a Warden would quietly grant more
## than the 40% reduction it advertises, worst on exactly the small hits the
## aura is supposed to matter least against. `aura_percent` is 100 when the
## target is unprotected, which makes this identical to compute().
static func compute_with_aura(base_damage: int, damage_type: int, armor_type: int,
		aura_percent: int) -> int:
	if base_damage <= 0:
		return 0
	var pct: int = multiplier_percent(damage_type, armor_type)
	return maxi(1, (base_damage * pct * aura_percent) / 10000)


## Splash, armour, falloff and aura in one division: the four-way version of
## compute_splash. Same reasoning, one more percentage.
static func compute_splash_with_aura(base_damage: int, damage_type: int, armor_type: int,
		falloff_percent: int, aura_percent: int) -> int:
	if base_damage <= 0 or falloff_percent <= 0:
		return 0
	var armour_pct: int = multiplier_percent(damage_type, armor_type)
	return maxi(1, (base_damage * armour_pct * falloff_percent * aura_percent) / 1000000)


## Splash falloff, integer percent of full damage at the given distance.
## Full damage at the centre, linear falloff to 25% at the rim.
static func splash_percent_at(distance: float, radius: float) -> int:
	if radius <= 0.0:
		return 100
	if distance >= radius:
		return 0
	var t: float = distance / radius
	return maxi(0, int(round(100.0 - 75.0 * t)))
