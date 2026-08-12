extends Control
## The in-match pause menu, plus the settings panel reached from it.
##
## Lives inside `game/ui/hud.gd` rather than alongside the main menu in
## `game/main.gd`, for a reason worth writing down: `tests/run_autoplay.gd` builds
## a real Hud, and nothing in the project builds a Level or a Hud any other way.
## Anything hosted here is constructed by the only check that executes view code
## at all. Anything hosted by main.gd is not executed by any gate.
##
## So the split is: pre-match UI (title, level select) belongs to main.gd and is
## uncovered; in-match UI (this) belongs to the Hud and is at least built on
## every autoplay run. Where a piece of UI could reasonably live in either, it
## goes here.

signal resume_pressed()
signal restart_pressed()
signal quit_to_menu_pressed()

const SettingsPanelScript := preload("res://game/ui/settings_panel.gd")

var _settings: PanelContainer
var _buttons: VBoxContainer


func build() -> void:
	# set_anchors_AND_OFFSETS_preset, not set_anchors_preset. The latter leaves a
	# fresh Control's offsets alone, and nested inside the Hud's root Control that
	# leaves this node zero-sized: the dim never covers anything and the buttons
	# pile up in the top-left corner over the credits readout. Caught by looking
	# at a rendered frame - it is invisible to every headless check, which all
	# report a perfectly healthy hidden panel.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# STOP, not IGNORE: a paused game must not let a click through to the board
	# behind it and build a tower the player cannot see themselves building.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	centre.add_child(_buttons)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buttons.add_child(title)

	_add_button("Resume", func() -> void: resume_pressed.emit())
	_add_button("Settings", _open_settings)
	_add_button("Restart map", func() -> void: restart_pressed.emit())
	_add_button("Abandon to menu", func() -> void: quit_to_menu_pressed.emit())

	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	_settings = SettingsPanelScript.new()
	_settings.name = "Settings"
	_settings.visible = false
	holder.add_child(_settings)
	_settings.build()
	_settings.closed.connect(_close_settings)


func _add_button(text: String, on_press: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(280, 40)
	button.text = text
	button.pressed.connect(on_press)
	_buttons.add_child(button)


func open() -> void:
	visible = true
	_buttons.visible = true
	_settings.visible = false


func close() -> void:
	visible = false
	_settings.visible = false


## True while the settings sheet is up. game/main.gd asks, so that Escape backs
## out of settings rather than unpausing straight past it.
func settings_open() -> bool:
	return _settings != null and _settings.visible


func _open_settings() -> void:
	_buttons.visible = false
	_settings.open()


func _close_settings() -> void:
	_settings.visible = false
	_buttons.visible = true
