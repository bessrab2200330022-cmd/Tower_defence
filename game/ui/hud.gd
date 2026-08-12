extends CanvasLayer
## Heads-up display. Built in code from the tower catalog so a new tower .tres
## shows up in the build bar automatically.

signal tower_selected(tower_id: String)
signal sell_mode_toggled(enabled: bool)
signal start_wave_pressed()
signal speed_changed(multiplier: float)
## Forwarded straight from the inspection panel. game/main.gd turns these into
## simulation commands; the HUD itself never touches sim state.
signal upgrade_requested(tower_id: int, def_id: String)
signal tower_sell_requested(cell: Vector2i)

const Types := preload("res://sim/sim_types.gd")
const TowerPanelScript := preload("res://game/ui/tower_panel.gd")

const PHASE_LABELS := ["Build", "Combat", "Victory", "Defeat"]
const SPEED_OPTIONS := [0.0, 1.0, 2.0, 4.0]
const SPEED_LABELS := ["II", "1x", "2x", "4x"]

var sim
var catalog

var _credits_label: Label
var _lives_label: Label
var _wave_label: Label
var _phase_label: Label
var _message_label: Label
var _outcome_label: Label
var _start_button: Button
var _sell_button: Button

var _tower_panel: PanelContainer

var _tower_buttons: Array[Button] = []
var _tower_ids: Array = []
var _selected_index: int = -1
var _sell_mode: bool = false
var _message_ttl: float = 0.0


func build(simulation, catalog_ref) -> void:
	sim = simulation
	catalog = catalog_ref

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_top_bar(root)
	_build_build_bar(root)
	_build_right_controls(root)
	_build_tower_panel(root)
	_build_messages(root)


## The inspection panel sits on the left, clear of the build bar along the
## bottom and the speed controls on the right. It is hidden until a tower is
## clicked, so it costs nothing when nothing is selected.
func _build_tower_panel(root: Control) -> void:
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	holder.offset_left = 16.0
	holder.offset_top = 64.0
	holder.offset_right = 340.0
	holder.offset_bottom = -104.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)

	var align := VBoxContainer.new()
	align.alignment = BoxContainer.ALIGNMENT_BEGIN
	align.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(align)

	_tower_panel = TowerPanelScript.new()
	_tower_panel.name = "TowerPanel"
	align.add_child(_tower_panel)
	_tower_panel.build(sim, catalog)
	_tower_panel.upgrade_requested.connect(
		func(tower_id: int, def_id: String) -> void: upgrade_requested.emit(tower_id, def_id))
	_tower_panel.sell_requested.connect(
		func(cell: Vector2i) -> void: tower_sell_requested.emit(cell))


## Called by game/main.gd when game/level.gd reports a tower was clicked.
func inspect_tower(cell: Vector2i) -> void:
	if _tower_panel != null:
		_tower_panel.inspect(cell)


func close_tower_panel() -> void:
	if _tower_panel != null:
		_tower_panel.close()


func _build_top_bar(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 46.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var spacer_left := Control.new()
	spacer_left.custom_minimum_size = Vector2(12, 0)
	row.add_child(spacer_left)

	_credits_label = _make_label("Credits 0", Color(0.98, 0.85, 0.45))
	_lives_label = _make_label("Lives 0", Color(0.95, 0.5, 0.5))
	_wave_label = _make_label("Wave -/-", Color(0.85, 0.9, 1.0))
	_phase_label = _make_label("Build", Color(0.7, 0.85, 0.95))
	row.add_child(_credits_label)
	row.add_child(_lives_label)
	row.add_child(_wave_label)
	row.add_child(_phase_label)


func _build_build_bar(root: Control) -> void:
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.position = Vector2(16, -84)
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)

	_tower_ids = catalog.tower_ids()
	for i in _tower_ids.size():
		var tower_id: String = str(_tower_ids[i])
		var def = catalog.get_tower(tower_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(168, 64)
		button.toggle_mode = true
		button.text = "%d  %s\n%d cr   %.0f dps" % [i + 1, def.display_name, def.cost, def.nominal_dps()]
		button.tooltip_text = def.description
		button.pressed.connect(_on_tower_button.bind(i))
		box.add_child(button)
		_tower_buttons.append(button)

	_sell_button = Button.new()
	_sell_button.custom_minimum_size = Vector2(96, 64)
	_sell_button.toggle_mode = true
	_sell_button.text = "X\nSell"
	_sell_button.pressed.connect(_on_sell_button)
	box.add_child(_sell_button)


func _build_right_controls(root: Control) -> void:
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.position = Vector2(-360, -84)
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)

	for i in SPEED_OPTIONS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(48, 48)
		button.text = SPEED_LABELS[i]
		button.pressed.connect(_on_speed_button.bind(SPEED_OPTIONS[i]))
		box.add_child(button)

	_start_button = Button.new()
	_start_button.custom_minimum_size = Vector2(148, 48)
	_start_button.text = "Start Wave"
	_start_button.pressed.connect(func() -> void: start_wave_pressed.emit())
	box.add_child(_start_button)


