extends SceneTree
## Balance harness. ROADMAP 0.1.
##
##   godot --headless --path . --script res://tests/run_balance.gd
##   godot --headless --path . --script res://tests/run_balance.gd -- --map=crossing --credits=320,640
##
## Plays a few hundred whole matches headless and reports what the game
## currently IS: win rate, average wave reached, credits left idle at the end,
## and damage dealt per tower type.
##
## NOT a CI gate. It is a measuring instrument, and a measurement that fails the
## build is a gate wearing a lab coat - the numbers below are meant to be read
## and argued with, not to go red. It exits non-zero only when the harness
## itself could not run: invalid content, a failed setup, or a match that
## stalled, all of which mean the numbers are not trustworthy.
##
## WHY THE SEED AXIS IS NOT THE INTERESTING ONE. `sim/rng.gd` is constructed and
## its state is hashed, but nothing in the current rules ever draws from it (see
## test_determinism.gd::test_rng_state_advances_only_through_the_sim_rng). Two
## matches with the same policy and different seeds are therefore byte
## identical, and averaging over seeds would report a fake confidence interval
## over one data point. The axis that actually varies a match today is the
## PLACEMENT AND BUILD POLICY, so that is what this sweeps. `--seeds` exists so
## the sweep keeps working the day randomness lands.

const Types := preload("res://sim/sim_types.gd")
const SimulationScript := preload("res://sim/simulation.gd")
const CatalogScript := preload("res://data/catalog.gd")
const DamageScript := preload("res://sim/damage.gd")

## A match that has not resolved by here is stalled, not slow. The shipped
## campaign resolves in ~6k.
const MAX_TICKS: int = 60000

var _catalog
var _problems: Array[String] = []


func _initialize() -> void:
	var options: Dictionary = _parse_args()

	_catalog = CatalogScript.load_default()
	for problem in _catalog.validate():
		_problems.append("content: %s" % problem)

	var maps: Array = _maps_to_run(options)
	if maps.is_empty():
		_problems.append("no maps matched %s" % str(options.get("map", "*")))
		_report_problems()
		return

	if options.has("gates"):
		var bonuses: Array = options.get("bonus", [-1])
		for map_def in maps:
			for credits in options["credits"]:
				for bonus in bonuses:
					_run_gates(map_def, int(credits), int(bonus))
		_report_problems()
		return

	print("")
	print("Balance harness - %d map(s), placement x build order x saving policy"
		% maps.size())
	print("==============================================================")

	var all_runs: Array = []
	for map_def in maps:
		for credits in options["credits"]:
			var runs: Array = _sweep(map_def, int(credits), options)
			all_runs.append_array(runs)
			_report_map(map_def, int(credits), runs)

	_report_overall(all_runs)
	_report_problems()


# ---------------------------------------------------------------------------
# The sweep
# ---------------------------------------------------------------------------

## Placement policies decide WHERE the next tower goes. This is the axis the
## naive autoplay runner never varied, and it is worth more than any other:
## row-major fill on `crossing` stacks every tower in one corner.
const PLACEMENTS := ["row_major", "spread", "near_spawn", "near_goal"]

## Saving policies decide WHETHER to build now. "greedy" buys whatever is
## affordable this instant; "patient" holds out for the first tower in the
## rotation even when a cheaper one is affordable.
const SAVING := ["greedy", "patient"]


func _sweep(map_def, starting_credits: int, options: Dictionary) -> Array:
	var runs: Array = []
	var orders: Array = _build_orders(options)
	for placement in PLACEMENTS:
		for order in orders:
			for saving in SAVING:
				for seed_value in options["seeds"]:
					runs.append(_play(map_def, starting_credits, placement, order,
						saving, int(seed_value)))
	return runs


## Every ordered tower rotation up to length 3, deduplicated. With the shipped
## three towers that is 3 singles + 6 pairs + 6 triples = 15 build orders.
func _build_orders(options: Dictionary) -> Array:
	if options.has("order"):
		return [options["order"]]
	var ids: Array = _catalog.tower_ids()
	var orders: Array = []
	for a in ids:
		orders.append([a])
	for a in ids:
		for b in ids:
			if a != b:
				orders.append([a, b])
	for a in ids:
		for b in ids:
			for c in ids:
				if a != b and b != c and a != c:
					orders.append([a, b, c])
	return orders


