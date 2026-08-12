extends Node3D
## A single in-flight shot.
##
## Position comes entirely from the simulation. The only thing this node decides
## for itself is which way the shell is pointing, derived from the movement
## between frames - the sim has no concept of projectile orientation and should
## not grow one just so a mesh looks right.

## Below this per-frame movement the direction is noise, so keep the last good
## heading rather than letting the model jitter as it converges on a target.
const MIN_TURN_DISTANCE: float = 0.0005

var model: Node3D
var using_mesh: bool = false

var _has_previous: bool = false
var _previous_position: Vector3 = Vector3.ZERO
var _spin: float = 0.0


func setup(def, color: Color) -> void:
	var mesh_path: String = "" if def == null else str(def.projectile_mesh_path)
	if mesh_path != "" and _setup_from_mesh(mesh_path):
		using_mesh = true
		return
	_setup_from_primitive(color)


func _setup_from_mesh(mesh_path: String) -> bool:
	if not ResourceLoader.exists(mesh_path):
		push_warning("ProjectileView: '%s' missing, falling back to a sphere" % mesh_path)
		return false
	var packed: PackedScene = load(mesh_path)
	if packed == null:
		return false
	model = packed.instantiate()
	add_child(model)
	return true


func _setup_from_primitive(color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mesh.radial_segments = 8
	mesh.rings = 4

	var instance := MeshInstance3D.new()
	instance.name = "Body"
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.5
	instance.material_override = material
	add_child(instance)
	model = instance


## Records where the shell was at the start of a tick. game/level.gd calls this
## from capture_tick_start(), immediately before Simulation.step().
func capture_previous(sim_position: Vector3) -> void:
	_previous_position = sim_position
	_has_previous = true


## Called every rendered frame with the simulation's authoritative position.
##
## `alpha` is the fraction of the current tick already elapsed; at 1.0 the shell
## sits exactly on the simulated position.
func update_to(new_position: Vector3, delta: float, alpha: float = 1.0) -> void:
	var offset: Vector3 = new_position - _previous_position

	if _has_previous and alpha < 1.0:
		position = _previous_position.lerp(new_position, alpha)
	else:
		position = new_position

	if _has_previous and offset.length_squared() > MIN_TURN_DISTANCE:
		var up: Vector3 = Vector3.UP
		if absf(offset.normalized().dot(Vector3.UP)) > 0.99:
			up = Vector3.RIGHT
		# The model is built nose-forward along +Z and a looking_at basis aims
		# -Z, so aim backwards along the travel and the nose ends up leading.
		#
		# Basis.looking_at rather than look_at(): look_at() reads the node's
		# CURRENT global origin, which at this point is still last frame's, so
		# aiming at the point we came from asked the engine to look at the place
		# it was already standing. That is a degenerate look_at and it logged an
		# error every frame of every shot - one of the three ERROR floods the
		# autoplay gate was quietly carrying.
		basis = Basis.looking_at(-offset, up)

	if alpha >= 1.0:
		# No tick boundary was captured this frame, so this frame is one. Keeps
		# the heading source fresh for callers that do not interpolate.
		_previous_position = new_position
		_has_previous = true

	# A slow roll. Costs nothing and stops the shell looking like a static
	# billboard while it crosses the board.
	if using_mesh and model != null:
		_spin += delta * 6.0
		model.rotation.z = _spin
