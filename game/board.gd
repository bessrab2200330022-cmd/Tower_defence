extends Node3D
## Builds the playable board as a chunky diorama from the simulation grid.
##
## WHY THIS IS IN GODOT AND NOT IN BLENDER
##
## `data/maps/*.layout.txt` is already the sim's source of truth: the pathfinder
## walks it, `MapDef.is_valid()` checks it, and the tests assert against it.
## A map hand-built in Blender would be a second source describing the same
## thing, and the two would drift the first time someone moved a corridor. You
## would get a board that looks one way and routes another - the worst class of
## bug, because it looks fine in a screenshot.
##
## So Blender builds the KIT (art/props/*.py -> data/models/terrain, /props) and
## this file ASSEMBLES it from the layout at load time. Authoring a new map stays
## one text file, and it gets dressed automatically.
##
## Nothing here reads or writes simulation state beyond the immutable grid.

const Types := preload("res://sim/sim_types.gd")
const RngScript := preload("res://sim/rng.gd")

const TERRAIN_DIR := "res://data/models/terrain"
const PROP_DIR := "res://data/models/props"

## How far the decorative landmass extends beyond the play area, in cells.
## Four is enough to fill an RTS camera's frame without doubling the tile count.
const BORDER_WIDTH: int = 4

## Vertical offsets. The path sitting below the grass is the single cue that
## makes a route readable from above - more than colour does.
const GROUND_TOP: float = 0.0
const PATH_TOP: float = -0.22
const BORDER_TOP: float = -0.1

## Props are scattered on the border ring only. A tree on a buildable cell is a
## lie: the player can build there and the art says otherwise.
const PROP_CHANCE_PERMILLE: int = 620

var grid
var map_def

var _ground_multi: MultiMeshInstance3D
var _path_multi: MultiMeshInstance3D
var _border_multi: MultiMeshInstance3D
var _props: Node3D


func build(sim_grid, map_resource) -> void:
	grid = sim_grid
	map_def = map_resource

	_props = Node3D.new()
	_props.name = "Props"
	add_child(_props)

	_build_ground()
	_build_border()
	_build_island()
	_scatter_props()
	_build_markers()


# ---------------------------------------------------------------------------
# Terrain
# ---------------------------------------------------------------------------

func _build_ground() -> void:
	var ground_cells: Array = []
	var path_cells: Array = []
	var blocked_cells: Array = []

	for y in grid.height:
		for x in grid.width:
			var cell := Vector2i(x, y)
			var world: Vector3 = grid.cell_to_world(cell)
			match grid.get_cell(cell):
				Types.Cell.PATH:
					path_cells.append(Vector3(world.x, PATH_TOP, world.z))
				Types.Cell.BLOCKED:
					blocked_cells.append(Vector3(world.x, GROUND_TOP + 0.5, world.z))
				_:
					ground_cells.append(Vector3(world.x, GROUND_TOP, world.z))

	_ground_multi = _add_layer("Ground", "%s/ground_block.glb" % TERRAIN_DIR,
		ground_cells, map_def.ground_color)
	_path_multi = _add_layer("Path", "%s/path_block.glb" % TERRAIN_DIR,
		path_cells, map_def.path_color)
	if not blocked_cells.is_empty():
		_add_layer("Blocked", "%s/border_block.glb" % TERRAIN_DIR,
			blocked_cells, map_def.blocked_color)


## The decorative landmass around the play area. Height varies so the outer edge
## reads as terrain falling away rather than as a tabletop with a hard border.
func _build_border() -> void:
	var rng = RngScript.new(_seed_from_map() ^ 0x5EED)
	var cells: Array = []

	for y in range(-BORDER_WIDTH, grid.height + BORDER_WIDTH):
		for x in range(-BORDER_WIDTH, grid.width + BORDER_WIDTH):
			var cell := Vector2i(x, y)
			if grid.in_bounds(cell):
				continue
			# Step down with distance from the play area, plus a little jitter,
			# so the silhouette is uneven the way a landscape is.
			var distance: int = maxi(
				maxi(-x, x - grid.width + 1),
				maxi(-y, y - grid.height + 1))
			var drop: float = float(distance) * 0.34 + float(rng.randi_range(0, 3)) * 0.11
			var world: Vector3 = grid.cell_to_world(cell)
			cells.append(Vector3(world.x, BORDER_TOP - drop, world.z))

	_border_multi = _add_layer("Border", "%s/border_block.glb" % TERRAIN_DIR,
		cells, map_def.ground_color.darkened(0.18))