## One whole match. Returns the measurements; never throws.
func _play(map_def, starting_credits: int, placement: String, order: Array,
		saving: String, seed_value: int) -> Dictionary:
	# 0 means "leave the map's own value alone", so the bare command measures the
	# shipped game rather than a hypothetical one.
	var previous_credits: int = map_def.starting_credits
	if starting_credits <= 0:
		starting_credits = previous_credits
	map_def.starting_credits = starting_credits

	var sim = SimulationScript.new()
	if not sim.setup(map_def, _catalog, seed_value):
		_problems.append("setup failed on '%s': %s" % [map_def.id, sim.setup_error])
		map_def.starting_credits = previous_credits
		return {}

	var cells: Array = _cells_for(sim, placement)
	var built: int = 0
	var ticks: int = 0
	var leaks: Dictionary = {}
	var peak_coverage: float = 0.0

	while not sim.is_over() and ticks < MAX_TICKS:
		if sim.phase == Types.Phase.BUILD:
			built = _spend(sim, cells, order, saving, built)
			peak_coverage = maxf(peak_coverage, _coverage(sim))
			sim.start_next_wave()
		sim.step()
		ticks += 1
		for event in sim.drain_events():
			if int(event["type"]) == Types.Event.ENEMY_LEAKED:
				var def_id: String = str(event["def_id"])
				leaks[def_id] = int(leaks.get(def_id, 0)) + 1

	if ticks >= MAX_TICKS:
		_problems.append("match stalled after %d ticks on '%s' (%s / %s / %s)"
			% [MAX_TICKS, map_def.id, placement, ",".join(PackedStringArray(order)), saving])

	var damage: Dictionary = {}
	var invested: Dictionary = {}
	var tower_counts: Dictionary = {}
	for tower in sim.towers:
		damage[tower.def_id] = int(damage.get(tower.def_id, 0)) + tower.damage_dealt
		invested[tower.def_id] = int(invested.get(tower.def_id, 0)) + tower.credits_invested
		tower_counts[tower.def_id] = int(tower_counts.get(tower.def_id, 0)) + 1

	map_def.starting_credits = previous_credits
	return {
		"map": str(map_def.id),
		"credits_start": starting_credits,
		"placement": placement,
		"order": ",".join(PackedStringArray(order)),
		"saving": saving,
		"seed": seed_value,
		"won": sim.phase == Types.Phase.WON,
		"wave_reached": sim.wave_director.wave_index + 1,
		"wave_count": sim.wave_director.wave_count(),
		"lives": sim.economy.lives,
		"credits_idle": sim.economy.credits,
		"towers": sim.towers.size(),
		"coverage": peak_coverage,
		"damage": damage,
		"invested": invested,
		"tower_counts": tower_counts,
		"leaks": leaks,
		"ticks": ticks,
	}


# ---------------------------------------------------------------------------
# Reference players and the difficulty gates (docs/design/difficulty.md 2 and 4)
# ---------------------------------------------------------------------------
#
# The gates in difficulty.md 4 are written "across 200 seeds". Seeds do nothing
# (see the header), so WORKSTREAMS.md "Standing decisions" voids that wording
# and asks for the same gates over the POLICY space instead. A reference
# player's composition is fixed by design, so the policy space here is:
#
#     placement policy (5) x pad offset (4)   = 20 runs per script
#     S3 additionally sweeps its Arc Cannon target mode (3) = 60 runs
#
# The pad offset is what stops that space collapsing to "one best build": it
# skips the first k candidate pads, modelling two competent players who both
# understand the game and still put their towers in different places.

const REFERENCE_PLACEMENTS := ["coverage", "spread", "near_spawn", "near_goal", "row_major"]
const REFERENCE_OFFSETS := [0, 1, 2, 3]
## S3 sweeps what its Arc Cannons shoot at; the Lance already ships on STRONGEST.
const S3_ARC_MODES := [0, 2, 4]  # FIRST, CLOSEST, WEAKEST
## Fraction of the route S3 covers before it starts buying tiers instead of towers.
const S3_COVERAGE_BEFORE_TIERS: float = 0.85


## Purchases due at each build phase, by wave index about to start.
## An unaffordable purchase rolls forward rather than being skipped - a
## competent player saves for the Lance rather than forgetting they wanted it.
func _shopping_list(script_name: String, phase: int) -> Array:
	match script_name:
		"S1":
			return ["arc_cannon"]  # repeated while affordable; see _run_reference
		"S2", "S3":
			match phase:
				0:
					return ["arc_cannon", "arc_cannon"]
				1:
					return ["frost_mortar"]
				2:
					return ["plasma_lance"]
				3:
					return ["plasma_lance"]
				_:
					return ["plasma_lance", "arc_cannon", "arc_cannon", "arc_cannon"]
	return []


