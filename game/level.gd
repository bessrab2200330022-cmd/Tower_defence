extends Node3D
## The world renderer. Reads simulation state, never writes to it.
##
## Everything visual is built from code and from the .tres definitions, so
## adding a tower or enemy needs no scene editing at all.

signal build_requested(cell: Vector2i, tower_id: String)
signal sell_requested(cell: Vector2i)

const Types := preload("res://sim/sim_types.gd")
const CameraScript := preload("res://game/rts_camera.gd")
const EnemyViewScript := preload("res://game/views/enemy_view.gd")
const TowerViewScript := preload("res://game/views/tower_view.gd")
const ProjectileViewScript := preload("res://game/views/projectile_view.gd")
const EffectsScript := preload("res://game/views/effects.gd")
const BoardScript := preload("res://game/board.gd")
const LightingScript := preload("res://game/lighting.gd")

var sim
var catalog
var map_def

var camera: Camera3D
var effects: Node3D
var board: Node3D
var lighting: Node3D

var _enemy_views: Dictionary = {}
var _tower_views: Dictionary = {}
var _projectile_views: Dictionary = {}

## tower_id -> TowerDef and enemy_id -> EnemyDef, so effect spawners can reach
## the definition without a catalog lookup on every shot. Kept in step with the
## view dictionaries: same keys, same lifetime.
var _tower_defs: Dictionary = {}
var _enemy_defs: Dictionary = {}

## Seconds between projectile trail sparks.
const TRAIL_INTERVAL: float = 0.045
var _trail_timer: float = 0.0

var _ghost: MeshInstance3D
var _ghost_range: MeshInstance3D
var _ghost_material: StandardMaterial3D
var _selected_tower_id: String = ""
var _sell_mode: bool = false
var _hover_cell: Vector2i = Vector2i(-1, -1)


func build(simulation, catalog_ref, map_resource) -> void:
	sim = simulation
	catalog = catalog_ref
	map_def = map_resource

	_build_environment()
	_build_board()
	_build_camera()
	_build_ghost()

	effects = EffectsScript.new()
	effects.name = "Effects"
	add_child(effects)


# ---------------------------------------------------------------------------
# Static world
# ---------------------------------------------------------------------------

## Sky, sun, shadows, SSAO, reflections and bloom all live in game/lighting.gd.
func _build_environment() -> void:
	lighting = LightingScript.new()
	lighting.name = "Lighting"
	add_child(lighting)
	lighting.build()


## Terrain, scatter props and the floating island beneath the board all come
## from game/board.gd, assembled from the same ASCII layout the pathfinder
## walks. See the header of that file for why the map is built here rather
## than in Blender.
func _build_board() -> void:
	board = BoardScript.new()
	board.name = "Board"
	add_child(board)
	board.build(sim.grid, map_def)


