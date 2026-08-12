extends RefCounted
## The game's InputMap layer. One table, registered at runtime.
##
## Every binding in the game used to be a raw keycode in a `match` statement -
## `KEY_SPACE` in main.gd, `KEY_Q` in rts_camera.gd - which meant rebinding was
## impossible and the full list of controls existed nowhere. This is that list.
##
## ## Why the actions are registered in code rather than in project.godot
##
## `project.godot` is the lead's file, not this agent's, and an `[input]` section
## edited from here would be a change outside `game/`. It is also the better
## engineering answer: the defaults live next to the labels the settings screen
## shows and the code that reads them, so adding a binding is one line in one
## table instead of a project file edit plus a UI edit plus a handler.
##
## The cost is that `ensure_installed()` has to run before anything reads an
## action. It is idempotent and called from every entry point that can be first -
## game/main.gd, game/level.gd and game/ui/hud.gd - because `tests/run_autoplay.gd`
## builds a Level and a Hud without ever going through main.gd.

## Prefix on every action this game defines, so nothing here can collide with
## Godot's built-in `ui_*` actions.
const PREFIX: String = "bl_"

## The whole control scheme, in the order the settings screen lists it.
##
##   action   the InputMap name
##   label    what the player is shown
##   keys     default keycodes; the first is the one rebinding replaces
##   group    heading in the settings list
const ACTIONS: Array = [
	{"action": "bl_start_wave", "label": "Start wave", "keys": [KEY_SPACE], "group": "Game"},
	{"action": "bl_pause", "label": "Pause", "keys": [KEY_P], "group": "Game"},
	{"action": "bl_cancel", "label": "Cancel / menu", "keys": [KEY_ESCAPE], "group": "Game"},
	{"action": "bl_sell_mode", "label": "Sell mode", "keys": [KEY_X], "group": "Game"},

	{"action": "bl_tower_1", "label": "Select tower 1", "keys": [KEY_1], "group": "Building"},
	{"action": "bl_tower_2", "label": "Select tower 2", "keys": [KEY_2], "group": "Building"},
	{"action": "bl_tower_3", "label": "Select tower 3", "keys": [KEY_3], "group": "Building"},
	{"action": "bl_tower_4", "label": "Select tower 4", "keys": [KEY_4], "group": "Building"},

	{"action": "bl_pan_forward", "label": "Pan forward", "keys": [KEY_W, KEY_UP], "group": "Camera"},
	{"action": "bl_pan_back", "label": "Pan back", "keys": [KEY_S, KEY_DOWN], "group": "Camera"},
	{"action": "bl_pan_left", "label": "Pan left", "keys": [KEY_A, KEY_LEFT], "group": "Camera"},
	{"action": "bl_pan_right", "label": "Pan right", "keys": [KEY_D, KEY_RIGHT], "group": "Camera"},
	{"action": "bl_orbit_left", "label": "Orbit left", "keys": [KEY_Q], "group": "Camera"},
	{"action": "bl_orbit_right", "label": "Orbit right", "keys": [KEY_E], "group": "Camera"},
	{"action": "bl_tilt_down", "label": "Tilt down", "keys": [KEY_R], "group": "Camera"},
	{"action": "bl_tilt_up", "label": "Tilt up", "keys": [KEY_F], "group": "Camera"},
	{"action": "bl_camera_reset", "label": "Reset camera", "keys": [KEY_HOME], "group": "Camera"},
]

## Tracks whether the table has been pushed into the InputMap this run. A static
## var rather than a check per action, so the common case is one boolean.
static var _installed: bool = false


## Registers every action, unless it already is. Safe to call from anywhere, any
## number of times.
##
## `overrides` maps an action name to a keycode and comes from the player's saved
## settings; anything absent keeps its default.
##
## `force` rebuilds even when the table is already installed. Resetting to
## defaults passes an EMPTY overrides dictionary, which is indistinguishable from
## the no-op first call unless the caller says so - so without this, "Reset keys"
## silently did nothing. Found by driving the settings screen rather than by
## reading it.
static func ensure_installed(overrides: Dictionary = {}, force: bool = false) -> void:
	if _installed and not force and overrides.is_empty():
		return
	for entry in ACTIONS:
		var spec: Dictionary = entry
		var action: String = str(spec["action"])
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var keys: Array = spec["keys"]
		var primary: int = int(overrides.get(action, keys[0]))
		# Rebuilt from scratch rather than added to, or applying a rebind twice
		# leaves the old key working alongside the new one.
		InputMap.action_erase_events(action)
		_add_key(action, primary)
		# Secondary defaults (the arrow keys) survive a rebind of the primary.
		for index in range(1, keys.size()):
			if int(keys[index]) != primary:
				_add_key(action, int(keys[index]))
	_installed = true


static func _add_key(action: String, keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


## The key the settings screen shows and rebinding replaces: the first key event
## on the action.
static func primary_keycode(action: String) -> int:
	if not InputMap.has_action(action):
		return KEY_NONE
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: InputEventKey = event
			return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	return KEY_NONE


static func key_name(keycode: int) -> String:
	if keycode == KEY_NONE:
		return "unbound"
	return OS.get_keycode_string(keycode)


static func label_for(action: String) -> String:
	for entry in ACTIONS:
		if str(entry["action"]) == action:
			return str(entry["label"])
	return action


## Which other action already owns a key, or "" if it is free. Rebinding onto a
## key that is taken silently makes one of the two dead, so the settings screen
## refuses instead.
static func conflict_for(action: String, keycode: int) -> String:
	for entry in ACTIONS:
		var other: String = str(entry["action"])
		if other == action:
			continue
		if primary_keycode(other) == keycode:
			return other
	return ""


static func default_keycode(action: String) -> int:
	for entry in ACTIONS:
		if str(entry["action"]) == action:
			return int((entry["keys"] as Array)[0])
	return KEY_NONE


## Actions in `group`, in table order.
static func actions_in(group: String) -> Array:
	var out: Array = []
	for entry in ACTIONS:
		if str(entry["group"]) == group:
			out.append(str(entry["action"]))
	return out


static func groups() -> Array:
	var out: Array = []
	for entry in ACTIONS:
		var group: String = str(entry["group"])
		if not out.has(group):
			out.append(group)
	return out
