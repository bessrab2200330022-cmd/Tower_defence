extends Node3D
## Visual body for one enemy.
##
## Same two-path shape as tower_view.gd: load the .glb built by
## art/enemies/<id>.py if EnemyDef.mesh_path is set, otherwise generate a sphere
## from the def's radius and height. The fallback keeps an unmodelled enemy
## playable rather than invisible.
##
## The health bar is always procedural. It is UI that happens to live in 3D, its
## width derives from the def, and baking it into a model would mean rebuilding
## the mesh to change a bar colour.

## How far a chilled enemy squashes. Read off enemy.slow_ticks_left, which is
## the only status the sim currently exposes.
const CHILL_SQUASH: Vector3 = Vector3(1.06, 0.84, 1.06)

## How fast a hit flash fades, in alpha per second. Fast enough that rapid fire
## reads as a stutter of flashes rather than a permanently white enemy.
const FLASH_DECAY: float = 5.5
const FLASH_PEAK: float = 0.7

## Below this squared movement per tick a heading is noise, so the last good one
## is kept rather than letting the model spin on the spot at a waypoint.
const MIN_HEADING_DISTANCE: float = 0.0004
## How fast the body swings onto a new heading, per second. Enemies turn corners
## instantly in the sim - the path is a sequence of axis-aligned waypoints - and
## a body that snaps 90 degrees in one frame reads as a glitch rather than as a
## turn.
const TURN_SMOOTHING: float = 13.0

var body: Node3D
var health_bar: MeshInstance3D
var health_material: StandardMaterial3D

var using_mesh: bool = false

## Height of the surface the enemy walks on. The simulation works on a flat
## plane at y = 0 and has no idea the path is recessed below the grass - that
## is a purely visual choice made in game/board.gd. Rather than teach the sim
## about terrain height, the view drops the model onto the surface.
var ground_offset: float = 0.0

## Height a flier cruises at, above the ground plane the simulation works on.
##
## Read from the enemy's def by NAME, because `EnemyDef` has no altitude field
## yet - the simulation agent is choosing the value in a parallel session and
## putting it on the def. Zero means "walks", which is every enemy today, so this
## is inert until that field exists.
##
## When it is non-zero it REPLACES ground_offset rather than adding to it: a
## Skiff does not care that the path is recessed 0.22 below the grass, because it
## is not standing on the path.
var cruise_altitude: float = 0.0

## Field names tried on the def, in order. More than one because the exact name
## is the sim agent's to pick and this costs nothing to be tolerant about.
const ALTITUDE_FIELDS: Array = ["cruise_altitude", "altitude", "fly_height"]

var _bar_width: float = 1.0
var _base_scale: Vector3 = Vector3.ONE
var _flash_material: StandardMaterial3D
var _flash: float = 0.0

## Where this enemy stood at the start of the tick currently being rendered.
## Lives here rather than in sim/, which has no concept of a rendered frame and
## must not grow one. Written only by capture_previous().
var _previous_position: Vector3 = Vector3.ZERO
var _has_previous: bool = false

var _yaw: float = 0.0
var _has_yaw: bool = false


func setup(def) -> void:
	cruise_altitude = _altitude_of(def)
	if def.mesh_path != "" and _setup_from_mesh(def):
		using_mesh = true
	else:
		_setup_from_primitive(def)

	_base_scale = body.scale
	_build_health_bar(def)
	_build_flash_overlay()


static func _altitude_of(def) -> float:
	for field in ALTITUDE_FIELDS:
		if field in def:
			var value: float = float(def.get(field))
			if value > 0.0:
				return value
	return 0.0


## Where this enemy's body sits above the simulation's flat plane. A flier gets
## its cruise altitude; a walker gets the drop onto the recessed path.
func vertical_offset() -> float:
	return cruise_altitude if cruise_altitude > 0.0 else ground_offset


func is_flying() -> bool:
	return cruise_altitude > 0.0


## A white additive layer applied as material_overlay on every mesh in the body.
## Overlay rather than material_override, so the enemy's own materials survive
## untouched - swapping them out and back would fight the shield transparency
## and lose the .glb's emissive details.
func _build_flash_overlay() -> void:
	_flash_material = StandardMaterial3D.new()
	_flash_material.albedo_color = Color(1.0, 0.95, 0.85, 0.0)
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_material.emission_enabled = true
	_flash_material.emission = Color(1.0, 0.95, 0.85)
	_flash_material.emission_energy_multiplier = 2.2

	if body is MeshInstance3D:
		body.material_overlay = _flash_material
	for mesh_instance in body.find_children("*", "MeshInstance3D", true, false):
		mesh_instance.material_overlay = _flash_material


## Called from level.gd on ENEMY_DAMAGED. This is the single clearest signal
## that a tower is actually hurting something - without it, damage is only
## visible as a health bar shrinking, which the eye does not track during a wave.
func flash() -> void:
	_flash = FLASH_PEAK


func _setup_from_mesh(def) -> bool:
	if not ResourceLoader.exists(def.mesh_path):
		push_warning("EnemyView: '%s' missing, falling back to a sphere" % def.mesh_path)
		return false

	var packed: PackedScene = load(def.mesh_path)
	if packed == null:
		push_warning("EnemyView: '%s' failed to load" % def.mesh_path)
		return false

	var model: Node3D = packed.instantiate()
	add_child(model)
	if not is_equal_approx(def.mesh_scale, 1.0):
		model.scale = Vector3.ONE * def.mesh_scale
	body = model

	if def.shell_node != "":
		_make_translucent(model, def.shell_node)
	return true


