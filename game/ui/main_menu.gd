extends CanvasLayer
## Title screen, level select and settings.
##
## ## Why this exists
##
## `game/main.gd` used to call `catalog.first_map()`. There are two maps. The
## second one - ten waves of it - was unreachable from a running build: not
## broken, just with no door. This is the door.
##
## ## Gating
##
## `docs/design/campaign.md` had not been written when this was built, so every
## map is listed and every map is unlocked. The decision it will make - gated
## ladder, flat list, or hub - lands in exactly one function here,
## `_lock_reason()`. It already returns a string that the card renders as the
## reason a map is unavailable, so a gated campaign needs that function's body
## and nothing else; the disabled rendering, the reason text and the layout are
## all in place.

signal map_chosen(map_id: String)
signal quit_pressed()

const SettingsPanelScript := preload("res://game/ui/settings_panel.gd")
const AppSettings := preload("res://game/app_settings.gd")

const COLOR_TITLE := Color(0.95, 0.97, 1.0)
const COLOR_SUB := Color(0.62, 0.72, 0.84)
const COLOR_STAT := Color(0.80, 0.86, 0.94)
const COLOR_LOCKED := Color(0.55, 0.50, 0.48)

var catalog

var _pages: Dictionary = {}
var _map_list: VBoxContainer
var _settings: PanelContainer


func build(catalog_ref) -> void:
	catalog = catalog_ref
	AppSettings.ensure_loaded()
	layer = 10

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.05, 0.07, 0.10, 1.0)
	add_child(backdrop)

	_build_title_page()
	_build_select_page()
	_build_settings_page()
	show_page("title")


# ---------------------------------------------------------------------------
# Pages
# ---------------------------------------------------------------------------

func _page(id: String) -> VBoxContainer:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.visible = false
	add_child(centre)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	centre.add_child(column)

	_pages[id] = centre
	return column


func show_page(id: String) -> void:
	for key in _pages:
		_pages[key].visible = str(key) == id
	if id == "settings":
		_settings.open()


func _build_title_page() -> void:
	var column := _page("title")

	var title := _text("BASTION LINE", COLOR_TITLE, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var tagline := _text("Hold the line.", COLOR_SUB, 18)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)

	column.add_child(_spacer(24))
	_button(column, "Play", func() -> void: show_page("select"))
	_button(column, "Settings", func() -> void: show_page("settings"))
	_button(column, "Quit", func() -> void: quit_pressed.emit())


func _build_select_page() -> void:
	var column := _page("select")

	var title := _text("Select a map", COLOR_TITLE, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_spacer(8))

	_map_list = VBoxContainer.new()
	_map_list.add_theme_constant_override("separation", 10)
	column.add_child(_map_list)

	column.add_child(_spacer(8))
	_button(column, "Back", func() -> void: show_page("title"))


func _build_settings_page() -> void:
	var column := _page("settings")
	_settings = SettingsPanelScript.new()
	_settings.name = "Settings"
	column.add_child(_settings)
	_settings.build()
	_settings.closed.connect(func() -> void: show_page("title"))


# ---------------------------------------------------------------------------
# Level select
# ---------------------------------------------------------------------------

## Rebuilt on every entry to the menu rather than once at build, so a map added
## to `data/maps/` while the game is running still appears - and so a future
## gating rule that depends on progress is re-evaluated after every match.
func refresh_maps() -> void:
	for child in _map_list.get_children():
		_map_list.remove_child(child)
		child.queue_free()

	var ids: Array = _map_ids()
	if ids.is_empty():
		_map_list.add_child(_text("No maps found in data/maps.", COLOR_LOCKED, 16))
		return
	for index in ids.size():
		_map_list.add_child(_map_card(str(ids[index]), index))


func _map_card(map_id: String, index: int) -> Control:
	var def = catalog.get_map(map_id)
	var reason: String = _lock_reason(map_id, index)
	var unlocked: bool = reason == ""

	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)

	var button := Button.new()
	button.custom_minimum_size = Vector2(420, 44)
	button.text = str(def.display_name) if def != null else map_id
	button.disabled = not unlocked
	if unlocked:
		button.pressed.connect(func() -> void: map_chosen.emit(map_id))
	card.add_child(button)

	var detail: String = reason
	if unlocked and def != null:
		# Read off the def rather than hardcoded: a map's own numbers are the
		# only honest preview of what it is, and they change under balance.
		detail = "%d waves   %d credits   %d lives   %s" % [
			def.wave_ids.size(), def.starting_credits, def.starting_lives,
			_grid_size(def)]
	var line := _text(detail, COLOR_STAT if unlocked else COLOR_LOCKED, 13)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(line)
	return card


## Board dimensions, from the same ASCII the pathfinder walks. Cheap, and it
## makes the difference between the two shipped maps legible before committing
## to ten waves of one.
static func _grid_size(def) -> String:
	var rows: PackedStringArray = def.layout_rows()
	if rows.is_empty():
		return "?"
	return "%d x %d" % [rows[0].length(), rows.size()]


## THE GATING HOOK. Returns "" for playable, or the reason it is not.
##
## Everything is unlocked because `docs/design/campaign.md` does not exist yet.
## When it does, this is the function that implements it and the only one that
## needs to change - a gated ladder is
##
##     if index > 0 and not _completed(previous_id): return "Finish %s first"
##
## which needs a completion record; there is deliberately none yet, because
## inventing a save format before the design that needs it is how you get the
## wrong one.
func _lock_reason(_map_id: String, _index: int) -> String:
	return ""


## Prefers a public `map_ids()` if the catalog grows one - it has `tower_ids()`
## and `all_tower_ids()` but nothing for maps, so this reaches into `maps` for
## now. Worth a one-line addition on the data side; flagged rather than done,
## because `data/` is not this agent's to edit.
func _map_ids() -> Array:
	if catalog == null:
		return []
	if catalog.has_method("map_ids"):
		return catalog.map_ids()
	var ids: Array = catalog.maps.keys()
	ids.sort()
	return ids


# ---------------------------------------------------------------------------

func open() -> void:
	visible = true
	refresh_maps()
	show_page("title")


func close() -> void:
	visible = false


## Escape backs out one page rather than doing nothing. Returns true when it
## handled the key, so main.gd knows not to also act on it.
func back() -> bool:
	if not visible:
		return false
	for key in _pages:
		if _pages[key].visible and str(key) != "title":
			show_page("title")
			return true
	return false


func _button(column: VBoxContainer, text: String, on_press: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(300, 42)
	button.text = text
	button.pressed.connect(on_press)
	column.add_child(button)


static func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


static func _text(value: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	return label
