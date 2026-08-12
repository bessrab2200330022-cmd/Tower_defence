extends Node3D
## Short-lived visual flourishes: beams, muzzle flashes, impact bursts, splash
## rings and death debris.
##
## Everything here is pooled into one array and hand-ticked from `step()`.
## Deliberately not Tween or Timer: those run on the SceneTree clock, so at 4x
## speed or while paused they desynchronise from the simulation the effects are
## describing, and a paused game slowly accumulates orphaned nodes.
##
## Nothing in this file may read or write simulation state. Effects are told
## what happened; they never decide anything.

const BEAM_LIFETIME: float = 0.11
const FLASH_LIFETIME: float = 0.09
const BURST_LIFETIME: float = 0.3
const RING_LIFETIME: float = 0.34
const DEBRIS_LIFETIME: float = 0.5
const SMOKE_LIFETIME: float = 1.1

## Anything above this many live effects starts recycling the oldest. A player
## fast-forwarding a big wave can otherwise spawn thousands in a second.
## One explosion is ~18 nodes, so this is roughly sixteen simultaneous blasts
## before the pool starts eating its own tail.
const MAX_LIVE: int = 300

var _live: Array = []


# ---------------------------------------------------------------------------
# Spawners
# ---------------------------------------------------------------------------

## Hitscan beam. Drawn as two concentric cylinders: a hot white-ish core inside
## a wider coloured sheath. One cylinder alone reads as a plastic stick; the
## pair is what makes it look like light.
func spawn_beam(from: Vector3, to: Vector3, color: Color, width: float = 1.0) -> void:
	var length: float = from.distance_to(to)
	if length <= 0.01:
		return

	var sheath := _beam_segment(from, to, length, 0.075 * width, color, 1.6)
	_track(sheath, BEAM_LIFETIME, {"fade": true, "shrink_xz": true})

	var core_color: Color = color.lerp(Color(1.0, 1.0, 1.0), 0.65)
	var core := _beam_segment(from, to, length, 0.028 * width, core_color, 3.0)
	_track(core, BEAM_LIFETIME * 0.8, {"fade": true})


## Bright flare at the barrel tip. Fires on every shot regardless of fire mode,
## because a tower that visibly kicks but emits nothing reads as jammed.
func spawn_muzzle_flash(at: Vector3, color: Color, size: float = 1.0) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.22 * size
	mesh.height = 0.44 * size
	mesh.radial_segments = 8
	mesh.rings = 4

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _glow(color.lerp(Color.WHITE, 0.45), 3.2)
	add_child(instance)
	instance.position = at
	instance.scale = Vector3(1.0, 0.8, 1.6)
	_track(instance, FLASH_LIFETIME, {"fade": true, "grow": 1.4})


## Impact flare. `radius` scales it, so a mortar shell landing looks bigger than
## a rifle round hitting.
func spawn_burst(at: Vector3, color: Color, radius: float = 1.0) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.3 * radius
	mesh.height = 0.6 * radius
	mesh.radial_segments = 8
	mesh.rings = 4

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _glow(color, 2.0)
	add_child(instance)
	instance.position = at + Vector3(0.0, 0.35, 0.0)
	_track(instance, BURST_LIFETIME, {"fade": true, "grow": 1.8})


## Flat expanding ring on the ground. This is the honest one: it is drawn at the
## real splash radius, so a player can learn the mortar's area of effect by
## watching it rather than by reading the .tres.
func spawn_ring(at: Vector3, color: Color, radius: float) -> void:
	if radius <= 0.05:
		return
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.86
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 6

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _glow(color, 1.6)
	add_child(instance)
	instance.position = Vector3(at.x, 0.08, at.z)
	instance.scale = Vector3(radius * 0.3, 1.0, radius * 0.3)
	_track(instance, RING_LIFETIME, {
		"fade": true,
		"scale_to": Vector3(radius, 1.0, radius),
		"scale_from": instance.scale,
	})