func _run_reference(map_def, starting_credits: int, bonus: int, script_name: String,
		placement: String, offset: int, arc_mode: int, branch: String) -> Dictionary:
	var previous: Dictionary = _override_map(map_def, starting_credits, bonus)

	var sim = SimulationScript.new()
	if not sim.setup(map_def, _catalog, 1):
		_problems.append("setup failed on '%s': %s" % [map_def.id, sim.setup_error])
		_restore_map(map_def, previous)
		return {}

	var ticks: int = 0
	var pending: Array = []
	var phase_index: int = 0
	var lives_at_wave_start: Dictionary = {}
	var lives_after_wave: Dictionary = {}
	var leaks: Dictionary = {}
	var towers_built: int = 0

	while not sim.is_over() and ticks < MAX_TICKS:
		if sim.phase == Types.Phase.BUILD:
			pending.append_array(_shopping_list(script_name, phase_index))
			towers_built += _shop(sim, pending, placement, offset, arc_mode, script_name, phase_index + 1, branch)
			phase_index += 1
			# wave_index is still the PREVIOUS wave here - start_next_wave has not
			# run yet - so the wave about to start is index + 2 in 1-based terms.
			lives_at_wave_start[sim.wave_director.wave_index + 2] = sim.economy.lives
			sim.start_next_wave()
		elif ticks % 30 == 0:
			# Building is legal mid-wave and every real player does it - bounties
			# arrive during the fight, and difficulty.md 2 has S2 spending its
			# remainder *during* wave 5 explicitly. Restricting these scripts to
			# the build phase left them finishing on ~460 unspendable credits,
			# which failed G3 for a reason that was never about the game.
			towers_built += _shop(sim, pending, placement, offset, arc_mode, script_name, phase_index, branch)

		sim.step()
		ticks += 1
		for event in sim.drain_events():
			var kind: int = int(event["type"])
			if kind == Types.Event.ENEMY_LEAKED:
				var def_id: String = str(event["def_id"])
				leaks[def_id] = int(leaks.get(def_id, 0)) + 1
			elif kind == Types.Event.WAVE_CLEARED:
				lives_after_wave[int(event["wave_index"])] = sim.economy.lives

	if ticks >= MAX_TICKS:
		_problems.append("match stalled after %d ticks (%s / %s / offset %d)"
			% [MAX_TICKS, script_name, placement, offset])

	var damage: Dictionary = {}
	var invested: Dictionary = {}
	var tower_counts: Dictionary = {}
	for tower in sim.towers:
		damage[tower.def_id] = int(damage.get(tower.def_id, 0)) + tower.damage_dealt
		invested[tower.def_id] = int(invested.get(tower.def_id, 0)) + tower.credits_invested
		tower_counts[tower.def_id] = int(tower_counts.get(tower.def_id, 0)) + 1

	_restore_map(map_def, previous)
	return {
		"script": script_name,
		"placement": placement,
		"offset": offset,
		"arc_mode": arc_mode,
		"won": sim.phase == Types.Phase.WON,
		"wave_reached": sim.wave_director.wave_index + 1,
		"wave_count": sim.wave_director.wave_count(),
		"lives": sim.economy.lives,
		"credits_idle": sim.economy.credits,
		"towers": towers_built,
		"lives_at_wave_start": lives_at_wave_start,
		"lives_after_wave": lives_after_wave,
		"leaks": leaks,
		"damage": damage,
		"invested": invested,
		"tower_counts": tower_counts,
		"branch": branch,
	}


## Buys everything currently affordable, in priority order. `pending` is mutated:
## a scheduled tower that could not be afforded stays on the list rather than
## being forgotten, so a competent player saves for the Lance it wanted.
## Returns how many towers went up.
func _shop(sim, pending: Array, placement: String, offset: int, arc_mode: int,
		script_name: String, next_phase: int, branch: String) -> int:
	var built: int = 0
	if script_name == "S1":
		# Buys an Arc Cannon whenever it can afford one. Nothing else, ever.
		while _buy(sim, "arc_cannon", placement, offset, arc_mode, script_name):
			built += 1
		return built

	var still_pending: Array = []
	for tower_id in pending:
		if _buy(sim, str(tower_id), placement, offset, arc_mode, script_name):
			built += 1
		else:
			still_pending.append(tower_id)
	pending.clear()
	pending.append_array(still_pending)

	# S3 is the tuned player: cover the route first, concentrate second. The
	# coverage gate is doing real work here - upgrading out of an uncovered map
	# is a losing line on The Crossing, and both naive orderings proved it. Tiers
	# before the fill dropped S3 to 3.5 towers and a 2.5% win rate; interleaving
	# them one-per-tick was barely better. Coverage dominates concentration until
	# the route is actually held, and only then do tiers pay.
	var concentrating: bool = (script_name == "S3"
		and _coverage(sim) >= S3_COVERAGE_BEFORE_TIERS)
	if concentrating:
		_upgrade_pass(sim, branch)

	# Surplus goes on Arc Cannons, holding back enough for whatever is still on
	# the list AND for the next phase's scheduled purchase. The lookahead is the
	# difference between a competent player and a compulsive one: without it the
	# surplus drained into Arc Cannons between waves and there was never enough
	# left for the Lance the schedule called for, which read as the answer tower
	# being weak when it was simply never bought.
	var reserve: int = 0
	for tower_id in pending:
		var pending_def = _catalog.get_tower(str(tower_id))
		if pending_def != null:
			reserve += pending_def.cost
	for tower_id in _shopping_list(script_name, next_phase):
		var next_def = _catalog.get_tower(str(tower_id))
		if next_def != null:
			reserve += next_def.cost
	# Once S3 is concentrating, the fill stops entirely. Leaving it on meant the
	# fill ran after the upgrade pass every tick and drained the credits first,
	# so only the cheapest rung ever got bought - at 2400 starting credits the
	# ladder still never reached tier 3, and the reason was the harness, not the
	# prices.
	var arc = _catalog.get_tower("arc_cannon")
	while not concentrating and arc != null and sim.economy.credits - reserve >= arc.cost:
		if not _buy(sim, "arc_cannon", placement, offset, arc_mode, script_name):
			break
		built += 1
	return built