## One MultiMesh per terrain kind. The whole board is three draw calls, which is
## why a 20x12 map plus a four-cell border ring costs nothing.
func _add_layer(layer_name: String, mesh_path: String, positions: Array,
		color: Color) -> MultiMeshInstance3D:
	if positions.is_empty():
		return null

	var loaded: Dictionary = _load_mesh(mesh_path)
	var mesh: Mesh = loaded.get("mesh", null)
	# The offset is load-bearing. Terrain blocks are modelled with the top face
	# at zero and the body hanging below, which puts that offset on the NODE
	# while the mesh data stays centred on its own origin. A MultiMesh takes
	# mesh data and ignores the node, so dropping the offset sank every tower
	# and enemy by half a block. Re-apply it here.
	var offset: Vector3 = loaded.get("offset", Vector3.ZERO)
	if mesh == null:
		mesh = _fallback_block()
		offset = Vector3(0.0, -0.55, 0.0)

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = positions.size()
	for i in positions.size():
		multi_mesh.set_instance_transform(i, Transform3D(Basis(), positions[i] + offset))

	var instance := MultiMeshInstance3D.new()
	instance.name = layer_name
	instance.multimesh = multi_mesh
	instance.material_override = _matte(color)
	add_child(instance)
	return instance


# ---------------------------------------------------------------------------
# The island
# ---------------------------------------------------------------------------

## The board is a floating island: a slab of rock hanging in open sky.
##
## This suits the shape the board already has. The playable area plus its border
## ring is a hard-edged rectangle sitting at a fixed height - which reads as an
## unfinished diorama if you put ground under it, and as a deliberate island if
## you do not. Cheaper than a horizon too: no distant scenery to draw, and the
## sky does the work of the background.
##
## Everything is procedural rather than a Blender asset, so a bigger map gets a
## proportionally bigger island for free.

## Stepped layers under the board. A smooth cone would fight the chunky slab
## language of the terrain; a ziggurat of shrinking boxes matches it.
const UNDERSIDE_LAYERS: int = 6
## Total drop of the stepped mass, as a fraction of the island's short side.
const UNDERSIDE_DEPTH_RATIO: float = 0.62
## Unused since the cloud deck moved to being placed relative to the island's
## lowest rock rather than to a fixed fraction of its width. Kept as the record
## of what the old fixed depth was, in case the new placement needs a floor.
const CLOUD_DEPTH_RATIO: float = 0.75
## Smaller islands orbiting the main one.
const SATELLITE_COUNT: int = 6
## Waterfalls pouring off the rim.
const WATERFALL_COUNT: int = 3
const CLOUD_COUNT: int = 52

var _floaters: Array = []
var _waterfall_drops: Array = []
var _clouds: Array = []
var _cloud_multi: MultiMeshInstance3D
var _cloud_centre: Vector3 = Vector3.ZERO
var _drift_time: float = 0.0


func _build_island() -> void:
	var extent: Vector3 = grid.world_extent()
	var centre := Vector3(extent.x * 0.5, 0.0, extent.z * 0.5)
	# The island footprint is the play area plus the decorative border ring.
	var border_span: float = float(BORDER_WIDTH) * 2.0 * grid.cell_size
	var island_x: float = extent.x + border_span
	var island_z: float = extent.z + border_span
	var span: float = maxf(island_x, island_z)

	# The border ring already steps down with distance; the underside starts
	# below its lowest point so the two read as one mass.
	var top: float = BORDER_TOP - float(BORDER_WIDTH) * 0.34 - 0.6

	var mass := Node3D.new()
	mass.name = "IslandUnderside"
	mass.position = Vector3(centre.x, top, centre.z)
	add_child(mass)
	_build_island_mass(mass, island_x, island_z,
		minf(island_x, island_z) * UNDERSIDE_DEPTH_RATIO,
		RngScript.new(_seed_from_map() ^ 0x1A5D))

	# Lowest rock on the main island: the stepped mass plus the roots hanging
	# off it. The cloud deck is placed relative to this so it can never be
	# level with anything solid.
	var mass_depth: float = minf(island_x, island_z) * UNDERSIDE_DEPTH_RATIO
	var island_bottom: float = top - mass_depth * 1.6

	_build_waterfalls(centre, island_x, island_z, top)
	_build_satellites(centre, span, top)
	_build_clouds(centre, span, island_bottom)


