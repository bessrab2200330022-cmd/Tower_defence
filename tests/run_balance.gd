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
	var enemy_defs: Dictionary = {}
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
			var kind: int = int(event["type"])
			if kind == Types.Event.ENEMY_SPAWNED:
				enemy_defs[int(event["enemy_id"])] = str(event["def_id"])
			elif kind == Types.Event.ENEMY_LEAKED:
				var def_id: String = str(enemy_defs.get(int(event["enemy_id"]), "?"))
				leaks[def_id] = int(leaks.get(def_id, 0)) + 1

	if ticks >= MAX_TICKS:
		_problems.append("match stalled after %d ticks on '%s' (%s / %s / %s)"
			% [MAX_TICKS, map_def.id, placement, ",".join(PackedStringArray(order)), saving])

	var damage: Dictionary = {}
	for tower in sim.towers:
		damage[tower.def_id] = int(damage.get(tower.def_id, 0)) + tower.damage_dealt

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
		"leaks": leaks,
		"ticks": ticks,
	}


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
func _report_damage(runs: Array) -> void:
	var total: Dictionary = {}
	var instances: Dictionary = {}
	for run in runs:
		for def_id in run["damage"]:
			total[def_id] = int(total.get(def_id, 0)) + int(run["damage"][def_id])
	for run in runs:
		for def_id in run["damage"]:
			instances[def_id] = int(instances.get(def_id, 0)) + 1

	print("")
	print("  damage dealt per tower type (10x scale, towers alive at the end)")
	print("    tower           cost    total damage   per tower alive   per 100 credits")
	for def_id in _sorted_keys(total):
		var def = _catalog.get_tower(def_id)
		var cost: int = def.cost if def != null else 0
		var count: int = maxi(int(instances.get(def_id, 1)), 1)
		var per_tower: float = float(total[def_id]) / float(count)
		var per_credit: float = per_tower / float(maxi(cost, 1)) * 100.0
		print("    %-14s %5d %15d %17.0f %17.0f"
			% [def_id, cost, total[def_id], per_tower, per_credit])


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
		if not arg.begins_with("--") or not arg.contains("="):
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
	if options["credits"].is_empty():
		options["credits"] = [0]  # 0 means "whatever the map ships with"
	return options