## Walks the standing towers lowest-tier-first and buys whatever tier is
## affordable. `branch` picks which side of a fork this policy commits to, which
## is what gives the two tier-3s in each family real coverage in the sweep.
## At most ONE tier per shop tick. Draining every spare credit into tiers first
## left S3 with 3.8 towers against S2's 10.9 and its win rate at 17% - on this
## map coverage beats concentration by a wide margin, so the tuned player
## interleaves the two rather than choosing.
func _upgrade_pass(sim, branch: String) -> void:
	var bought: bool = true
	while bought:
		bought = false
		# Upgrade the pad that has already earned it. Taking towers in array
		# order instead poured everything into Arc Cannons - they are built first
		# and cheapest to tier - and no Lance or Mortar tier was ever measured.
		# damage_dealt is the tuned player's proxy for "this pad sees traffic".
		var ranked: Array = sim.towers.duplicate()
		ranked.sort_custom(func(a, b):
			if a.damage_dealt == b.damage_dealt:
				return a.id < b.id
			return a.damage_dealt > b.damage_dealt)
		for tower in ranked:
			var def = _catalog.get_tower(tower.def_id)
			if def == null or def.upgrade_ids.is_empty():
				continue
			var wanted: String = str(def.upgrade_ids[0])
			if branch == "b" and def.upgrade_ids.size() > 1:
				wanted = str(def.upgrade_ids[def.upgrade_ids.size() - 1])
			if sim.try_upgrade(tower.id, wanted):
				bought = true
				break


## One purchase. Returns false when it is unaffordable or there is nowhere left.
func _buy(sim, tower_id: String, placement: String, offset: int, arc_mode: int,
		script_name: String) -> bool:
	var def = _catalog.get_tower(tower_id)
	if def == null or not sim.economy.can_afford(def.cost):
		return false
	var cell: Vector2i = _pick_cell(sim, placement, offset, def.range_world)
	if cell.x < 0:
		return false
	if not sim.try_build(cell, tower_id):
		return false
	# S3 is S2 plus deliberate target-mode calls.
	if script_name == "S3" and tower_id == "arc_cannon":
		sim.set_target_mode(cell, arc_mode)
	return true


## Where the next tower goes. "coverage" is recomputed per purchase against the
## route the existing towers already cover, which is what difficulty.md 2 means
## by "the next-best uncovered pad"; the rest are the static orders the generic
## sweep uses. Returns (-1,-1) when nothing is free.
func _pick_cell(sim, placement: String, offset: int, range_world: float) -> Vector2i:
	var free: Array = []
	for cell in _cells_for(sim, placement):
		if sim.tower_at(cell) == null:
			free.append(cell)
	if free.is_empty():
		return Vector2i(-1, -1)

	if placement != "coverage":
		return free[mini(offset, free.size() - 1)]

	# Greedy set cover: the pad that newly covers the most route.
	var covered: Dictionary = {}
	for i in sim.waypoints.size():
		for tower in sim.towers:
			var d: Vector3 = sim.waypoints[i] - tower.position
			if d.x * d.x + d.z * d.z <= tower.range_squared():
				covered[i] = true
				break

	var range_sq: float = range_world * range_world
	var scored: Array = []
	for index in free.size():
		var world: Vector3 = sim.grid.cell_to_world(free[index])
		var gain: int = 0
		for i in sim.waypoints.size():
			if covered.has(i):
				continue
			var d: Vector3 = sim.waypoints[i] - world
			if d.x * d.x + d.z * d.z <= range_sq:
				gain += 1
		scored.append({"cell": free[index], "gain": gain, "i": index})
	# Index is the tie-break, so equal-gain pads resolve in a stable order.
	scored.sort_custom(func(a, b):
		if a["gain"] == b["gain"]:
			return a["i"] < b["i"]
		return a["gain"] > b["gain"])
	return scored[mini(offset, scored.size() - 1)]["cell"]