## Builds the rock hanging below an island, main or satellite, into `parent`
## whose origin is the top of the mass.
##
## The first version was clean shrinking boxes with thin cones hanging off the
## bottom. It read badly: the boxes looked like a stack of trays and the cones
## looked like separate blades floating under it. Two changes fix that, and both
## are about breaking regularity rather than adding detail.
##
##   * Each layer is two or three overlapping boxes at different offsets and
##     rotations rather than one clean box, so no horizontal seam runs the whole
##     width of the island.
##   * The bottom is a few THICK roots that start wide enough to overlap the
##     layer above them. A taper only reads as rock if it is continuous with the
##     mass it hangs from; anything thin enough to be seen against the sky on
##     both sides reads as a tooth.
func _build_island_mass(parent: Node3D, size_x: float, size_z: float,
		depth: float, rng) -> void:
	var layer_height: float = depth / float(UNDERSIDE_LAYERS)
	# Warm soil at the top grading to cold dark rock at the bottom. Under a
	# bright sky with strong ambient, a single mid-grey washes out to the same
	# blue as the background and the island loses its silhouette entirely - and
	# a gradient down the side reads as strata rather than as one painted wall.
	var soil := Color(0.36, 0.28, 0.22)
	var deep := Color(0.17, 0.15, 0.16)

	var y: float = 0.0
	# Half-extents of the layer above, so a chunk can never escape it. Letting
	# offsets run free produced exactly one visible artefact: a lower slab
	# sticking out past the rim, reading as a modelling error rather than rock.
	var parent_half_x: float = size_x * 0.5
	var parent_half_z: float = size_z * 0.5

	for index in UNDERSIDE_LAYERS:
		var t: float = float(index) / float(maxi(UNDERSIDE_LAYERS - 1, 1))
		var shrink: float = 1.0 - pow(t, 0.85) * 0.78
		# Two chunks even at the top. One full-width box makes a five-metre flat
		# face that is the first thing the eye lands on.
		var chunks: int = 2 if index < UNDERSIDE_LAYERS - 2 else 3
		# The first layer is a thin rim under the grass, not a wall.
		var height: float = layer_height * (0.55 if index == 0 else 1.0 + float(rng.randi_range(0, 35)) / 100.0)

		var widest_x: float = 0.0
		var widest_z: float = 0.0

		for chunk in chunks:
			var chunk_scale: float = 0.68 + float(rng.randi_range(0, 30)) / 100.0
			var chunk_x: float = size_x * shrink * chunk_scale
			var chunk_z: float = size_z * shrink * chunk_scale

			# Clamp the offset so this chunk stays within the layer above it.
			var room_x: float = maxf(parent_half_x - chunk_x * 0.5, 0.0)
			var room_z: float = maxf(parent_half_z - chunk_z * 0.5, 0.0)
			var offset_x: float = float(rng.randi_range(-100, 100)) / 100.0 * room_x
			var offset_z: float = float(rng.randi_range(-100, 100)) / 100.0 * room_z

			var mesh := BoxMesh.new()
			mesh.size = Vector3(chunk_x, height, chunk_z)

			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			instance.position = Vector3(offset_x, y - height * 0.5, offset_z)
			# Small rotations only. Anything more and the corners escape the
			# clamp above, which is what the clamp exists to prevent.
			instance.rotation.y = float(rng.randi_range(-4, 4)) * PI / 180.0
			# Per-chunk shade jitter, so neighbouring chunks separate visually
			# instead of merging into one silhouette.
			var shade: Color = soil.lerp(deep, t * 0.85)
			shade = shade.lightened(float(rng.randi_range(-4, 6)) / 100.0)
			instance.material_override = _matte(shade)
			parent.add_child(instance)

			widest_x = maxf(widest_x, absf(offset_x) + chunk_x * 0.5)
			widest_z = maxf(widest_z, absf(offset_z) + chunk_z * 0.5)

		parent_half_x = widest_x
		parent_half_z = widest_z
		y -= height

	_build_roots(parent, size_x, size_z, depth, y, rng, deep)


