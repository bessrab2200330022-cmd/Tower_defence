extends RefCounted
## Player settings: volume, window size, key bindings. Loaded once at boot,
## written only when the player presses Apply.
##
## Deliberately never written implicitly. A settings file that saves itself on
## every change means the autoplay gate and every headless run touch the user's
## disk, and a crash mid-run can leave a half-written config that stops the game
## booting. Loading a missing file is silent and yields defaults.
##
## Nothing here reaches the simulation. Volume, resolution and bindings are all
## presentation, which is why this can live entirely in `game/`.

const InputActions := preload("res://game/input_actions.gd")

const PATH: String = "user://settings.cfg"

## Window sizes offered by the settings screen. 1600x900 is project.godot's
## default and stays first so "the size it shipped at" is always reachable.
const RESOLUTIONS: Array = [
	Vector2i(1600, 900),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

static var master_volume: float = 0.85
static var effects_volume: float = 1.0
static var resolution_index: int = 0
## action name -> keycode, for anything the player has moved off its default.
static var bindings: Dictionary = {}

static var _loaded: bool = false


## Reads the config if there is one, then installs the InputMap either way.
## Idempotent; the first caller wins and the rest are free.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		master_volume = clampf(float(config.get_value("audio", "master", master_volume)), 0.0, 1.0)
		effects_volume = clampf(float(config.get_value("audio", "effects", effects_volume)), 0.0, 1.0)
		resolution_index = clampi(int(config.get_value("video", "resolution", resolution_index)),
			0, RESOLUTIONS.size() - 1)
		for action in config.get_section_keys("input") if config.has_section("input") else []:
			bindings[str(action)] = int(config.get_value("input", str(action)))

	InputActions.ensure_installed(bindings)
	apply_audio()


static func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "effects", effects_volume)
	config.set_value("video", "resolution", resolution_index)
	for action in bindings:
		config.set_value("input", str(action), int(bindings[action]))
	var error: int = config.save(PATH)
	if error != OK:
		push_warning("AppSettings: could not write %s (error %d)" % [PATH, error])


## Volume lives on the audio bus rather than on the AudioDirector, so it applies
## whether or not a match is running - the menu's own sounds included.
static func apply_audio() -> void:
	var master: int = AudioServer.get_bus_index("Master")
	if master < 0:
		return
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(master, master_volume <= 0.001)


## No-op when there is no window to resize, which is every headless run.
static func apply_resolution() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var size: Vector2i = RESOLUTIONS[clampi(resolution_index, 0, RESOLUTIONS.size() - 1)]
	DisplayServer.window_set_size(size)


static func rebind(action: String, keycode: int) -> void:
	if keycode == InputActions.default_keycode(action):
		bindings.erase(action)
	else:
		bindings[action] = keycode
	InputActions.ensure_installed(bindings, true)


static func reset_bindings() -> void:
	bindings.clear()
	InputActions.ensure_installed(bindings, true)