## Death effect: a flare plus a few chunks thrown outward. Directions come from
## a fixed table rather than randf() - not for determinism (this is the view
## layer, it cannot affect the sim) but because reproducible visuals make
## screenshot comparisons meaningful.
const DEBRIS_DIRECTIONS: Array = [
	Vector3(1.0, 1.4, 0.2), Vector3(-0.9, 1.2, 0.6), Vector3(0.3, 1.5, -1.0),
	Vector3(-0.5, 1.1, -0.9), Vector3(1.1, 0.9, -0.4),
	Vector3(-1.2, 1.0, 0.3), Vector3(0.7, 1.6, 0.8), Vector3(-0.2, 1.3, 1.1),
]

## Smoke drifts up and out from these, slower and darker than the debris.
const SMOKE_OFFSETS: Array = [
	Vector3(0.0, 0.0, 0.0), Vector3(0.45, 0.1, -0.3), Vector3(-0.4, 0.15, 0.35),
	Vector3(0.25, 0.3, 0.45), Vector3(-0.3, 0.25, -0.4),
]


func spawn_death(at: Vector3, color: Color, scale: float = 1.0) -> void:
	spawn_burst(at, color, scale)
	spawn_ring(at, color, 1.1 * scale)
	_spawn_debris(at, color, scale, 5)


## The full explosion: fireball, shockwave, smoke, debris and a light flash.
##
## The light is the piece that sells it. A glowing mesh only brightens its own
## pixels; a real OmniLight3D throws colour onto the terrain slabs and the
## towers around the blast for a few frames, and with bloom on, that spill is
## what the eye reads as an explosion rather than as a decal.
func spawn_explosion(at: Vector3, color: Color, radius: float = 1.0,
		smoke_color: Color = Color(0.25, 0.24, 0.26)) -> void:
	var centre: Vector3 = at + Vector3(0.0, 0.35 * radius, 0.0)

	# Core fireball: bright, fast, gone before you can focus on it.
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.34 * radius
	core_mesh.height = 0.68 * radius
	core_mesh.radial_segments = 10
	core_mesh.rings = 6

	var core := MeshInstance3D.new()
	core.mesh = core_mesh
	core.material_override = _glow(color.lerp(Color.WHITE, 0.5), 3.4)
	add_child(core)
	core.position = centre
	_track(core, 0.16, {"fade": true, "grow": 2.6})

	# Outer bloom, slower and more saturated, so the blast has a soft edge.
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.5 * radius
	shell_mesh.height = 1.0 * radius
	shell_mesh.radial_segments = 10
	shell_mesh.rings = 6

	var shell := MeshInstance3D.new()
	shell.mesh = shell_mesh
	shell.material_override = _glow(color, 2.0)
	add_child(shell)
	shell.position = centre
	_track(shell, 0.34, {"fade": true, "grow": 1.9})

	spawn_ring(at, color, 1.5 * radius)
	_spawn_light(centre, color, 7.0 * radius, 0.22)
	_spawn_smoke(at, smoke_color, radius)
	_spawn_debris(at, color, radius, DEBRIS_DIRECTIONS.size())


func _spawn_debris(at: Vector3, color: Color, scale: float, count: int) -> void:
	for index in mini(count, DEBRIS_DIRECTIONS.size()):
		var direction: Vector3 = DEBRIS_DIRECTIONS[index]
		var mesh := BoxMesh.new()
		var chunk_size: float = 0.1 * scale
		mesh.size = Vector3(chunk_size, chunk_size, chunk_size * 1.6)

		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = _glow(color, 1.2)
		add_child(instance)
		instance.position = at + Vector3(0.0, 0.4 * scale, 0.0)
		_track(instance, DEBRIS_LIFETIME, {
			"fade": true,
			"velocity": direction * 2.2 * scale,
			"gravity": 9.0,
		})