## Thick tapered masses hanging off the bottom of an island.
##
## Wide at the top on purpose: each root starts broad enough to bury itself in
## the layer above, so it reads as the island narrowing to points rather than as
## spikes attached to a flat underside.
func _build_roots(parent: Node3D, size_x: float, size_z: float, depth: float,
		bottom: float, rng, rock: Color) -> void:
	var narrow: float = minf(size_x, size_z)

	# Two or three big ones carrying the silhouette...
	for i in 3:
		var length: float = depth * (0.42 + float(rng.randi_range(0, 40)) / 100.0)
		var width: float = narrow * (0.16 + float(rng.randi_range(0, 10)) / 100.0)
		var angle: float = TAU * float(i) / 3.0 + float(rng.randi_range(0, 80)) / 100.0
		var offset: float = narrow * 0.1 * float(rng.randi_range(20, 100)) / 100.0

		var mesh := CylinderMesh.new()
		mesh.top_radius = width
		mesh.bottom_radius = width * 0.12
		mesh.height = length
		mesh.radial_segments = 6

		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		# Start above `bottom` so the wide end is inside the stack, not below it.
		instance.position = Vector3(
			cos(angle) * offset,
			bottom + length * 0.28,
			sin(angle) * offset)
		instance.rotation = Vector3(
			float(rng.randi_range(-8, 8)) * PI / 180.0,
			angle,
			float(rng.randi_range(-8, 8)) * PI / 180.0)
		instance.material_override = _matte(rock.lerp(Color(0.16, 0.14, 0.13), 0.6))
		parent.add_child(instance)

	# ...and a scatter of stubbier ones filling the gaps between them.
	for i in 5:
		var length: float = depth * (0.12 + float(rng.randi_range(0, 22)) / 100.0)
		var width: float = narrow * (0.07 + float(rng.randi_range(0, 6)) / 100.0)
		var angle: float = float(rng.randi_range(0, 359)) * PI / 180.0
		var offset: float = narrow * float(rng.randi_range(5, 26)) / 100.0

		var mesh := CylinderMesh.new()
		mesh.top_radius = width
		mesh.bottom_radius = width * 0.2
		mesh.height = length
		mesh.radial_segments = 5

		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.position = Vector3(
			cos(angle) * offset,
			bottom + length * 0.55,
			sin(angle) * offset)
		instance.rotation.y = angle
		instance.material_override = _matte(rock.lerp(Color(0.2, 0.17, 0.16), 0.5))
		parent.add_child(instance)


## A drifting deck of flattened blobs below and around the island. This is the
## depth cue that turns "a slab with nothing under it" into "a slab a long way
## above something".
##
## Two hard constraints, and both are enforced by the shape of the motion rather
## than by clamping after the fact:
##
##   * **Never inside the island.** Every cloud sits outside a cylinder that
##     encloses the whole island - and they move by ORBITING that cylinder's
##     axis. Rotation preserves radius exactly, so a cloud that starts outside
##     can never drift inside, whatever the frame rate or however long the game
##     runs. Linear drift with wrapping would need collision checks; this needs
##     none.
##   * **Never near the camera.** The camera orbits a focus at y = 0 and is
##     always above it (pitch is clamped negative), so it never descends below
##     y = 0. Keeping the whole deck a long way under the island's lowest rock
##     means the two volumes cannot meet.
func _build_clouds(centre: Vector3, span: float, island_bottom: float) -> void:
	var rng = RngScript.new(_seed_from_map() ^ 0xC10D)

	# The island is rectangular; its enclosing radius is the half-diagonal. Any
	# cloud beyond that plus a margin is outside the island at every angle.
	var extent: Vector3 = grid.world_extent()
	var border_span: float = float(BORDER_WIDTH) * 2.0 * grid.cell_size
	var half_x: float = (extent.x + border_span) * 0.5
	var half_z: float = (extent.z + border_span) * 0.5
	var keep_out: float = sqrt(half_x * half_x + half_z * half_z) * 1.25

	var top: float = island_bottom - span * 0.18

	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 2.0
	blob.radial_segments = 8
	blob.rings = 5

	for i in CLOUD_COUNT:
		var radius: float = keep_out + span * float(rng.randi_range(0, 190)) / 100.0
		var size: float = span * (0.07 + float(rng.randi_range(0, 13)) / 100.0)
		_clouds.append({
			"radius": radius,
			"angle": float(rng.randi_range(0, 628)) / 100.0,
			"y": top - float(rng.randi_range(0, 110)) * span * 0.006,
			"scale": Vector3(size, size * 0.32, size * 0.78),
			"tilt": float(rng.randi_range(0, 628)) / 100.0,
			# Inner clouds sweep faster, like differential rotation. Uniform
			# angular speed would read as the whole sky being on a turntable.
			"speed": (0.016 + float(rng.randi_range(0, 14)) / 1000.0) * (span / maxf(radius, 1.0)),
		})

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = blob
	multi_mesh.instance_count = _clouds.size()

	_cloud_multi = MultiMeshInstance3D.new()
	_cloud_multi.name = "Clouds"
	_cloud_multi.multimesh = multi_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.94, 0.96, 1.0)
	material.roughness = 1.0
	# Unshaded, so they stay bright from every camera angle instead of turning
	# into grey lumps whenever the sun is behind them.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_multi.material_override = material
	_cloud_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cloud_multi)

	_cloud_centre = centre
	_update_clouds()