## Superseded by board.gd, which draws spawn/goal markers at the path's height
## rather than at zero. Kept only because removing it is a separate change from
## building the board; delete it once nothing references it.
func _add_marker_legacy(position: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = sim.grid.cell_size * 0.34
	mesh.bottom_radius = sim.grid.cell_size * 0.34
	mesh.height = 0.12
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3(position.x, 0.06, position.z)
	var material := _make_material(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.8
	instance.material_override = material
	add_child(instance)


func _build_camera() -> void:
	camera = CameraScript.new()
	camera.name = "Camera"
	add_child(camera)
	var extent: Vector3 = sim.grid.world_extent()
	camera.setup(Vector3(extent.x * 0.5, 0.0, extent.z * 0.5), maxf(extent.x, extent.z))


func _build_ghost() -> void:
	var size: float = sim.grid.cell_size
	var box := BoxMesh.new()
	box.size = Vector3(size * 0.9, 0.9, size * 0.9)
	_ghost = MeshInstance3D.new()
	_ghost.mesh = box
	_ghost_material = _make_material(Color(0.4, 1.0, 0.5, 0.35))
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost.material_override = _ghost_material
	_ghost.visible = false
	add_child(_ghost)

	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.0
	_ghost_range = MeshInstance3D.new()
	_ghost_range.mesh = ring
	var ring_material := _make_material(Color(0.5, 0.9, 1.0, 0.25))
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_range.material_override = ring_material
	_ghost_range.visible = false
	add_child(_ghost_range)


static func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	material.metallic = 0.0
	return material


# ---------------------------------------------------------------------------
# Sim -> view
# ---------------------------------------------------------------------------

func consume_events(events: Array) -> void:
	for event in events:
		match int(event["type"]):
			Types.Event.ENEMY_SPAWNED:
				_add_enemy_view(event)
			Types.Event.ENEMY_DAMAGED:
				var hit = _enemy_views.get(int(event["enemy_id"]), null)
				if hit != null:
					hit.flash()
			Types.Event.ENEMY_KILLED:
				_on_enemy_killed(event)
				_remove_view(_enemy_views, event["enemy_id"])
			Types.Event.ENEMY_LEAKED:
				# No death effect: it did not die, it got through. Rewarding a
				# leak with the same flourish as a kill reads as a win.
				_remove_view(_enemy_views, event["enemy_id"])
			Types.Event.TOWER_BUILT:
				_add_tower_view(event)
			Types.Event.TOWER_SOLD:
				_remove_view(_tower_views, event["tower_id"])
			Types.Event.TOWER_FIRED:
				_on_tower_fired(event)
			Types.Event.PROJECTILE_SPAWNED:
				_add_projectile_view(event)
			Types.Event.PROJECTILE_HIT:
				_on_projectile_hit(event)
				_remove_view(_projectile_views, event["projectile_id"])
			Types.Event.PROJECTILE_EXPIRED:
				# Fizzled, so no impact burst - but the node still has to go.
				_remove_view(_projectile_views, event["projectile_id"])
			_:
				pass


func _add_enemy_view(event: Dictionary) -> void:
	var def = catalog.get_enemy(str(event["def_id"]))
	if def == null:
		return
	_enemy_defs[int(event["enemy_id"])] = def
	var view := EnemyViewScript.new()
	# Enemies only ever walk on path cells, which board.gd recesses below the
	# grass, so a single constant drop is exact rather than an approximation.
	view.ground_offset = BoardScript.PATH_TOP
	view.setup(def)
	view.position = event["position"]
	add_child(view)
	_enemy_views[int(event["enemy_id"])] = view


func _add_tower_view(event: Dictionary) -> void:
	var def = catalog.get_tower(str(event["def_id"]))
	if def == null:
		return
	_tower_defs[int(event["tower_id"])] = def
	var view := TowerViewScript.new()
	view.setup(def)
	view.position = event["position"]
	add_child(view)
	_tower_views[int(event["tower_id"])] = view


func _add_projectile_view(event: Dictionary) -> void:
	var def = _tower_defs.get(int(event.get("tower_id", 0)), null)
	var view := ProjectileViewScript.new()
	view.setup(def, _effect_color(def))
	view.position = event["position"]
	add_child(view)
	_projectile_views[int(event["projectile_id"])] = view


func _on_tower_fired(event: Dictionary) -> void:
	var tower_id := int(event["tower_id"])
	var view = _tower_views.get(tower_id, null)
	if view != null:
		view.on_fired()

	var def = _tower_defs.get(tower_id, null)
	var color: Color = _effect_color(def)
	var origin: Vector3 = event["origin"]
	# The target is an enemy, and enemies render on the recessed path.
	var target: Vector3 = _on_ground(event["target_position"])

	# Fire from roughly the muzzle rather than the tower's origin, and aim at
	# chest height rather than the enemy's feet. Both are eyeballed offsets -
	# the sim tracks a point, not a barrel tip, and giving it one would be sim
	# state that exists purely to make a beam line up.
	var muzzle: Vector3 = origin + Vector3(0.0, 1.4, 0.0)
	var direction: Vector3 = target - muzzle
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		muzzle += direction.normalized() * 0.9

	effects.spawn_muzzle_flash(muzzle, color)

	if int(event.get("fire_mode", Types.FireMode.PROJECTILE)) == Types.FireMode.HITSCAN:
		effects.spawn_beam(muzzle, target + Vector3(0.0, 0.5, 0.0), color)
		effects.spawn_burst(target + Vector3(0.0, 0.3, 0.0), color, 0.5)


func _on_projectile_hit(event: Dictionary) -> void:
	var position: Vector3 = _on_ground(event["position"])
	var radius: float = float(event.get("splash_radius", 0.0))
	var color := Color(0.7, 0.9, 1.0)

	if radius > 0.05:
		# A splash weapon gets the full treatment. The ring is drawn at the true
		# splash radius, so the area of effect is learnable by watching rather
		# than by reading the .tres.
		effects.spawn_explosion(position, color, maxf(radius * 0.5, 0.7))
		effects.spawn_ring(position, color, radius)
	else:
		effects.spawn_burst(position, color, 0.6)


func _on_enemy_killed(event: Dictionary) -> void:
	var enemy_id := int(event["enemy_id"])
	var def = _enemy_defs.get(enemy_id, null)
	var color: Color = def.body_color if def != null else Color(1.0, 0.75, 0.35)
	# Bigger enemies die harder. Scaled off the def's radius so a Brute's death
	# carries weight a Drone's does not.
	var scale: float = 1.0 if def == null else clampf(def.radius / 0.45, 0.7, 2.0)
	var position: Vector3 = _on_ground(event["position"])

	if scale >= 1.3:
		# Heavy enemies detonate. Under that threshold an explosion every time a
		# drone pops would bury the board in smoke during a swarm wave.
		effects.spawn_explosion(position, color, scale * 0.9)
	else:
		effects.spawn_death(position, color, scale)
	_enemy_defs.erase(enemy_id)


## Drops a simulation position onto the visible path surface. The sim works on a
## flat plane at y = 0; board.gd recesses the path below the grass for looks, so
## anything spawned at an enemy's feet needs the same drop the enemy view gets.
static func _on_ground(position: Vector3) -> Vector3:
	return Vector3(position.x, position.y + BoardScript.PATH_TOP, position.z)


## Falls back to a neutral blue when a tower def is missing, which only happens
## if a tower was built before its def loaded - i.e. never, in practice.
static func _effect_color(def) -> Color:
	return def.effect_color if def != null else Color(0.7, 0.95, 1.0)


func _remove_view(store: Dictionary, key) -> void:
	var id := int(key)
	var view = store.get(id, null)
	if view != null:
		view.queue_free()
	store.erase(id)
	# Def caches are keyed the same way and must not outlive their view, or a
	# long match slowly leaks a dictionary entry per dead enemy.
	if store == _tower_views:
		_tower_defs.erase(id)
	elif store == _enemy_views:
		_enemy_defs.erase(id)


## How many view nodes are currently tracked, per kind. Every count must equal
## the matching array in the simulation: views are created and destroyed only
## from drained events, so a mismatch means an event went missing and a mesh is
## orphaned. `tests/run_autoplay.gd` checks this every frame.
func view_counts() -> Dictionary:
	return {
		"enemies": _enemy_views.size(),
		"towers": _tower_views.size(),
		"projectiles": _projectile_views.size(),
	}


## Hands every moving view the position it should interpolate FROM. Called by
## game/main.gd immediately before each Simulation.step(), so once the step
## returns the sim holds tick N and every view still remembers tick N-1 — which
## is exactly the pair sync() blends between.
##
## Nothing here reads back into the sim, and the stored positions live on the
## view nodes rather than on the entities: `sim/` must not learn that a renderer
## exists, or `snapshot_hash()` stops being a statement about the game alone.
func capture_tick_start() -> void:
	for enemy in sim.enemies:
		var view = _enemy_views.get(enemy.id, null)
		if view != null:
			view.capture_previous(enemy.position)
	for projectile in sim.projectiles:
		var view = _projectile_views.get(projectile.id, null)
		if view != null:
			view.capture_previous(projectile.position)


## Called once per rendered frame. Pure read of sim state.
##
## `alpha` is how far this frame sits between the last simulated tick and the
## next, 0..1. The default of 1.0 means "no interpolation, land on the sim
## position" — that is what a caller which never calls capture_tick_start()
## gets, including `tests/run_autoplay.gd`, whose behaviour must not change.
func sync(delta: float, alpha: float = 1.0) -> void:
	var blend: float = clampf(alpha, 0.0, 1.0)

	for enemy in sim.enemies:
		var view = _enemy_views.get(enemy.id, null)
		if view != null:
			view.update_from(enemy, delta, blend)
	for tower in sim.towers:
		var view = _tower_views.get(tower.id, null)
		if view != null:
			view.update_from(tower, delta)
	# Trail sparks, throttled rather than emitted every frame. At 60fps a
	# per-frame trail buries every other effect in the pool's recycling budget
	# and reads as a solid tube rather than as motion.
	_trail_timer += delta
	var emit_trail: bool = _trail_timer >= TRAIL_INTERVAL
	if emit_trail:
		_trail_timer = 0.0

	for projectile in sim.projectiles:
		# Where the spark is dropped, which is the shell's rendered position and
		# not its sim position - otherwise the trail detaches from the shell it
		# is supposed to be coming off, by up to one tick of travel.
		var spark: Vector3 = projectile.position
		var view = _projectile_views.get(projectile.id, null)
		if view != null:
			# update_to rather than a bare position assignment: the view derives
			# its facing from the movement between ticks, so it needs to see both
			# the new position and how long it took to get there.
			view.update_to(projectile.position, delta, blend)
			spark = view.position
		if emit_trail:
			var def = _tower_defs.get(projectile.owner_tower_id, null)
			effects.spawn_burst(spark - Vector3(0.0, 0.35, 0.0),
				_effect_color(def), 0.28)

	effects.step(delta)
	_update_ghost()


# ---------------------------------------------------------------------------
# Placement input
# ---------------------------------------------------------------------------

func set_ghost_tower(tower_id: String) -> void:
	_selected_tower_id = tower_id
	if tower_id != "":
		_sell_mode = false


func set_sell_mode(enabled: bool) -> void:
	_sell_mode = enabled
	if enabled:
		_selected_tower_id = ""


func cell_under_mouse() -> Vector2i:
	# No viewport when sync() is driven by a harness rather than by a rendered
	# frame. Returning "nowhere" is the honest answer and keeps Level callable
	# headless, which is the property the autoplay gate is built on.
	var viewport: Viewport = get_viewport()
	if camera == null or viewport == null:
		return Vector2i(-1, -1)
	var mouse: Vector2 = viewport.get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse)
	var direction: Vector3 = camera.project_ray_normal(mouse)
	var ground := Plane(Vector3.UP, 0.0)
	var hit = ground.intersects_ray(origin, direction)
	if hit == null:
		return Vector2i(-1, -1)
	return sim.grid.world_to_cell(hit)


func _update_ghost() -> void:
	_hover_cell = cell_under_mouse()
	var showing: bool = _selected_tower_id != "" and sim.grid.in_bounds(_hover_cell)
	_ghost.visible = showing
	_ghost_range.visible = showing
	if not showing:
		return

	var world: Vector3 = sim.grid.cell_to_world(_hover_cell)
	_ghost.position = Vector3(world.x, 0.45, world.z)
	_ghost_range.position = Vector3(world.x, 0.12, world.z)

	var def = catalog.get_tower(_selected_tower_id)
	var radius: float = def.range_world if def != null else 1.0
	_ghost_range.scale = Vector3(radius, 1.0, radius)

	var allowed: bool = sim.build_blocked_reason(_hover_cell, _selected_tower_id) == ""
	_ghost_material.albedo_color = Color(0.4, 1.0, 0.5, 0.35) if allowed else Color(1.0, 0.35, 0.35, 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var cell: Vector2i = cell_under_mouse()
	if not sim.grid.in_bounds(cell):
		return
	if _sell_mode:
		sell_requested.emit(cell)
	elif _selected_tower_id != "":
		build_requested.emit(cell, _selected_tower_id)
