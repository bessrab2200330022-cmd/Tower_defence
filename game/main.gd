extends Node3D
## Entry point. Owns the fixed-timestep loop and wires sim <-> view <-> HUD.
##
## Deliberately the ONLY place that advances simulation time. If you find
## yourself calling `Simulation.step()` anywhere else, stop and reconsider.

const Types := preload("res://sim/sim_types.gd")
const SimulationScript := preload("res://sim/simulation.gd")
const CatalogScript := preload("res://data/catalog.gd")
const LevelScript := preload("res://game/level.gd")
const HudScript := preload("res://game/ui/hud.gd")

## Guard against the spiral of death after a stall or a breakpoint.
const MAX_TICKS_PER_FRAME: int = 8

var catalog
var sim
var level: Node3D
var hud: CanvasLayer

var _accumulator: float = 0.0
var speed_multiplier: float = 1.0
var paused: bool = false


func _ready() -> void:
	catalog = CatalogScript.load_default()
	var problems: PackedStringArray = catalog.validate()
	for problem in problems:
		push_error("Content validation: %s" % problem)

	var map_def = catalog.first_map()
	if map_def == null:
		push_error("No maps found in res://data/maps. Cannot start.")
		return

	sim = SimulationScript.new()
	if not sim.setup(map_def, catalog, 20260810):
		push_error("Simulation setup failed: %s" % sim.setup_error)
		return

	level = LevelScript.new()
	level.name = "Level"
	add_child(level)
	level.build(sim, catalog, map_def)

	hud = HudScript.new()
	hud.name = "Hud"
	add_child(hud)
	hud.build(sim, catalog)
	hud.tower_selected.connect(_on_tower_selected)
	hud.sell_mode_toggled.connect(_on_sell_mode_toggled)
	hud.start_wave_pressed.connect(_on_start_wave_pressed)
	hud.speed_changed.connect(_on_speed_changed)

	level.build_requested.connect(_on_build_requested)
	level.sell_requested.connect(_on_sell_requested)


func _process(delta: float) -> void:
	if sim == null or level == null:
		return

	if not paused and not sim.is_over():
		_accumulator += delta * speed_multiplier
		var ticks: int = 0
		while _accumulator >= Types.TICK_DELTA and ticks < MAX_TICKS_PER_FRAME:
			_accumulator -= Types.TICK_DELTA
			# Snapshot where everything is BEFORE the step, so the views have a
			# position to interpolate from. It has to sit inside the loop rather
			# than in front of it: after a catch-up burst the interpolation
			# source must be the second-to-last tick, not wherever the entities
			# happened to be at the end of the previous frame.
			level.capture_tick_start()
			sim.step()
			ticks += 1
		if _accumulator > Types.TICK_DELTA * float(MAX_TICKS_PER_FRAME):
			_accumulator = 0.0

	level.consume_events(sim.drain_events())
	level.sync(delta, _tick_fraction())
	hud.refresh()


## How far the renderer stands between the last simulated tick and the next one,
## as 0..1. Views blend across it so motion stays smooth on a display that does
## not happen to refresh at the simulation's 60 Hz.
##
## Paused or finished, the sim is not going anywhere, so hold exactly on the
## last tick rather than easing toward a future that will never be simulated.
func _tick_fraction() -> float:
	if paused or sim.is_over():
		return 1.0
	return clampf(_accumulator / Types.TICK_DELTA, 0.0, 1.0)


func _on_tower_selected(tower_id: String) -> void:
	level.set_ghost_tower(tower_id)


func _on_sell_mode_toggled(enabled: bool) -> void:
	level.set_sell_mode(enabled)


func _on_start_wave_pressed() -> void:
	sim.start_next_wave()


func _on_speed_changed(multiplier: float) -> void:
	if multiplier <= 0.0:
		paused = true
	else:
		paused = false
		speed_multiplier = multiplier


func _on_build_requested(cell: Vector2i, tower_id: String) -> void:
	var reason: String = sim.build_blocked_reason(cell, tower_id)
	if reason != "":
		hud.flash_message(reason)
		return
	sim.try_build(cell, tower_id)


func _on_sell_requested(cell: Vector2i) -> void:
	if not sim.try_sell(cell):
		hud.flash_message("nothing to sell there")


func _unhandled_input(event: InputEvent) -> void:
	if sim == null or level == null or hud == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				sim.start_next_wave()
			KEY_ESCAPE:
				level.set_ghost_tower("")
				level.set_sell_mode(false)
				hud.clear_selection()
			KEY_1, KEY_2, KEY_3, KEY_4:
				var index: int = event.keycode - KEY_1
				hud.select_tower_by_index(index)
			KEY_X:
				hud.toggle_sell_mode()
			KEY_P:
				paused = not paused