## Rewrites all cloud transforms from their orbital parameters. Forty-odd
## instances on one MultiMesh, so this is a rounding error per frame.
func _update_clouds() -> void:
	if _cloud_multi == null:
		return
	var multi_mesh: MultiMesh = _cloud_multi.multimesh
	for i in _clouds.size():
		var cloud: Dictionary = _clouds[i]
		var angle: float = float(cloud["angle"]) + _drift_time * float(cloud["speed"])
		var basis := Basis().scaled(cloud["scale"])
		basis = basis.rotated(Vector3.UP, angle + float(cloud["tilt"]))
		multi_mesh.set_instance_transform(i, Transform3D(basis, Vector3(
			_cloud_centre.x + cos(angle) * float(cloud["radius"]),
			float(cloud["y"]),
			_cloud_centre.z + sin(angle) * float(cloud["radius"]))))


## Smaller islands orbiting the main one. Each is a grassy top plate over the
## same rock mass as the main island, so the archipelago reads as one place
## rather than as a board with decorations near it.
##
## They bob and turn slowly. That is the only motion on screen between waves,
## and a completely still screen reads as a frozen game.
func _build_satellites(centre: Vector3, span: float, top: float) -> void:
	var rng = RngScript.new(_seed_from_map() ^ 0xF10A)
	var pine_scene: PackedScene = _load_scene("%s/pine_medium.glb" % PROP_DIR)
	var small_pine: PackedScene = _load_scene("%s/pine_small.glb" % PROP_DIR)
	var rock_scene: PackedScene = _load_scene("%s/rock_medium.glb" % PROP_DIR)

	for i in SATELLITE_COUNT:
		var island := Node3D.new()
		island.name = "Satellite%d" % (i + 1)

		# A wide spread of sizes. Equal-sized satellites read as a deliberate
		# ring of props; mixed sizes read as terrain.
		var scale: float = 0.1 + float(rng.randi_range(0, 22)) / 100.0
		var size_x: float = span * scale
		var size_z: float = size_x * (0.7 + float(rng.randi_range(0, 50)) / 100.0)

		# Grass plate on top, matching the board's own surface colour.
		var plate := MeshInstance3D.new()
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(size_x, size_x * 0.22, size_z)
		plate.mesh = plate_mesh
		plate.position = Vector3(0.0, -size_x * 0.11, 0.0)
		plate.material_override = _matte(map_def.ground_color)
		island.add_child(plate)

		var mass := Node3D.new()
		mass.position = Vector3(0.0, -size_x * 0.2, 0.0)
		island.add_child(mass)
		_build_island_mass(mass, size_x * 0.94, size_z * 0.94, size_x * 0.85, rng)

		# Dress the top. Bigger islands get a small forest, small ones a rock.
		var props: int = 1 if scale < 0.16 else 3
		for p in props:
			var scene: PackedScene = pine_scene if p == 0 else small_pine
			if rng.chance_permille(280) or scene == null:
				scene = rock_scene
			if scene == null:
				continue
			var prop: Node3D = scene.instantiate()
			prop.position = Vector3(
				float(rng.randi_range(-32, 32)) / 100.0 * size_x,
				0.0,
				float(rng.randi_range(-32, 32)) / 100.0 * size_z)
			prop.rotation.y = float(rng.randi_range(0, 359)) * PI / 180.0
			prop.scale = Vector3.ONE * (0.7 + float(rng.randi_range(0, 60)) / 100.0)
			island.add_child(prop)

		# Ringed clear of the board, and always BELOW the play surface.
		#
		# Not for looks - for the camera. It orbits a focus at y = 0 at up to 80
		# units, so at a shallow pitch it swings wide and low. A satellite
		# sitting at or above board height in that ring would eventually be flown
		# straight through. Keeping the whole archipelago under the board means
		# the camera volume and the satellite volume never intersect.
		var angle: float = TAU * float(i) / float(SATELLITE_COUNT) + float(rng.randi_range(0, 60)) / 100.0
		var radius: float = span * (0.68 + float(rng.randi_range(0, 60)) / 100.0)
		var height: float = top - 3.0 - float(rng.randi_range(0, 170)) * 0.11
		island.position = Vector3(
			centre.x + cos(angle) * radius, height, centre.z + sin(angle) * radius)
		island.rotation.y = float(rng.randi_range(0, 359)) * PI / 180.0
		add_child(island)

		_floaters.append({
			"node": island,
			"base_y": height,
			"phase": float(rng.randi_range(0, 628)) / 100.0,
			"amplitude": 0.2 + float(rng.randi_range(0, 45)) / 100.0,
			"spin": (float(rng.randi_range(0, 20)) - 10.0) / 900.0,
		})


