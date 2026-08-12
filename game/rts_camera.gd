extends Camera3D
## Orbiting RTS camera. Purely presentational - it never touches the simulation.
##
## Controls:
##   Pan / orbit / tilt / reset all come from the InputMap - the defaults are
##   WASD and arrows, Q/E, R/F and Home, and every one of them is rebindable.
##   See game/input_actions.gd for the table.
##
##   Right-drag      orbit: horizontal yaw, vertical pitch
##   Middle-drag     pan
##   Wheel           zoom
##
## Every input writes to a *target* value and the camera eases toward it. That
## smoothing is most of what separates a camera that feels like a camera from
## one that feels like a variable being assigned - and it costs four lerps.

const MIN_DISTANCE: float = 10.0
const MAX_DISTANCE: float = 80.0

const PAN_SPEED: float = 24.0
const ZOOM_STEP: float = 3.5
const KEY_ORBIT_SPEED: float = 1.7
const KEY_PITCH_SPEED: float = 1.0

const MOUSE_ORBIT_SENSITIVITY: float = 0.006
const MOUSE_PITCH_SENSITIVITY: float = 0.005

## Pitch limits. Never straight down - the towers lose their silhouettes and the
## game reads as a spreadsheet.
const PITCH_MIN: float = -80.0
## Shallower than a grounded map would allow. The board is a floating island,
## and its underside and cloud deck are worth being able to look at - but the
## limit still stops short of horizontal, because at a grazing angle the board
## collapses to a sliver and the enemy path stops being readable, which is the
## one thing the camera must never break.
const PITCH_MAX: float = -12.0

## How fast the camera converges on its target, per second. Higher is snappier.
const SMOOTHING: float = 12.0

var focus: Vector3 = Vector3.ZERO
var distance: float = 34.0
var yaw: float = deg_to_rad(-40.0)
var pitch: float = deg_to_rad(-52.0)

var _target_focus: Vector3 = Vector3.ZERO
var _target_distance: float = 34.0
var _target_yaw: float = deg_to_rad(-40.0)
var _target_pitch: float = deg_to_rad(-52.0)

var _home_focus: Vector3 = Vector3.ZERO
var _home_distance: float = 34.0

var _bounds_radius: float = 40.0
var _panning: bool = false
var _orbiting: bool = false


func setup(centre: Vector3, board_span: float) -> void:
	_bounds_radius = maxf(board_span, 10.0)
	_home_focus = centre
	_home_distance = clampf(board_span * 0.95, MIN_DISTANCE, MAX_DISTANCE)

	focus = centre
	_target_focus = centre
	distance = _home_distance
	_target_distance = _home_distance
	_apply()


func reset_view() -> void:
	_target_focus = _home_focus
	_target_distance = _home_distance
	_target_yaw = deg_to_rad(-40.0)
	_target_pitch = deg_to_rad(-52.0)


# ---------------------------------------------------------------------------
# Per-frame
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_read_keyboard(delta)

	# exp() rather than a raw lerp factor, so the easing is frame-rate
	# independent. A plain `lerp(a, b, 0.2)` moves twice as fast at 120fps.
	var weight: float = 1.0 - exp(-SMOOTHING * delta)
	focus = focus.lerp(_target_focus, weight)
	distance = lerpf(distance, _target_distance, weight)
	yaw = lerp_angle(yaw, _target_yaw, weight)
	pitch = lerpf(pitch, _target_pitch, weight)

	_apply()


## Reads actions, not keycodes. `get_axis` returns the two-key difference in one
## call, so a player who rebinds pan-left keeps a working pair rather than half
## of one.
func _read_keyboard(delta: float) -> void:
	var move := Vector2(
		Input.get_axis("bl_pan_left", "bl_pan_right"),
		Input.get_axis("bl_pan_forward", "bl_pan_back"))

	if move != Vector2.ZERO:
		# Normalised, or holding two keys pans diagonally 41% faster.
		move = move.normalized()
		# Pan speed scales with zoom: at max zoom-out the same key press should
		# cover more ground, or crossing the map becomes a chore.
		var speed: float = PAN_SPEED * delta * (distance / 30.0)
		_target_focus += _pan_vector(move.x, move.y) * speed
		_clamp_focus()

	_target_yaw += Input.get_axis("bl_orbit_left", "bl_orbit_right") * KEY_ORBIT_SPEED * delta
	_set_pitch(_target_pitch
		+ Input.get_axis("bl_tilt_down", "bl_tilt_up") * KEY_PITCH_SPEED * delta)


# ---------------------------------------------------------------------------
# Mouse
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_button(event)
	elif event is InputEventMouseMotion:
		_handle_motion(event)
	elif event.is_action_pressed("bl_camera_reset"):
		reset_view()


func _handle_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_target_distance = clampf(_target_distance - ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_target_distance = clampf(_target_distance + ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
		MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		MOUSE_BUTTON_RIGHT:
			# Right-drag orbits. Left is taken by building, middle by panning,
			# and orbit-on-right is what every RTS trains players to expect.
			_orbiting = event.pressed


func _handle_motion(event: InputEventMouseMotion) -> void:
	if _orbiting:
		_target_yaw += event.relative.x * MOUSE_ORBIT_SENSITIVITY
		# Inverted on purpose: dragging down tips the camera down toward the
		# board, which is the direction the hand is moving the horizon.
		_set_pitch(_target_pitch - event.relative.y * MOUSE_PITCH_SENSITIVITY)
	elif _panning:
		var scale: float = distance * 0.0016
		_target_focus -= _pan_vector(event.relative.x, event.relative.y) * scale
		_clamp_focus()


# ---------------------------------------------------------------------------
# Maths
# ---------------------------------------------------------------------------

## Screen-relative pan, converted into world XZ using the current yaw, so "up"
## always means "away from the camera" no matter how the view is rotated.
## Magnitude is preserved - callers scale it, because the keyboard wants a unit
## direction and the mouse wants raw pixel deltas.
func _pan_vector(x: float, y: float) -> Vector3:
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	return right * x + forward * y


func _set_pitch(value: float) -> void:
	_target_pitch = clampf(value, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))


func _clamp_focus() -> void:
	_target_focus.x = clampf(_target_focus.x, -_bounds_radius, _bounds_radius * 2.0)
	_target_focus.z = clampf(_target_focus.z, -_bounds_radius, _bounds_radius * 2.0)
	_target_focus.y = 0.0


func _apply() -> void:
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		-sin(pitch),
		cos(yaw) * cos(pitch)
	) * distance
	position = focus + offset
	# Basis.looking_at rather than look_at(): look_at() asserts the node is
	# already inside the SceneTree and logs an error when it is not, and setup()
	# legitimately runs during scene construction. Every ancestor of the camera
	# is an untransformed Node3D, so a local basis and a global one agree here -
	# which is the same assumption the `position` line above already makes.
	basis = Basis.looking_at(focus - position, Vector3.UP)
