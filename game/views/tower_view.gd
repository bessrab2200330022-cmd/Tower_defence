extends Node3D
## Visual body for one tower.
##
## Two paths, same public surface:
##   * TowerDef.mesh_path set    -> load the .glb built by art/towers/<id>.py
##   * TowerDef.mesh_path empty  -> generate primitives from the def's numbers
##
## The fallback is not dead code. It is what every unmodelled tower uses, so a
## new tower is playable the moment its .tres exists and stays playable if a
## model fails to import. `tests/run_autoplay.gd` exercises whichever path the
## shipped content selects.
##
## Either way three nodes must exist, because the animation below drives them
## by name:
##   Base    - static
##   Turret  - rotated on Y to face the target
##   Barrel  - child of Turret, slid on local +Z for recoil
##
## Colour always comes from the TowerDef, never from the model. The .glb carries
## geometry only, so data/towers/*.tres stays the single source of truth for
## palette and an artist can't silently override balance-relevant readability.

## How fast the barrel returns to rest, as a fraction of full recoil per second.
## Was a per-CALL decay of 0.12, which meant the recovery took 8 rendered frames
## regardless of how long a frame lasted - so recoil recovered twice as fast on a
## 120 Hz display as on a 60 Hz one. 7.2/s is the old constant at 60 fps, so the
## feel at the reference frame rate is unchanged.
const RECOIL_RECOVERY: float = 7.2
const RECOIL_TRAVEL: float = 0.35

## How fast the turret traverses onto a new bearing, per second.
##
## `tower.facing` only moves on the tick a shot is fired, so it arrives as a
## step function. Interpolating across one tick would resolve it in 16 ms, which
## is still a snap; easing over roughly a tenth of a second reads as machinery
## swinging round. Purely cosmetic - the shot itself has already been resolved
## in the sim by the time this runs.
const TRAVERSE_SMOOTHING: float = 16.0

## Mesh names tinted with body_color. Everything unlisted keeps its exported
## material, which is how the dark structural parts stay dark.
const BODY_PARTS: Array = ["Base", "Plinth", "TurretHead"]
## Mesh names tinted with accent_color - the bright details that catch the eye.
const ACCENT_PARTS: Array = ["AmmoDrum", "Sight", "Muzzle"]

var base: Node3D
var turret: Node3D
var barrel: Node3D

var using_mesh: bool = false

var _recoil: float = 0.0
var _barrel_rest: float = 0.0

var _yaw: float = 0.0
var _has_yaw: bool = false


func setup(def) -> void:
	if def.mesh_path != "" and _setup_from_mesh(def):
		using_mesh = true
		return
	_setup_from_primitives(def)


# ---------------------------------------------------------------------------
# Built asset
# ---------------------------------------------------------------------------

## Returns false if anything is missing, so setup() can fall back rather than
## leaving a half-built tower that renders but never rotates.
func _setup_from_mesh(def) -> bool:
	if not ResourceLoader.exists(def.mesh_path):
		push_warning("TowerView: '%s' missing, falling back to primitives" % def.mesh_path)
		return false

	var packed: PackedScene = load(def.mesh_path)
	if packed == null:
		push_warning("TowerView: '%s' failed to load" % def.mesh_path)
		return false

	var model: Node3D = packed.instantiate()
	add_child(model)
	if not is_equal_approx(def.mesh_scale, 1.0):
		model.scale = Vector3.ONE * def.mesh_scale

	turret = model.find_child("Turret", true, false)
	barrel = model.find_child("Barrel", true, false)
	base = model.find_child("Base", true, false)

	if turret == null or barrel == null:
		push_warning("TowerView: '%s' has no Turret/Barrel node" % def.mesh_path)
		model.queue_free()
		return false

	_barrel_rest = barrel.position.z
	_tint(model, BODY_PARTS, def.body_color, 0.0)
	_tint(model, ACCENT_PARTS, def.accent_color, 0.35)
	return true


func _tint(root: Node, names: Array, color: Color, emission: float) -> void:
	for part_name in names:
		var node = root.find_child(str(part_name), true, false)
		if node is MeshInstance3D:
			node.material_override = _material(color, emission)


# ---------------------------------------------------------------------------
# Primitive fallback
# ---------------------------------------------------------------------------

func _setup_from_primitives(def) -> void:
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.62
	base_mesh.bottom_radius = 0.78
	base_mesh.height = def.body_height
	base_mesh.radial_segments = 12

	var base_instance := MeshInstance3D.new()
	base_instance.name = "Base"
	base_instance.mesh = base_mesh
	base_instance.position = Vector3(0.0, def.body_height * 0.5, 0.0)
	base_instance.material_override = _material(def.body_color, 0.0)
	add_child(base_instance)
	base = base_instance

	turret = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, def.body_height + 0.18, 0.0)
	add_child(turret)

	var head := MeshInstance3D.new()
	head.name = "TurretHead"
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.7, 0.42, 0.7)
	head.mesh = head_mesh
	head.material_override = _material(def.accent_color, 0.35)
	turret.add_child(head)

	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.22, 0.22, def.barrel_length)
	var barrel_instance := MeshInstance3D.new()
	barrel_instance.name = "Barrel"
	barrel_instance.mesh = barrel_mesh
	_barrel_rest = def.barrel_length * 0.5 + 0.2
	barrel_instance.position = Vector3(0.0, 0.05, _barrel_rest)
	barrel_instance.material_override = _material(def.accent_color, 0.5)
	turret.add_child(barrel_instance)
	barrel = barrel_instance


static func _material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	material.metallic = 0.25
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material


# ---------------------------------------------------------------------------
# Animation - identical for both paths
# ---------------------------------------------------------------------------

func on_fired() -> void:
	_recoil = 1.0


func update_from(tower, delta: float = 0.0) -> void:
	var step: float = maxf(delta, 0.0)

	if not _has_yaw:
		# First frame: adopt the bearing rather than swinging to it, or every
		# tower built during a wave slews from due north on placement.
		_yaw = tower.facing
		_has_yaw = true
	else:
		# exp() so the traverse rate does not scale with frame rate.
		_yaw = lerp_angle(_yaw, tower.facing, 1.0 - exp(-TRAVERSE_SMOOTHING * step))
	turret.rotation.y = _yaw

	if _recoil > 0.0:
		_recoil = maxf(_recoil - RECOIL_RECOVERY * step, 0.0)
	barrel.position.z = _barrel_rest - _recoil * RECOIL_TRAVEL