## Water pouring off the island's edge and dispersing into mist.
##
## No shader and no particle system: a tapered translucent slab, a scatter of
## mist blobs at top and bottom, and a handful of droplets that fall and loop.
## At the distance an RTS camera sits, that is indistinguishable from something
## far more expensive, and it costs nothing to maintain.
func _build_waterfalls(centre: Vector3, island_x: float, island_z: float, top: float) -> void:
	var rng = RngScript.new(_seed_from_map() ^ 0xFA11)

	for i in WATERFALL_COUNT:
		# Placed on the rim, spaced around the island rather than clustered.
		var angle: float = TAU * float(i) / float(WATERFALL_COUNT) + 0.6
		var edge := Vector3(
			centre.x + cos(angle) * island_x * 0.46,
			top + 0.4,
			centre.z + sin(angle) * island_z * 0.46)

		var fall := Node3D.new()
		fall.name = "Waterfall%d" % (i + 1)
		fall.position = edge
		add_child(fall)

		var length: float = 9.0 + float(rng.randi_range(0, 90)) / 10.0
		var width: float = 1.4 + float(rng.randi_range(0, 12)) / 10.0

		# The sheet. Widening slightly as it falls, which is what water does and
		# what stops it reading as a solid pillar.
		var sheet := MeshInstance3D.new()
		var sheet_mesh := CylinderMesh.new()
		sheet_mesh.top_radius = width * 0.5
		sheet_mesh.bottom_radius = width * 0.85
		sheet_mesh.height = length
		sheet_mesh.radial_segments = 6
		sheet.mesh = sheet_mesh
		sheet.position = Vector3(0.0, -length * 0.5, 0.0)
		sheet.material_override = _water_material(0.55)
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fall.add_child(sheet)

		# Mist where it leaves the rim and where it dissipates.
		_add_mist(fall, Vector3(0.0, -0.3, 0.0), width * 1.1, 3, rng)
		_add_mist(fall, Vector3(0.0, -length, 0.0), width * 2.2, 5, rng)

		# Droplets. Each falls, then loops back to the top - cheap, and the eye
		# reads looping motion as flow.
		for d in 4:
			var drop := MeshInstance3D.new()
			var drop_mesh := SphereMesh.new()
			drop_mesh.radius = 0.16 + float(rng.randi_range(0, 10)) / 100.0
			drop_mesh.height = drop_mesh.radius * 2.6
			drop_mesh.radial_segments = 6
			drop_mesh.rings = 4
			drop.mesh = drop_mesh
			drop.material_override = _water_material(0.85)
			drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			drop.position = Vector3(
				float(rng.randi_range(-40, 40)) / 100.0 * width,
				-float(d) * length / 4.0,
				float(rng.randi_range(-40, 40)) / 100.0 * width)
			fall.add_child(drop)

			_waterfall_drops.append({
				"node": drop,
				"length": length,
				"offset": float(d) * length / 4.0,
				"speed": 7.0 + float(rng.randi_range(0, 40)) / 10.0,
			})