func _run_gates(map_def, starting_credits: int, bonus: int) -> void:
	var runs: Dictionary = {"S1": [], "S2": [], "S3": []}
	for script_name in ["S1", "S2", "S3"]:
		var modes: Array = S3_ARC_MODES if script_name == "S3" else [0]
		# Only S3 buys upgrades, so only S3 sweeps which side of each fork it
		# commits to. S1 and S2 run one nominal branch that is never consulted.
		var branches: Array = ["a", "b"] if script_name == "S3" else ["a"]
		for placement in REFERENCE_PLACEMENTS:
			for offset in REFERENCE_OFFSETS:
				for arc_mode in modes:
					for branch in branches:
						var run: Dictionary = _run_reference(map_def, starting_credits, bonus,
							script_name, placement, int(offset), int(arc_mode), str(branch))
						if not run.is_empty():
							runs[script_name].append(run)

	var effective: int = starting_credits if starting_credits > 0 else map_def.starting_credits
	var effective_bonus: int = bonus if bonus >= 0 else map_def.wave_clear_bonus
	print("")
	print("=== GATES: %s, %d starting credits, %d wave-clear bonus ==="
		% [map_def.id, effective, effective_bonus])
	print("    S1 n=%d  S2 n=%d  S3 n=%d (policy space: placement x pad offset%s)"
		% [runs["S1"].size(), runs["S2"].size(), runs["S3"].size(), " x arc target mode"])
	print("")
	print("  #   result  gate                          measured")
	print("  --------------------------------------------------------------------")

	var s1: Array = runs["S1"]
	var s2: Array = runs["S2"]
	var s3: Array = runs["S3"]
	var s2_wins: Array = _filter(s2, "won", true)

	_gate("G1", _win_rate(s2) >= 0.90, "S2 wins >= 90%",
		"%s (%d/%d)" % [_percent(_win_rate(s2)), s2_wins.size(), s2.size()])

	var median_lives: float = _median(s2_wins, "lives")
	var p5_lives: float = _percentile(s2_wins, "lives", 0.05)
	_gate("G2", s2_wins.size() > 0 and median_lives >= 14.0 and median_lives <= 18.0 and p5_lives >= 8.0,
		"S2 median lives 14-18, p5 >= 8",
		"median %.1f, p5 %.1f" % [median_lives, p5_lives])

	var median_idle: float = _median(s2_wins, "credits_idle")
	_gate("G3", s2_wins.size() > 0 and median_idle <= 200.0, "S2 median idle credits <= 200",
		"%.0f" % median_idle)

	var bit: int = 0
	for run in s2_wins:
		if _lost_a_life_in_wave(run, 5):
			bit += 1
	var bite_rate: float = float(bit) / float(maxi(s2_wins.size(), 1))
	_gate("G4", s2_wins.size() > 0 and bite_rate >= 0.60, "wave 5 costs S2 a life in >= 60%",
		"%s (%d/%d)" % [_percent(bite_rate), bit, s2_wins.size()])

	var s1_median_wave: float = _median(s1, "wave_reached")
	_gate("G5", _win_rate(s1) <= 0.20 and s1_median_wave == 5.0,
		"S1 win <= 20% and median terminal wave 5",
		"win %s, median wave %.1f" % [_percent(_win_rate(s1)), s1_median_wave])

	var reach4: float = _reach_rate(s1, 4)
	var reach5: float = _reach_rate(s1, 5)
	_gate("G6", reach4 >= 0.90 and reach5 >= 0.50, "S1 reaches wave 4 >= 90%, wave 5 >= 50%",
		"w4 %s, w5 %s" % [_percent(reach4), _percent(reach5)])

	var g7_ok: bool = true
	var g7_worst: int = 999
	for run in s1 + s2 + s3:
		if int(run["towers"]) < 3:
			continue
		var after2: int = int(run["lives_after_wave"].get(1, run["lives"]))
		g7_worst = mini(g7_worst, after2)
		if after2 < 15:
			g7_ok = false
	_gate("G7", g7_ok, "3+ towers => >= 15 lives after wave 2",
		"worst %d" % g7_worst)

	var ratio: float = _shielded_clarity()
	_gate("G8", ratio >= 3.0, "energy vs shielded >= 3x kinetic",
		"%.2fx" % ratio)

	var flawless: int = 0
	for run in s3:
		if bool(run["won"]) and int(run["lives"]) == 20:
			flawless += 1
	var flawless_rate: float = float(flawless) / float(maxi(s3.size(), 1))
	_gate("G9", flawless_rate >= 0.10, "some S3 policy goes 20/20 in >= 10%",
		"%s (%d/%d)" % [_percent(flawless_rate), flawless, s3.size()])

	# Where the worst runs come from. G2's percentile clause reads as "no policy
	# in the space does worse than X", so it matters a great deal whether the
	# tail is one deliberately bad placement or a broad weakness.
	print("")
	print("  S2 by placement policy   win rate  median lives  worst lives")
	for placement in REFERENCE_PLACEMENTS:
		var subset: Array = _filter(s2, "placement", placement)
		var worst: int = 999
		for run in subset:
			worst = mini(worst, int(run["lives"]))
		print("    %-20s %9s %13.1f %12d"
			% [placement, _percent(_win_rate(subset)), _median(subset, "lives"), worst])

	print("")
	for script_name in ["S1", "S2", "S3"]:
		var set: Array = runs[script_name]
		print("  %s: win %s, median wave %.1f, median lives %.1f, median idle %.0f, avg towers %.1f"
			% [script_name, _percent(_win_rate(set)), _median(set, "wave_reached"),
				_median(set, "lives"), _median(set, "credits_idle"), _avg(set, "towers")])
	_report_damage(s1 + s2 + s3)
	_report_leaks(s1 + s2 + s3)
	print("")