## Turns a named node into a see-through shell. The Shielded Scout's bubble has
## to be transparent to read as a field rather than a hull, but transparency is
## a render-time decision, so the model ships opaque and this applies it.
func _make_translucent(root: Node, node_name: String) -> void:
	var node = root.find_child(node_name, true, false)
	if not (node is MeshInstance3D):
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.85, 1.0, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.45, 0.85, 1.0)
	material.emission_energy_multiplier = 1.1
	node.material_override = material


func _setup_from_primitive(def) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = def.radius
	mesh.height = def.height
	mesh.radial_segments = 12
	mesh.rings = 6

	var instance := MeshInstance3D.new()
	instance.name = "Body"
	instance.mesh = mesh
	instance.position = Vector3(0.0, def.height * 0.5, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = def.body_color
	material.roughness = 0.6
	material.emission_enabled = true
	material.emission = def.body_color
	material.emission_energy_multiplier = 0.25
	instance.material_override = material
	add_child(instance)
	body = instance


func _build_health_bar(def) -> void:
	_bar_width = maxf(def.radius * 2.2, 0.6)
	var bar_mesh := QuadMesh.new()
	bar_mesh.size = Vector2(_bar_width, 0.12)

	health_bar = MeshInstance3D.new()
	health_bar.name = "HealthBar"
	health_bar.mesh = bar_mesh
	health_bar.position = Vector3(0.0, def.height + 0.45, 0.0)
	health_material = StandardMaterial3D.new()
	health_material.albedo_color = Color(0.35, 0.9, 0.4)
	health_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	health_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Billboarding rebuilds the model-view matrix from the camera, and discards
	# the node's scale on the way through unless this is set. Without it the
	# bar below never actually shrinks - it just turns red.
	health_material.billboard_keep_scale = true
	health_material.no_depth_test = true
	health_bar.material_override = health_material
	add_child(health_bar)


## Records where the enemy stands at the start of a tick. game/level.gd calls
## this from capture_tick_start(), immediately before Simulation.step().
func capture_previous(sim_position: Vector3) -> void:
	_previous_position = sim_position
	_has_previous = true


## `alpha` is the fraction of the current tick already elapsed. At 1.0 the view
## lands exactly on the simulated position, which is both the default and what
## the headless autoplay gate sees.
func update_from(enemy, delta: float = 0.0, alpha: float = 1.0) -> void:
	var target: Vector3 = enemy.position
	var shown: Vector3 = target
	if _has_previous and alpha < 1.0:
		shown = _previous_position.lerp(target, alpha)
	position = shown + Vector3(0.0, vertical_offset(), 0.0)

	if _has_previous:
		_face_travel(target - _previous_position, delta)
	if alpha >= 1.0:
		# Nobody is capturing tick boundaries this frame, so this frame IS the
		# boundary. Without this the heading source would freeze at wherever the
		# enemy spawned.
		_previous_position = target
		_has_previous = true

	if _flash > 0.0 and _flash_material != null:
		_flash = maxf(_flash - FLASH_DECAY * maxf(delta, 0.0), 0.0)
		_flash_material.albedo_color.a = _flash

	var fraction: float = clampf(enemy.health_fraction(), 0.0, 1.0)
	health_bar.scale = Vector3(maxf(fraction, 0.001), 1.0, 1.0)
	health_bar.position.x = -_bar_width * (1.0 - fraction) * 0.5
	health_bar.visible = fraction < 0.999
	health_material.albedo_color = Color(0.9, 0.35, 0.3).lerp(Color(0.35, 0.9, 0.4), fraction)

	# Chilled enemies squash, so the player can see the Frost Mortar working
	# without reading a number. Deliberately a shape change rather than a colour
	# change - the palette is already carrying armour type.
	if enemy.slow_ticks_left > 0:
		body.scale = _base_scale * CHILL_SQUASH
	else:
		body.scale = _base_scale


## Turns the body to face the direction it is walking.
##
## The simulation tracks a position and a waypoint index and has no notion of
## orientation, so without this every enemy crabs sideways down the serpentine
## leg of the map - which is what it did until now. Models are built nose along
## +Z (art/README.md: Blender -Y maps to Godot +Z), matching the atan2(x, z)
## convention `sim/simulation.gd` already uses for tower facing.
func _face_travel(travel: Vector3, delta: float) -> void:
	if travel.length_squared() <= MIN_HEADING_DISTANCE:
		return
	var wanted: float = atan2(travel.x, travel.z)
	if not _has_yaw:
		_yaw = wanted
		_has_yaw = true
	else:
		# exp() rather than a fixed lerp weight, or the turn rate doubles when
		# the frame rate does.
		_yaw = lerp_angle(_yaw, wanted, 1.0 - exp(-TURN_SMOOTHING * maxf(delta, 0.0)))
	# The body, not this node. The health bar hangs off the root and is a piece
	# of UI that happens to be in 3D - it should not swing around with the thing
	# it is measuring.
	body.rotation.y = _yaw
