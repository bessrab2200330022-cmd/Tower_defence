extends PanelContainer
## Resolution, volume and key rebinding.
##
## One panel, instantiated twice - once by the main menu and once by the pause
## menu - rather than reparented between them. Reparenting a Control between two
## CanvasLayers is a reliable source of focus and visibility bugs, and this thing
## holds no state of its own: it reads AppSettings when it opens and writes back
## on change, so two copies cannot disagree.

signal closed()

const InputActions := preload("res://game/input_actions.gd")
const AppSettings := preload("res://game/app_settings.gd")

const COLOR_TITLE := Color(0.93, 0.96, 1.0)
const COLOR_LABEL := Color(0.66, 0.74, 0.84)
const COLOR_KEY := Color(0.98, 0.85, 0.45)
const COLOR_WARN := Color(1.0, 0.5, 0.45)

var _resolution_button: OptionButton
var _master_slider: HSlider
var _effects_slider: HSlider
var _binding_buttons: Dictionary = {}
var _notice: Label

## The action currently waiting for a keypress, or "" when not rebinding. While
## this is set the panel swallows every key, which is what stops the Escape that
## cancels rebinding also closing the menu underneath.
var _capturing: String = ""


func build() -> void:
	AppSettings.ensure_loaded()
	custom_minimum_size = Vector2(460, 0)

	var inset := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inset.add_theme_constant_override(str(side), 16)
	add_child(inset)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	inset.add_child(column)

	column.add_child(_label("Settings", COLOR_TITLE, 24))
	column.add_child(HSeparator.new())

	# Seventeen rebindable actions plus video and audio is taller than a 720p
	# viewport, and what fell off the bottom was the Save button - the one control
	# that makes the rest of the screen mean anything. Scrolling the settings and
	# pinning the buttons outside the scroll is the fix. Found by looking at a
	# rendered frame at the smallest resolution the game offers.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	var scrolled := VBoxContainer.new()
	scrolled.add_theme_constant_override("separation", 8)
	scrolled.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scrolled)

	_build_video(scrolled)
	_build_audio(scrolled)
	_build_bindings(scrolled)

	_notice = _label("", COLOR_WARN, 13)
	column.add_child(_notice)

	column.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)

	var defaults := Button.new()
	defaults.text = "Reset keys"
	defaults.pressed.connect(_on_reset_bindings)
	row.add_child(defaults)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var save := Button.new()
	save.text = "Save"
	save.pressed.connect(func() -> void:
		AppSettings.save()
		_say("Saved.", COLOR_LABEL))
	row.add_child(save)

	var close := Button.new()
	close.text = "Back"
	close.pressed.connect(func() -> void: closed.emit())
	row.add_child(close)


func _build_video(column: VBoxContainer) -> void:
	column.add_child(_label("Video", COLOR_LABEL, 15))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	row.add_child(_label("Resolution", COLOR_LABEL, 14))

	_resolution_button = OptionButton.new()
	_resolution_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for size in AppSettings.RESOLUTIONS:
		var value: Vector2i = size
		_resolution_button.add_item("%d x %d" % [value.x, value.y])
	_resolution_button.selected = AppSettings.resolution_index
	_resolution_button.item_selected.connect(func(index: int) -> void:
		AppSettings.resolution_index = index
		AppSettings.apply_resolution())
	row.add_child(_resolution_button)


func _build_audio(column: VBoxContainer) -> void:
	column.add_child(_label("Audio", COLOR_LABEL, 15))
	_master_slider = _volume_row(column, "Master", AppSettings.master_volume,
		func(value: float) -> void:
			AppSettings.master_volume = value
			AppSettings.apply_audio())
	_effects_slider = _volume_row(column, "Effects", AppSettings.effects_volume,
		func(value: float) -> void:
			AppSettings.effects_volume = value)


func _volume_row(column: VBoxContainer, text: String, value: float, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)

	var name_label := _label(text, COLOR_LABEL, 14)
	name_label.custom_minimum_size = Vector2(80, 0)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var readout := _label("%d%%" % int(round(value * 100.0)), COLOR_KEY, 14)
	readout.custom_minimum_size = Vector2(48, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)

	slider.value_changed.connect(func(new_value: float) -> void:
		readout.text = "%d%%" % int(round(new_value * 100.0))
		on_change.call(new_value))
	return slider


## One button per action, grouped the way the table groups them. Pressing a
## button arms capture; the next key pressed becomes that action's binding.
func _build_bindings(column: VBoxContainer) -> void:
	column.add_child(_label("Controls", COLOR_LABEL, 15))
	for group in InputActions.groups():
		column.add_child(_label(str(group), COLOR_LABEL, 13))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16)
		column.add_child(grid)
		for action in InputActions.actions_in(str(group)):
			var action_name: String = str(action)
			grid.add_child(_label(InputActions.label_for(action_name), COLOR_LABEL, 14))
			var button := Button.new()
			button.custom_minimum_size = Vector2(150, 26)
			button.text = InputActions.key_name(InputActions.primary_keycode(action_name))
			button.pressed.connect(_on_rebind_pressed.bind(action_name))
			grid.add_child(button)
			_binding_buttons[action_name] = button


func _on_rebind_pressed(action: String) -> void:
	_capturing = action
	_binding_buttons[action].text = "press a key"
	_say("Press a key for '%s', or Escape to cancel." % InputActions.label_for(action), COLOR_LABEL)


func _on_reset_bindings() -> void:
	AppSettings.reset_bindings()
	_refresh_bindings()
	_say("Controls reset to defaults.", COLOR_LABEL)


func _refresh_bindings() -> void:
	for action in _binding_buttons:
		_binding_buttons[action].text = InputActions.key_name(
			InputActions.primary_keycode(str(action)))


## Capture runs on _input, not _unhandled_input: a rebind has to see the key
## before anything else does, including the game action that key is currently
## bound to.
func _input(event: InputEvent) -> void:
	if _capturing == "" or not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: InputEventKey = event
	get_viewport().set_input_as_handled()

	var action: String = _capturing
	_capturing = ""

	var keycode: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if keycode == KEY_ESCAPE:
		_refresh_bindings()
		_say("Cancelled.", COLOR_LABEL)
		return

	var clash: String = InputActions.conflict_for(action, keycode)
	if clash != "":
		_refresh_bindings()
		_say("%s is already '%s'." % [InputActions.key_name(keycode),
			InputActions.label_for(clash)], COLOR_WARN)
		return

	AppSettings.rebind(action, keycode)
	_refresh_bindings()
	_say("Bound to %s. Press Save to keep it." % InputActions.key_name(keycode), COLOR_LABEL)


func open() -> void:
	AppSettings.ensure_loaded()
	_resolution_button.selected = AppSettings.resolution_index
	_master_slider.value = AppSettings.master_volume
	_effects_slider.value = AppSettings.effects_volume
	_capturing = ""
	_refresh_bindings()
	_say("", COLOR_LABEL)
	visible = true


func _say(text: String, color: Color) -> void:
	if _notice == null:
		return
	_notice.text = text
	_notice.add_theme_color_override("font_color", color)


static func _label(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	return label