func _gate(id: String, passed: bool, description: String, measured: String) -> void:
	print("  %-3s %-7s %-29s %s" % [id, "PASS" if passed else "FAIL", description, measured])


func _lost_a_life_in_wave(run: Dictionary, wave: int) -> bool:
	var at_start = run["lives_at_wave_start"].get(wave, null)
	if at_start == null:
		return false
	return int(run["lives"]) < int(at_start)


func _reach_rate(runs: Array, wave: int) -> float:
	if runs.is_empty():
		return 0.0
	var reached: int = 0
	for run in runs:
		if run["lives_at_wave_start"].has(wave):
			reached += 1
	return float(reached) / float(runs.size())


## G8: best energy tower vs SHIELDED against best kinetic tower vs SHIELDED,
## as effective DPS rather than per-shot, so a slow heavy hitter is compared
## honestly against a fast weak one.
func _shielded_clarity() -> float:
	var best_energy: float = 0.0
	var best_kinetic: float = 0.0
	for tower_id in _catalog.tower_ids():
		var def = _catalog.get_tower(tower_id)
		var per_shot: int = DamageScript.compute(def.damage, def.damage_type,
			Types.ArmorType.SHIELDED)
		var dps: float = float(per_shot) * 60.0 / float(maxi(def.fire_interval_ticks, 1))
		if def.damage_type == Types.DamageType.ENERGY:
			best_energy = maxf(best_energy, dps)
		elif def.damage_type == Types.DamageType.KINETIC:
			best_kinetic = maxf(best_kinetic, dps)
	if best_kinetic <= 0.0:
		return 0.0
	return best_energy / best_kinetic


func _median(runs: Array, key: String) -> float:
	return _percentile(runs, key, 0.5)


func _percentile(runs: Array, key: String, fraction: float) -> float:
	if runs.is_empty():
		return 0.0
	var values: Array = []
	for run in runs:
		values.append(float(run[key]))
	values.sort()
	var index: int = int(floor(fraction * float(values.size() - 1)))
	return float(values[clampi(index, 0, values.size() - 1)])


# ---------------------------------------------------------------------------
# Policies
# ---------------------------------------------------------------------------

## Buildable cells adjacent to the route, ordered by the placement policy.
func _cells_for(sim, placement: String) -> Array:
	var cells: Array = _cells_beside_the_path(sim)
	match placement:
		"spread":
			return _ordered_by_spread(sim, cells)
		"near_spawn":
			return _ordered_by_distance_to(sim, cells, sim.waypoints[0], true)
		"near_goal":
			return _ordered_by_distance_to(sim, cells, sim.waypoints[sim.waypoints.size() - 1], true)
	return cells


func _cells_beside_the_path(sim) -> Array:
	var out: Array = []
	var grid = sim.grid
	for y in grid.height:
		for x in grid.width:
			var cell := Vector2i(x, y)
			if not grid.is_buildable(cell):
				continue
			for n in grid.neighbours4(cell):
				if grid.is_walkable(n):
					out.append(cell)
					break
	return out


func _ordered_by_distance_to(sim, cells: Array, anchor: Vector3, nearest_first: bool) -> Array:
	var scored: Array = []
	for i in cells.size():
		var offset: Vector3 = sim.grid.cell_to_world(cells[i]) - anchor
		# Index is the tie-break so equal distances keep row-major order and the
		# sweep stays reproducible.
		scored.append({"cell": cells[i], "d": offset.x * offset.x + offset.z * offset.z, "i": i})
	scored.sort_custom(func(a, b):
		if a["d"] == b["d"]:
			return a["i"] < b["i"]
		return a["d"] < b["d"] if nearest_first else a["d"] > b["d"])
	var out: Array = []
	for entry in scored:
		out.append(entry["cell"])
	return out


## Greedy farthest-point ordering: each pick is the cell furthest from every
## cell already chosen, which spreads towers along the route instead of piling
## them at whichever end row-major order happens to reach first.
func _ordered_by_spread(sim, cells: Array) -> Array:
	var remaining: Array = cells.duplicate()
	var chosen: Array = []
	while not remaining.is_empty():
		var best_index: int = 0
		var best_score: float = -1.0
		for i in remaining.size():
			var world: Vector3 = sim.grid.cell_to_world(remaining[i])
			var nearest: float = 1e20
			for taken in chosen:
				var offset: Vector3 = world - sim.grid.cell_to_world(taken)
				nearest = minf(nearest, offset.x * offset.x + offset.z * offset.z)
			if chosen.is_empty():
				nearest = -float(i)  # first pick keeps row-major order
			if nearest > best_score:
				best_score = nearest
				best_index = i
		chosen.append(remaining[best_index])
		remaining.remove_at(best_index)
	return chosen