func _add_mist(parent: Node3D, at: Vector3, size: float, count: int, rng) -> void:
	for i in count:
		var blob := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = size * (0.5 + float(rng.randi_range(0, 50)) / 100.0)
		mesh.height = mesh.radius * 1.4
		mesh.radial_segments = 7
		mesh.rings = 4
		blob.mesh = mesh
		blob.position = at + Vector3(
			float(rng.randi_range(-60, 60)) / 100.0 * size,
			float(rng.randi_range(-30, 30)) / 100.0 * size,
			float(rng.randi_range(-60, 60)) / 100.0 * size)
		blob.material_override = _water_material(0.3)
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(blob)


## Unshaded so water stays bright whatever angle the sun is at, and alpha rather
## than additive so a thick sheet does not glow.
static func _water_material(alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.82, 0.93, 1.0, alpha)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


# ---------------------------------------------------------------------------
# Props
# ---------------------------------------------------------------------------

## Seeded from the map id, so a given map always dresses itself identically.
## Not required for correctness - this is the view layer and cannot affect the
## sim - but it makes screenshots comparable between runs, which matters when
## the person reviewing the art cannot see it happen live.
func _scatter_props() -> void:
	var kinds: Array = [
		{"path": "%s/pine_large.glb" % PROP_DIR, "weight": 26},
		{"path": "%s/pine_medium.glb" % PROP_DIR, "weight": 30},
		{"path": "%s/pine_small.glb" % PROP_DIR, "weight": 18},
		{"path": "%s/rock_medium.glb" % PROP_DIR, "weight": 12},
		{"path": "%s/rock_small.glb" % PROP_DIR, "weight": 8},
		{"path": "%s/rock_large.glb" % PROP_DIR, "weight": 4},
		{"path": "%s/bush.glb" % PROP_DIR, "weight": 12},
	]
	var scenes: Array = []
	var weights := PackedInt32Array()
	for kind in kinds:
		var scene: PackedScene = _load_scene(str(kind["path"]))
		if scene != null:
			scenes.append(scene)
			weights.append(int(kind["weight"]))
	if scenes.is_empty():
		return

	var rng = RngScript.new(_seed_from_map())
	var cell_size: float = grid.cell_size

	for y in range(-BORDER_WIDTH, grid.height + BORDER_WIDTH):
		for x in range(-BORDER_WIDTH, grid.width + BORDER_WIDTH):
			var cell := Vector2i(x, y)
			if grid.in_bounds(cell):
				continue
			if not rng.chance_permille(PROP_CHANCE_PERMILLE):
				continue

			var index: int = rng.weighted_index(weights)
			if index < 0:
				continue

			var distance: int = maxi(
				maxi(-x, x - grid.width + 1),
				maxi(-y, y - grid.height + 1))
			var drop: float = float(distance) * 0.34

			var prop: Node3D = scenes[index].instantiate()
			var world: Vector3 = grid.cell_to_world(cell)
			# Jitter inside the cell, so the scatter does not read as a grid.
			var jitter_x: float = (float(rng.randi_range(-40, 40)) / 100.0) * cell_size * 0.5
			var jitter_z: float = (float(rng.randi_range(-40, 40)) / 100.0) * cell_size * 0.5
			prop.position = Vector3(world.x + jitter_x, BORDER_TOP - drop, world.z + jitter_z)
			prop.rotation.y = float(rng.randi_range(0, 359)) * PI / 180.0
			var scale: float = 0.82 + float(rng.randi_range(0, 45)) / 100.0
			prop.scale = Vector3.ONE * scale
			_props.add_child(prop)


# ---------------------------------------------------------------------------
# Markers and helpers
# ---------------------------------------------------------------------------

## Spawn and goal markers. They pulse, which is the cheapest way to make the two
## most important cells on the board findable at a glance - and with bloom on,
## the pulse spills light onto the surrounding tiles rather than just changing
## the disc's brightness.
var _markers: Array = []
var _pulse_time: float = 0.0


func _build_markers() -> void:
	_add_marker(grid.cell_to_world(grid.spawn), Color(1.0, 0.5, 0.2), PATH_TOP, 0.0)
	_add_marker(grid.cell_to_world(grid.goal), Color(0.35, 0.95, 0.55), PATH_TOP, PI)


