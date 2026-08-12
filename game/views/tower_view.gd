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

## Which meshes take `body_color` and which take `accent_color`, by node name
## prefix. Everything matching neither keeps its exported material, which is how
## the dark structural parts stay dark.
##
## Prefixes rather than a list of exact names. The list version reached exactly
## one tower of three: it never touched the Frost Mortar's `CoolantTank` or the
## Plasma Lance's `Capacitor`, `CapacitorRear` and `Fin`, so two thirds of the
## roster shipped with the accent colour in the .tres doing nothing. Extending
## the list would have fixed those three towers and left the next one to fail
## the same way in silence; a prefix cannot.
##
## The naming contract for art/ is therefore: **a mesh that should carry the
## tower's body colour is named `Body<Something>`, and one that should carry the
## accent colour is named `Accent<Something>`.** Names stay descriptive -
## `AccentCoolantTank` is still a coolant tank.
const BODY_PREFIX: String = "Body"
const ACCENT_PREFIX: String = "Accent"

## The names the shipped models use today, honoured so nothing goes grey between
## this landing and art/ adopting the prefixes. FROZEN - a new part gets a
## prefix, it does not get added here.
const LEGACY_BODY_PARTS: Array = ["Base", "Plinth", "TurretHead"]
const LEGACY_ACCENT_PARTS: Array = ["AmmoDrum", "Sight", "Muzzle"]

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


## Swaps this tower's body for a different tier's, in place.
##
## In place is the point. An upgrade creates no simulation entity and destroys
## none, so the node has to survive - freeing this view and building another
## would leave `Level`'s dictionary momentarily out of step with `sim.towers`,
## which is exactly the invariant `tests/run_autoplay.gd` asserts every frame.
##
## `setup()` already falls back to primitives when a tier's .glb is missing, so
## a tier whose model art/ has not finished yet stays playable. Nothing extra is
## needed here and nothing extra should be added.
func rebuild(def) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	base = null
	turret = null
	barrel = null
	using_mesh = false
	_recoil = 0.0
	_barrel_rest = 0.0

	setup(def)

	# Carry the bearing across. The sim's `facing` did not change, so a turret
	# that snapped back to due north on upgrade would be the view inventing a
	# movement that never happened.
	if _has_yaw and turret != null:
		turret.rotation.y = _yaw


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

	# `Turret` and `Barrel` are the animation contract and keep their exact
	# names - they are pivots, not painted surfaces, so the palette prefixes do
	# not apply to them. `Base` may legitimately become `BodyBase` once art/
	# adopts the convention, hence the second lookup.
	turret = model.find_child("Turret", true, false)
	barrel = model.find_child("Barrel", true, false)
	base = model.find_child("Base", true, false)
	if base == null:
		base = model.find_child("Body*", true, false)

	if turret == null or barrel == null:
		push_warning("TowerView: '%s' has no Turret/Barrel node" % def.mesh_path)
		model.queue_free()
		return false

	_barrel_rest = barrel.position.z
	_tint(model, def)
	return true


## Applies the def's palette to every mesh in the model whose name opts in.
##
## Walks all meshes rather than looking each name up. `find_child()` returns the
## FIRST match, so even a complete list of exact names would have tinted only one
## of the Plasma Lance's two capacitors - the second was never reachable.
##
## One material per colour, shared across the parts that use it, rather than one
## per part: a tower has a palette, not six independent surfaces.
func _tint(root: Node, def) -> void:
	var body_material: StandardMaterial3D = _material(def.body_color, 0.0)
	var accent_material: StandardMaterial3D = _material(def.accent_color, 0.35)

	for node in _meshes_in(root):
		var part_name: String = str(node.name)
		if part_name.begins_with(ACCENT_PREFIX) or LEGACY_ACCENT_PARTS.has(part_name):
			node.material_override = accent_material
		elif part_name.begins_with(BODY_PREFIX) or LEGACY_BODY_PARTS.has(part_name):
			node.material_override = body_material


static func _meshes_in(root: Node) -> Array:
	var out: Array = []
	if root is MeshInstance3D:
		out.append(root)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		out.append(node)
	return out


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