## Returns the running total of towers built.
func _spend(sim, cells: Array, order: Array, saving: String, built: int) -> int:
	if order.is_empty():
		return built
	for cell in cells:
		if sim.tower_at(cell) != null:
			continue
		var wanted: String = str(order[built % order.size()])
		if sim.try_build(cell, wanted):
			built += 1
			continue
		if saving == "patient":
			# Hold the credits for the tower the rotation actually wants.
			return built
		var placed: bool = false
		for offset in range(1, order.size()):
			if sim.try_build(cell, str(order[(built + offset) % order.size()])):
				built += 1
				placed = true
				break
		if not placed:
			return built
	return built


## Fraction of route waypoints inside at least one tower's range.
func _coverage(sim) -> float:
	if sim.waypoints.is_empty():
		return 0.0
	var covered: int = 0
	for waypoint in sim.waypoints:
		for tower in sim.towers:
			var offset: Vector3 = waypoint - tower.position
			if offset.x * offset.x + offset.z * offset.z <= tower.range_squared():
				covered += 1
				break
	return float(covered) / float(sim.waypoints.size())


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

func _report_map(map_def, starting_credits: int, runs: Array) -> void:
	print("")
	print("--- %s, %d starting credits, %d matches ---"
		% [map_def.id, starting_credits, runs.size()])
	print("")
	print("  win rate            %s" % _percent(_win_rate(runs)))
	print("  avg wave reached    %.2f of %d" % [_avg(runs, "wave_reached"), _wave_count(runs)])
	print("  avg lives left      %.1f" % _avg(runs, "lives"))
	print("  avg credits idle    %.0f" % _avg(runs, "credits_idle"))
	print("  avg towers standing %.1f" % _avg(runs, "towers"))
	print("  avg peak coverage   %s" % _percent(_avg(runs, "coverage")))

	print("")
	print("  by placement policy      matches  win rate  avg wave  avg idle  avg coverage")
	for placement in PLACEMENTS:
		var subset: Array = _filter(runs, "placement", placement)
		print("    %-22s %7d  %8s  %8.2f  %8.0f  %12s"
			% [placement, subset.size(), _percent(_win_rate(subset)),
				_avg(subset, "wave_reached"), _avg(subset, "credits_idle"),
				_percent(_avg(subset, "coverage"))])

	print("")
	print("  by saving policy         matches  win rate  avg wave  avg idle")
	for saving in SAVING:
		var subset: Array = _filter(runs, "saving", saving)
		print("    %-22s %7d  %8s  %8.2f  %8.0f"
			% [saving, subset.size(), _percent(_win_rate(subset)),
				_avg(subset, "wave_reached"), _avg(subset, "credits_idle")])

	print("")
	print("  by build order           matches  win rate  avg wave  avg lives")
	for order in _distinct(runs, "order"):
		var subset: Array = _filter(runs, "order", order)
		print("    %-22s %7d  %8s  %8.2f  %9.1f"
			% [order, subset.size(), _percent(_win_rate(subset)),
				_avg(subset, "wave_reached"), _avg(subset, "lives")])

	_report_damage(runs)
	_report_leaks(runs)


## Damage dealt per tower type, and what it cost to deal it. Total damage is
## meaningless on its own - a type that appears in more build orders will
## always lead - so the per-tower and per-100-credit columns are the ones to
## read.
## Damage per tower type, priced against what was actually sunk into those
## towers. `credits_invested` is the denominator rather than `def.cost` because a
## tier's cost is only its increment - pricing a Prime Focus at 220 would credit
## it with the Lance and the Focused Array it was built on top of.
func _report_damage(runs: Array) -> void:
	var total: Dictionary = {}
	var invested: Dictionary = {}
	var instances: Dictionary = {}
	for run in runs:
		for def_id in run["damage"]:
			total[def_id] = int(total.get(def_id, 0)) + int(run["damage"][def_id])
			invested[def_id] = int(invested.get(def_id, 0)) + int(run["invested"].get(def_id, 0))
			# Towers, not runs. Counting runs here silently reported a whole
			# match's worth of Arc Cannon damage as one tower's.
			instances[def_id] = int(instances.get(def_id, 0)) + int(run["tower_counts"].get(def_id, 0))

	print("")
	print("  damage dealt per tower type (10x scale, towers alive at the end)")
	print("    tower                tier   total damage   per tower   invested/tower   per 100 credits")
	for def_id in _sorted_keys(total):
		var def = _catalog.get_tower(def_id)
		var tier: int = int(def.tier) if def != null else 0
		var count: int = maxi(int(instances.get(def_id, 1)), 1)
		var per_tower: float = float(total[def_id]) / float(count)
		var spend_per_tower: float = float(invested.get(def_id, 0)) / float(count)
		var per_credit: float = per_tower / maxf(spend_per_tower, 1.0) * 100.0
		print("    %-20s %4d %14d %11.0f %16.0f %17.0f"
			% [def_id, tier, total[def_id], per_tower, spend_per_tower, per_credit])


func _report_leaks(runs: Array) -> void:
	var leaks: Dictionary = {}
	for run in runs:
		for def_id in run["leaks"]:
			leaks[def_id] = int(leaks.get(def_id, 0)) + int(run["leaks"][def_id])
	if leaks.is_empty():
		return
	print("")
	print("  leaks by enemy type (all matches)")
	for def_id in _sorted_keys(leaks):
		print("    %-18s %8d" % [def_id, leaks[def_id]])


