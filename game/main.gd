extends Node3D
## Entry point and application shell. Owns the menu, the fixed-timestep loop, and
## the lifetime of a match.
##
## Deliberately the ONLY place that advances simulation time. If you find
## yourself calling `Simulation.step()` anywhere else, stop and reconsider.
##
## Until this round it booted straight into `catalog.first_map()`. There are two
## maps; the second had no door. A match is now something that gets started with
## a chosen map id and torn down again, which is the whole of the change - the
## loop below is untouched.

const Types := preload("res://sim/sim_types.gd")
const SimulationScript := preload("res://sim/simulation.gd")
const CatalogScript := preload("res://data/catalog.gd")
const LevelScript := preload("res://game/level.gd")
const HudScript := preload("res://game/ui/hud.gd")
const MainMenuScript := preload("res://game/ui/main_menu.gd")
const InputActions := preload("res://game/input_actions.gd")
const AppSettings := preload("res://game/app_settings.gd")

## Guard against the spiral of death after a stall or a breakpoint.
const MAX_TICKS_PER_FRAME: int = 8

## Every match uses this seed. Replays and the balance harness both key off it,
## and a wall-clock seed would make a reported bug unreproducible.
const MATCH_SEED: int = 20260810

var catalog
var sim
var level: Node3D
var hud: CanvasLayer
var menu: CanvasLayer

var _accumulator: float = 0.0
var speed_multiplier: float = 1.0
var paused: bool = false
var _current_map_id: String = ""


func _ready() -> void:
	# Before anything can read an action. Also installs any saved rebinds.
	AppSettings.ensure_loaded()

	catalog = CatalogScript.load_default()
	var problems: PackedStringArray = catalog.validate()
	for problem in problems:
		push_error("Content validation: %s" % problem)

	menu = MainMenuScript.new()
	menu.name = "MainMenu"
	add_child(menu)
	menu.build(catalog)
	menu.map_chosen.connect(start_match)
	menu.quit_pressed.connect(func() -> void: get_tree().quit())
	menu.open()

	# `--map=<id>` boots straight past the menu. This exists for the headless
	# boot check: `--quit-after 600` with no arguments now lands on the title
	# screen, so without a way through it the smoke run stops proving that a
	# board, a sim and a HUD can be built at all. See the report - the gate
	# itself lives in scripts/, which is not this agent's to edit.
	var requested: String = _requested_map_id()
	if requested != "":
		start_match(requested)


## Reads `--map=<id>` or `--map <id>` from the arguments after `--`.
static func _requested_map_id() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index in args.size():
		var arg: String = args[index]
		if arg.begins_with("--map="):
			return arg.substr(6)
		if arg == "--map" and index + 1 < args.size():
			return args[index + 1]
	return ""


# ---------------------------------------------------------------------------
# Match lifetime
# ---------------------------------------------------------------------------

func start_match(map_id: String) -> void:
	var map_def = catalog.get_map(map_id)
	if map_def == null:
		push_error("No map '%s' in res://data/maps." % map_id)
		return

	end_match()
	_current_map_id = map_id

	sim = SimulationScript.new()
	if not sim.setup(map_def, catalog, MATCH_SEED):
		push_error("Simulation setup failed: %s" % sim.setup_error)
		sim = null
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
	hud.upgrade_requested.connect(_on_upgrade_requested)
	hud.tower_sell_requested.connect(_on_sell_requested)
	hud.resume_pressed.connect(func() -> void: set_paused(false))
	hud.restart_pressed.connect(func() -> void: start_match(_current_map_id))
	hud.quit_to_menu_pressed.connect(quit_to_menu)

	level.build_requested.connect(_on_build_requested)
	level.sell_requested.connect(_on_sell_requested)
	level.tower_inspected.connect(_on_tower_inspected)

	_accumulator = 0.0
	speed_multiplier = 1.0
	set_paused(false)
	menu.close()


## Frees the match outright rather than hiding it. A Level holds a board, a
## lighting rig and every view node in play; leaving one parked behind the menu
## while another is built is how a second match runs at half the frame rate.
func end_match() -> void:
	if hud != null:
		hud.queue_free()
		hud = null
	if level != null:
		level.queue_free()
		level = null
	sim = null


func quit_to_menu() -> void:
	end_match()
	_current_map_id = ""
	paused = false
	menu.open()


func set_paused(value: bool) -> void:
	paused = value
	if hud == null:
		return
	if value:
		hud.open_pause_menu()
	else:
		hud.close_pause_menu()


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
		level.play_denied()
		return
	sim.try_build(cell, tower_id)


func _on_sell_requested(cell: Vector2i) -> void:
	if not sim.try_sell(cell):
		hud.flash_message("nothing to sell there")
		level.play_denied()
		return
	# The panel is inspecting a tower that no longer exists.
	level.clear_selection()
	hud.close_tower_panel()


func _on_tower_inspected(cell: Vector2i) -> void:
	hud.inspect_tower(cell)


## The upgrade command, routed through apply_command rather than through
## `Simulation.try_upgrade()`, so that when save and replay land it is already in
## the command log instead of being a second door into the simulation.
##
## The refusal message comes from the sim, which is the only thing that knows why
## - it enforces the ladder rule as well as the price.
func _on_upgrade_requested(tower_id: int, def_id: String) -> void:
	var reason: String = ""
	if sim.has_method("upgrade_blocked_reason"):
		reason = str(sim.upgrade_blocked_reason(tower_id, def_id))
	if reason == "" and sim.apply_command(SimulationScript.COMMAND_UPGRADE,
			{"tower_id": tower_id, "def_id": def_id}):
		return
	hud.flash_message(reason if reason != "" else "cannot upgrade that")
	level.play_denied()


## Every binding goes through the InputMap now - see game/input_actions.gd for
## why the actions are registered in code. The raw `match event.keycode` this
## replaced was twelve keys that could not be rebound and were written down
## nowhere.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if sim == null:
		# On the menu. Escape backs out a page; the menu says whether it used it.
		if event.is_action_pressed("bl_cancel"):
			menu.back()
		return

	if event.is_action_pressed("bl_pause"):
		set_paused(not paused)
		return

	if event.is_action_pressed("bl_cancel"):
		# Escape unwinds one layer at a time: settings, then pause, then the
		# current selection. Doing all three at once means a player who opened
		# settings by accident loses their tower selection closing it.
		if hud.pause_settings_open():
			hud.open_pause_menu()
		elif paused:
			set_paused(false)
		else:
			level.set_ghost_tower("")
			level.set_sell_mode(false)
			level.clear_selection()
			hud.clear_selection()
		return

	if paused:
		return

	if event.is_action_pressed("bl_start_wave"):
		sim.start_next_wave()
	elif event.is_action_pressed("bl_sell_mode"):
		hud.toggle_sell_mode()
	else:
		for index in 4:
			if event.is_action_pressed("bl_tower_%d" % (index + 1)):
				hud.select_tower_by_index(index)
				return
