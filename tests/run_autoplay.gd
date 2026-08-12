extends SceneTree
## Headless autoplay: drives the REAL view layer through a whole match.
##
##   godot --headless --path . --script res://tests/run_autoplay.gd
##
## Why this exists. `--quit-after` boots the game, but nothing starts a wave
## without a keypress, so the plain smoke run never renders an enemy, a tower, a
## projectile or an effect - the entire contents of `game/views/` and most of
## `game/level.gd` go unexecuted by anything in CI. This runner plays the
## campaign from the first build to the final phase against the same Level and
## Hud the player gets.
##
## It also checks the invariant that binds the two layers together: view nodes
## are created and destroyed only from drained events, so the number of views
## must equal the number of live entities in the sim, every frame. A mismatch
## means an event went missing and a mesh has been orphaned - the exact failure
## no unit test can see, because unit tests never build a view.
##
## Exits 0 when the match completes with the invariant intact, 1 otherwise.

const Types := preload("res://sim/sim_types.gd")
const SimulationScript := preload("res://sim/simulation.gd")
const CatalogScript := preload("res://data/catalog.gd")
const LevelScript := preload("res://game/level.gd")
const HudScript := preload("res://game/ui/hud.gd")

## The sim is frame-rate independent, so batching ticks only trades wall-clock
## time against how often the views resync. Keep it above 1 to prove the views
## survive a catch-up burst, the way they must after a stalled frame.
const TICKS_PER_FRAME: int = 12
## Generous: the shipped campaign lands well under this. It is a stall detector,
## not a budget.
const MAX_TICKS: int = 60000

const SEED: int = 20260810

var _sim
var _catalog
var _level: Node3D
var _hud: CanvasLayer

var _ticks: int = 0
var _towers_built: int = 0
var _build_cells: Array[Vector2i] = []
var _failures: Array[String] = []
var _reported_wave: int = -1


func _initialize() -> void:
	print("")
	print("Autoplay: driving sim + level + hud headless")
	print("--------------------------------------------------------------")

	_catalog = CatalogScript.load_default()
	for problem in _catalog.validate():
		_fail("content: %s" % problem)

	var map_def = _catalog.first_map()
	if map_def == null:
		_fail("no maps found in res://data/maps")
		_finish()
		return

	_sim = SimulationScript.new()
	if not _sim.setup(map_def, _catalog, SEED):
		_fail("simulation setup failed: %s" % _sim.setup_error)
		_finish()
		return

	# Same wiring as game/main.gd. Building it here rather than instancing
	# main.tscn is deliberate: this runner drives time itself, where main.gd
	# drives it from wall-clock delta.
	_level = LevelScript.new()
	_level.name = "Level"
	root.add_child(_level)
	_level.build(_sim, _catalog, map_def)

	_hud = HudScript.new()
	_hud.name = "Hud"
	root.add_child(_hud)
	_hud.build(_sim, _catalog)

	_build_cells = _cells_beside_the_path()
	if _build_cells.is_empty():
		_fail("map '%s' has no buildable ground next to the path" % map_def.id)

	print("map '%s': %d waypoints, %d build sites, %d towers in the catalog"
		% [map_def.id, _sim.waypoints.size(), _build_cells.size(), _catalog.tower_ids().size()])


## Returning true ends the run. SceneTree drives node processing and the
## queue_free flush around this call, so the view nodes retired last frame are
## genuinely released - no need (and no way) to chain to a parent implementation.
func _process(delta: float) -> bool:
	if _sim == null:
		return true

	if _sim.phase == Types.Phase.BUILD:
		_spend_credits()
		_sim.start_next_wave()

	for i in TICKS_PER_FRAME:
		if _sim.is_over():
			break
		_sim.step()
		_ticks += 1

	# Exactly what main.gd does every frame, in the same order.
	_level.consume_events(_sim.drain_events())
	_level.sync(delta)
	_hud.refresh()

	_check_invariants()
	_report_wave_change()

	if _sim.is_over():
		print("match ended on tick %d: %s, %d lives left, %d towers standing"
			% [_sim.tick, _phase_name(), _sim.economy.lives, _sim.towers.size()])
		_finish()
		return true

	if _ticks >= MAX_TICKS:
		_fail("the match did not resolve within %d ticks (stalled in phase %s)"
			% [MAX_TICKS, _phase_name()])
		_finish()
		return true

	return false


# ---------------------------------------------------------------------------
# Playing
# ---------------------------------------------------------------------------

## Buildable cells that touch the route, in row-major order so the run is
## reproducible. Map-agnostic: it reads the grid rather than hardcoding a board.
func _cells_beside_the_path() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var grid = _sim.grid
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


## Buys whatever is affordable, cycling through the catalog so every tower type
## gets built - each one is a different view and a different fire mode, and the
## point of this run is to execute all of them.
func _spend_credits() -> void:
	var tower_ids: Array = _catalog.tower_ids()
	if tower_ids.is_empty():
		return
	for cell in _build_cells:
		if _sim.tower_at(cell) != null:
			continue
		if not _build_something(cell, tower_ids):
			return


## Prefers the next type in the rotation but falls through to a cheaper one, so
## a single expensive tower cannot stall the whole run behind an empty wallet.
func _build_something(cell: Vector2i, tower_ids: Array) -> bool:
	for offset in tower_ids.size():
		var tower_id: String = str(tower_ids[(_towers_built + offset) % tower_ids.size()])
		if _sim.try_build(cell, tower_id):
			_towers_built += 1
			return true
	return false


func _report_wave_change() -> void:
	var index: int = _sim.wave_director.wave_index
	if index == _reported_wave:
		return
	_reported_wave = index
	var counts: Dictionary = _level.view_counts()
	print("  wave %d/%d started on tick %-6d towers %d, views e/t/p %d/%d/%d"
		% [index + 1, _sim.wave_director.wave_count(), _sim.tick, _sim.towers.size(),
			counts["enemies"], counts["towers"], counts["projectiles"]])


# ---------------------------------------------------------------------------
# Checking
# ---------------------------------------------------------------------------

func _check_invariants() -> void:
	var counts: Dictionary = _level.view_counts()
	_expect(counts["enemies"], _sim.enemies.size(), "enemy views")
	_expect(counts["towers"], _sim.towers.size(), "tower views")
	_expect(counts["projectiles"], _sim.projectiles.size(), "projectile views")
	if _sim.dropped_spawns != 0:
		_fail("tick %d: %d spawn(s) were dropped - a wave references a missing enemy id"
			% [_sim.tick, _sim.dropped_spawns])


func _expect(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	# One report per failure kind is enough; this runs every frame.
	_fail("tick %d: %d %s for %d entities" % [_sim.tick, actual, label, expected])
	_sim = null


func _fail(message: String) -> void:
	if _failures.size() < 12:
		_failures.append(message)


func _phase_name() -> String:
	match _sim.phase:
		Types.Phase.BUILD:
			return "Build"
		Types.Phase.COMBAT:
			return "Combat"
		Types.Phase.WON:
			return "Victory"
		Types.Phase.LOST:
			return "Defeat"
	return "?"


func _finish() -> void:
	print("--------------------------------------------------------------")
	if _failures.is_empty():
		print("PASS  autoplay completed over %d ticks, views stayed in step" % _ticks)
		print("")
		quit(0)
		return

	print("FAIL  %d problem(s):" % _failures.size())
	for failure in _failures:
		print("  - %s" % failure)
	print("")
	quit(1)