## Dark, slow, rising. Deliberately NOT additive - smoke that adds light is the
## classic mistake that turns a explosion into a glowing cloud.
func _spawn_smoke(at: Vector3, color: Color, scale: float) -> void:
	for index in SMOKE_OFFSETS.size():
		var offset: Vector3 = SMOKE_OFFSETS[index]
		var mesh := SphereMesh.new()
		mesh.radius = 0.3 * scale
		mesh.height = 0.6 * scale
		mesh.radial_segments = 7
		mesh.rings = 4

		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = _smoke_material(color)
		add_child(instance)
		instance.position = at + offset * scale + Vector3(0.0, 0.3 * scale, 0.0)
		_track(instance, SMOKE_LIFETIME, {
			"fade": true,
			"alpha": 0.5,   # smoke starts translucent and fades from there
			"grow": 1.6,
			"velocity": Vector3(offset.x * 0.6, 0.9, offset.z * 0.6) * scale,
			"gravity": -0.4,   # negative: smoke rises and keeps rising
		})


func _spawn_light(at: Vector3, color: Color, energy: float, lifetime: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 9.0
	light.shadow_enabled = false   # a shadow-casting flash costs far more than it shows
	add_child(light)
	light.position = at
	_track(light, lifetime, {"light_energy": energy})


# ---------------------------------------------------------------------------
# Tick
# ---------------------------------------------------------------------------

func step(delta: float) -> void:
	var survivors: Array = []
	for entry in _live:
		entry["life"] -= delta
		var node: Node3D = entry["node"]
		if entry["life"] <= 0.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			continue

		# t goes 1 -> 0 over the effect's life.
		var t: float = entry["life"] / entry["max_life"]
		var age: float = 1.0 - t

		# Lights fade on energy, everything else on alpha. Squaring the falloff
		# makes a flash punch and vanish rather than dimming linearly, which
		# reads as a light being switched off.
		if entry.has("light_energy") and node is OmniLight3D:
			(node as OmniLight3D).light_energy = float(entry["light_energy"]) * t * t
			survivors.append(entry)
			continue

		if entry.get("fade", false) and node is MeshInstance3D:
			var material: StandardMaterial3D = (node as MeshInstance3D).material_override
			if material != null:
				material.albedo_color.a = float(entry.get("alpha", 1.0)) * t

		if entry.has("grow"):
			node.scale = Vector3.ONE * (1.0 + age * float(entry["grow"]))

		if entry.has("scale_to"):
			node.scale = (entry["scale_from"] as Vector3).lerp(entry["scale_to"], age)

		if entry.get("shrink_xz", false):
			# The sheath narrows as it fades, so the beam looks like it is
			# collapsing into the core rather than simply dimming.
			node.scale = Vector3(t, 1.0, t)

		if entry.has("velocity"):
			var velocity: Vector3 = entry["velocity"]
			velocity.y -= float(entry.get("gravity", 0.0)) * delta
			entry["velocity"] = velocity
			node.position += velocity * delta

		survivors.append(entry)
	_live = survivors


func live_count() -> int:
	return _live.size()


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _beam_segment(from: Vector3, to: Vector3, length: float, radius: float,
		color: Color, energy: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 6

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _glow(color, energy)
	add_child(instance)
	instance.position = (from + to) * 0.5
	# CylinderMesh runs along +Y, so aim -Z at the target then tip it forward.
	var direction: Vector3 = (to - from).normalized()
	var up: Vector3 = Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	instance.look_at(to, up)
	instance.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	return instance


func _track(node: Node3D, lifetime: float, options: Dictionary) -> void:
	var entry: Dictionary = options.duplicate()
	entry["node"] = node
	entry["life"] = lifetime
	entry["max_life"] = lifetime
	_live.append(entry)

	# Recycle oldest-first rather than refusing to spawn, so a burst of activity
	# degrades gracefully instead of silently dropping the newest effects.
	while _live.size() > MAX_LIVE:
		var oldest: Dictionary = _live.pop_front()
		var old_node = oldest["node"]
		if is_instance_valid(old_node):
			old_node.queue_free()


## Alpha-blended and unlit rather than additive. Additive smoke gets brighter
## the thicker it is, which is the exact opposite of how smoke behaves and turns
## an explosion into a glowing cloud.
static func _smoke_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.5)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _glow(color: Color, energy: float = 1.4) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