func _add_marker(world: Vector3, color: Color, top: float, phase: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = grid.cell_size * 0.36
	mesh.bottom_radius = grid.cell_size * 0.36
	mesh.height = 0.1
	mesh.radial_segments = 8

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3(world.x, top + 0.06, world.z)
	var material := _matte(color)
	material.emission_enabled = true
	material.emission = color
	# Above the glow HDR threshold at the top of the pulse, below it at the
	# bottom, so the marker visibly breathes rather than just dimming.
	material.emission_energy_multiplier = 1.2
	instance.material_override = material
	add_child(instance)

	# A wider, fainter ring around it, scaled by the same pulse.
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = grid.cell_size * 0.44
	ring_mesh.outer_radius = grid.cell_size * 0.52
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 5

	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.position = Vector3(world.x, top + 0.04, world.z)
	var ring_material := _matte(color)
	ring_material.emission_enabled = true
	ring_material.emission = color
	ring_material.emission_energy_multiplier = 0.8
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color.a = 0.55
	ring.material_override = ring_material
	add_child(ring)

	_markers.append({
		"disc": material,
		"ring": ring,
		"ring_material": ring_material,
		"phase": phase,
	})


func _process(delta: float) -> void:
	_drift_time += delta
	for floater in _floaters:
		var node: Node3D = floater["node"]
		if not is_instance_valid(node):
			continue
		node.position.y = float(floater["base_y"]) + sin(
			_drift_time * 0.5 + float(floater["phase"])) * float(floater["amplitude"])
		node.rotation.y += float(floater["spin"]) * delta

	_update_clouds()

	# Droplets fall and wrap back to the top. fposmod does the wrapping without
	# per-drop state, so this stays a pure function of elapsed time - which means
	# it cannot drift out of sync however long the game runs.
	for drop in _waterfall_drops:
		var node: Node3D = drop["node"]
		if not is_instance_valid(node):
			continue
		var length: float = float(drop["length"])
		var travelled: float = _drift_time * float(drop["speed"]) + float(drop["offset"])
		node.position.y = -fposmod(travelled, length)

	if _markers.is_empty():
		return
	_pulse_time += delta
	for marker in _markers:
		# 0..1, roughly 1.4 seconds a cycle.
		var wave: float = 0.5 + 0.5 * sin(_pulse_time * 4.4 + float(marker["phase"]))
		marker["disc"].emission_energy_multiplier = 0.7 + wave * 1.1
		marker["ring_material"].albedo_color.a = 0.2 + wave * 0.45
		var scale: float = 0.94 + wave * 0.12
		marker["ring"].scale = Vector3(scale, 1.0, scale)


## Stable integer from the map id, so the same map always scatters identically.
func _seed_from_map() -> int:
	var value: int = 2166136261
	for i in str(map_def.id).length():
		value = ((value ^ str(map_def.id).unicode_at(i)) * 16777619) & 0xFFFFFFFF
	return value


static func _load_scene(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		push_warning("Board: missing '%s'" % path)
		return null
	return load(path)


## Pulls the first mesh out of a .glb for MultiMesh use, along with the local
## offset of the node that carried it.
##
## Returning both matters: MultiMesh instances raw mesh data and knows nothing
## about the scene graph the mesh came from, so any transform an artist put on
## the node is silently lost unless the caller re-applies it.
static func _load_mesh(path: String) -> Dictionary:
	var scene: PackedScene = _load_scene(path)
	if scene == null:
		return {}
	var root: Node = scene.instantiate()
	var result: Dictionary = {}
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var node: MeshInstance3D = child
		# Global rather than local: the mesh may sit under intermediate nodes,
		# and every one of their transforms is equally lost.
		result = {"mesh": node.mesh, "offset": _accumulated_offset(node, root)}
		break
	root.free()
	return result


static func _accumulated_offset(node: Node3D, root: Node) -> Vector3:
	var offset := Vector3.ZERO
	var cursor: Node = node
	while cursor != null and cursor != root.get_parent():
		if cursor is Node3D:
			offset += (cursor as Node3D).position
		cursor = cursor.get_parent()
	return offset


## Used when the terrain kit has not been built yet, so the game still runs on a
## fresh clone that has not run scripts/build_art.
static func _fallback_block() -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3(1.98, 1.1, 1.98)
	return box


## Terrain is matte on purpose. Roughness 0.88 rather than 1.0 leaves just
## enough specular for the sky gradient to graze the bevelled top edges of each
## slab, which is what separates one tile from the next without an outline.
static func _matte(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	material.metallic = 0.0
	return material