func _report_overall(runs: Array) -> void:
	print("")
	print("==============================================================")
	print("%d matches total, %s won, avg wave %.2f, avg credits idle %.0f"
		% [runs.size(), _percent(_win_rate(runs)), _avg(runs, "wave_reached"),
			_avg(runs, "credits_idle")])
	var best: Dictionary = {}
	for run in runs:
		if best.is_empty() or _better(run, best):
			best = run
	if not best.is_empty():
		print("best single match: %s / %s / %s on %s at %d credits -> %s, wave %d, %d lives"
			% [best["placement"], best["order"], best["saving"], best["map"],
				best["credits_start"], "WIN" if best["won"] else "LOSS",
				best["wave_reached"], best["lives"]])
	print("")


func _report_problems() -> void:
	if _problems.is_empty():
		print("harness ran clean.")
		print("")
		quit(0)
		return
	print("HARNESS PROBLEMS - the numbers above are not trustworthy:")
	var shown: int = 0
	for problem in _problems:
		if shown >= 12:
			print("  ... and %d more" % (_problems.size() - shown))
			break
		print("  - %s" % problem)
		shown += 1
	print("")
	quit(1)


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

func _better(a: Dictionary, b: Dictionary) -> bool:
	if bool(a["won"]) != bool(b["won"]):
		return bool(a["won"])
	if int(a["wave_reached"]) != int(b["wave_reached"]):
		return int(a["wave_reached"]) > int(b["wave_reached"])
	return int(a["lives"]) > int(b["lives"])


func _win_rate(runs: Array) -> float:
	if runs.is_empty():
		return 0.0
	var wins: int = 0
	for run in runs:
		if bool(run["won"]):
			wins += 1
	return float(wins) / float(runs.size())


func _avg(runs: Array, key: String) -> float:
	if runs.is_empty():
		return 0.0
	var total: float = 0.0
	for run in runs:
		total += float(run[key])
	return total / float(runs.size())


func _wave_count(runs: Array) -> int:
	return int(runs[0]["wave_count"]) if not runs.is_empty() else 0


func _filter(runs: Array, key: String, value) -> Array:
	var out: Array = []
	for run in runs:
		if run[key] == value:
			out.append(run)
	return out


func _distinct(runs: Array, key: String) -> Array:
	var seen: Array = []
	for run in runs:
		if not seen.has(run[key]):
			seen.append(run[key])
	seen.sort()
	return seen


func _sorted_keys(dict: Dictionary) -> Array:
	var keys: Array = dict.keys()
	keys.sort()
	return keys


func _percent(fraction: float) -> String:
	return "%.1f%%" % (fraction * 100.0)


func _maps_to_run(options: Dictionary) -> Array:
	var wanted: String = str(options.get("map", ""))
	var out: Array = []
	var ids: Array = _catalog.maps.keys()
	ids.sort()
	for id in ids:
		if wanted == "" or str(id) == wanted:
			out.append(_catalog.maps[id])
	return out


## Args after `--`, as `--key=value`. Everything has a default so the bare
## command is the useful one.
func _parse_args() -> Dictionary:
	var options: Dictionary = {"credits": [], "seeds": [1]}
	for raw in OS.get_cmdline_user_args():
		var arg: String = str(raw)
		if not arg.begins_with("--"):
			continue
		if not arg.contains("="):
			# Bare flags.
			if arg == "--gates":
				options["gates"] = true
			continue
		var parts: PackedStringArray = arg.substr(2).split("=", true, 1)
		var key: String = parts[0]
		var value: String = parts[1]
		match key:
			"map":
				options["map"] = value
			"credits":
				for piece in value.split(",", false):
					options["credits"].append(int(piece))
			"seeds":
				var seeds: Array = []
				for piece in value.split(",", false):
					seeds.append(int(piece))
				options["seeds"] = seeds
			"order":
				options["order"] = Array(value.split(",", false))
			"bonus":
				options["bonus"] = []
				for piece in value.split(",", false):
					options["bonus"].append(int(piece))
	if options["credits"].is_empty():
		options["credits"] = [0]  # 0 means "whatever the map ships with"
	return options


## Applies the sweepable map-level knobs and returns what they were, so the
## caller can put the resource back. MapDef is a shared loaded Resource - a run
## that leaves it modified poisons every run after it.
func _override_map(map_def, starting_credits: int, bonus: int) -> Dictionary:
	var previous: Dictionary = {
		"credits": map_def.starting_credits,
		"bonus": map_def.wave_clear_bonus,
	}
	if starting_credits > 0:
		map_def.starting_credits = starting_credits
	if bonus >= 0:
		map_def.wave_clear_bonus = bonus
	return previous


func _restore_map(map_def, previous: Dictionary) -> void:
	map_def.starting_credits = int(previous["credits"])
	map_def.wave_clear_bonus = int(previous["bonus"])