func _build_messages(root: Control) -> void:
	_message_label = _make_label("", Color(1.0, 0.65, 0.5))
	_message_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message_label.position = Vector2(-140, -120)
	_message_label.custom_minimum_size = Vector2(280, 24)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_message_label)

	_outcome_label = _make_label("", Color(1.0, 1.0, 1.0))
	_outcome_label.set_anchors_preset(Control.PRESET_CENTER)
	_outcome_label.position = Vector2(-200, -30)
	_outcome_label.custom_minimum_size = Vector2(400, 60)
	_outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome_label.add_theme_font_size_override("font_size", 42)
	root.add_child(_outcome_label)


static func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

func refresh() -> void:
	if sim == null:
		return
	_credits_label.text = "Credits %d" % sim.economy.credits
	_lives_label.text = "Lives %d" % sim.economy.lives
	_wave_label.text = "Wave %d/%d" % [maxi(sim.wave_director.wave_index + 1, 0), sim.wave_director.wave_count()]
	_phase_label.text = PHASE_LABELS[clampi(sim.phase, 0, PHASE_LABELS.size() - 1)]

	_start_button.disabled = sim.phase != Types.Phase.BUILD or not sim.wave_director.has_next_wave()

	for i in _tower_buttons.size():
		var def = catalog.get_tower(str(_tower_ids[i]))
		_tower_buttons[i].disabled = def != null and not sim.economy.can_afford(def.cost) and _selected_index != i

	match sim.phase:
		Types.Phase.WON:
			_outcome_label.text = "Line held."
			_outcome_label.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6))
		Types.Phase.LOST:
			_outcome_label.text = "Line broken."
			_outcome_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
		_:
			_outcome_label.text = ""

	if _tower_panel != null:
		_tower_panel.refresh()

	if _message_ttl > 0.0:
		_message_ttl -= get_process_delta_time()
		if _message_ttl <= 0.0:
			_message_label.text = ""


func flash_message(text: String, seconds: float = 1.6) -> void:
	_message_label.text = text
	_message_ttl = seconds


func clear_selection() -> void:
	_selected_index = -1
	_sell_mode = false
	close_tower_panel()
	for button in _tower_buttons:
		button.button_pressed = false
	_sell_button.button_pressed = false
	tower_selected.emit("")
	sell_mode_toggled.emit(false)


func select_tower_by_index(index: int) -> void:
	if index < 0 or index >= _tower_buttons.size():
		return
	_tower_buttons[index].button_pressed = true
	_on_tower_button(index)


func toggle_sell_mode() -> void:
	_sell_button.button_pressed = not _sell_button.button_pressed
	_on_sell_button()


func _on_tower_button(index: int) -> void:
	_selected_index = index
	_sell_mode = false
	_sell_button.button_pressed = false
	for i in _tower_buttons.size():
		_tower_buttons[i].button_pressed = i == index
	tower_selected.emit(str(_tower_ids[index]))
	sell_mode_toggled.emit(false)


func _on_sell_button() -> void:
	_sell_mode = _sell_button.button_pressed
	if _sell_mode:
		_selected_index = -1
		for button in _tower_buttons:
			button.button_pressed = false
		tower_selected.emit("")
	sell_mode_toggled.emit(_sell_mode)


func _on_speed_button(multiplier: float) -> void:
	speed_changed.emit(multiplier)
