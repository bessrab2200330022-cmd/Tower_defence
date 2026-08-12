extends Node3D
## The world renderer. Reads simulation state, never writes to it.
##
## Everything visual is built from code and from the .tres definitions, so
## adding a tower or enemy needs no scene editing at all.

signal build_requested(cell: Vector2i, tower_id: String)
signal sell_requested(cell: Vector2i)
## A placed tower was clicked with nothing else armed. Nothing consumes this
## yet; it is the hook ROADMAP 2.3's inspection panel will hang off, and
## emitting it now means the selection state below has exactly one owner.
signal tower_inspected(cell: Vector2i)

const Types := preload("res://sim/sim_types.gd")
const CameraScript := preload("res://game/rts_camera.gd")
const EnemyViewScript := preload("res://game/views/enemy_view.gd")
const TowerViewScript := preload("res://game/views/tower_view.gd")
const ProjectileViewScript := preload("res://game/views/projectile_view.gd")
const EffectsScript := preload("res://game/views/effects.gd")
const BoardScript := preload("res://game/board.gd")
const LightingScript := preload("res://game/lighting.gd")
const AudioScript := preload("res://game/audio/audio_director.gd")
const RangeRingScript := preload("res://game/views/range_ring.gd")
const CellMarkerScript := preload("res://game/views/cell_marker.gd")
const DamageNumbersScript := preload("res://game/views/damage_numbers.gd")
const InputActions := preload("res://game/input_actions.gd")

## Placement feedback palette. Green means the click will work, red means it
## will be refused, amber marks a tower already standing there, and the pale
## blue is a neutral "you are pointing at this cell".
const COLOR_VALID := Color(0.35, 1.0, 0.55)
const COLOR_INVALID := Color(1.0, 0.32, 0.30)
const COLOR_TOWER := Color(1.0, 0.78, 0.35)
const COLOR_NEUTRAL := Color(0.62, 0.80, 0.95)
const COLOR_RANGE := Color(0.45, 0.85, 1.0)

## `Types.Event.TOWER_UPGRADED`, resolved by NAME rather than written as a
## number, because at the time of writing `sim/` has not declared it yet - the
## simulation agent is adding it in a parallel session.
##
## A named GDScript enum is a constant Dictionary at runtime, so this looks the
## member up and takes whichever id the sim ends up choosing. Until the member
## exists it evaluates to -1, which no event's `type` can equal, so the consumer
## below is inert rather than wrong. Hard-coding 17 would have bound this to a
## number nobody promised.
##
## This matters more than usual. An upgrade mutates a view without creating or
## destroying one, so `tests/run_autoplay.gd`'s view-count assert cannot see a
## missing consumer - see docs/ARCHITECTURE.md, "What the view-count invariant
## does not catch". If this binding is wrong, a tier-3 tower wears its tier-1
## mesh and every gate stays green.
## `static var`, not `const`: a Dictionary lookup is not a constant
## expression, and the whole point is that this is resolved at load time
## rather than written down.
static var EVENT_TOWER_UPGRADED: int = int(Types.Event.get("TOWER_UPGRADED", -1))

## The three ability events, bound the same way and for the same reason: the
## simulation agent is writing the producers in a parallel session and had not
## landed them when this was written. Each resolves to -1 until it exists, which
## no event's `type` can equal.
##
## Of the three only ENEMY_SPLIT is covered by the autoplay assert, because it is
## the only one that creates entities - two new enemies mean two new views, and a
## missing consumer would show as a count mismatch. ENEMY_HEALED and AURA_APPLIED
## mutate without creating, so they are in the same blind spot TOWER_UPGRADED is.
static var EVENT_ENEMY_HEALED: int = int(Types.Event.get("ENEMY_HEALED", -1))
static var EVENT_ENEMY_SPLIT: int = int(Types.Event.get("ENEMY_SPLIT", -1))
static var EVENT_AURA_APPLIED: int = int(Types.Event.get("AURA_APPLIED", -1))

## Heal pulses are green because the number they accompany is a *gain*; using the
## damage palette for both is how a healed enemy reads as a bug.
const COLOR_HEAL := Color(0.45, 1.0, 0.62)
const COLOR_AURA := Color(0.65, 0.55, 1.0)

## How long an aura ring survives without being refreshed.
##
## The contract has an "applied" event and no "removed" event, so persistence is
## built as a heartbeat: every AURA_APPLIED re-arms the ring, and when the source
## dies the events stop and the ring fades on its own. That is deliberately
## robust to whatever cadence the sim ends up emitting at - per tick, per pulse
## or per newly-affected enemy all work - and it cannot leak a ring for a Warden
## that is no longer alive.
const AURA_TTL: float = 0.9
## Fallback when the source's def carries no radius field. Only used until the
## enemy schema grows one.
const AURA_FALLBACK_RADIUS: float = 4.0

var sim
var catalog
var map_def

var camera: Camera3D
var effects: Node3D
var board: Node3D
var lighting: Node3D
var audio: Node3D
var damage_numbers: Node3D

var _enemy_views: Dictionary = {}
var _tower_views: Dictionary = {}
var _projectile_views: Dictionary = {}

## tower_id -> TowerDef and enemy_id -> EnemyDef, so effect spawners can reach
## the definition without a catalog lookup on every shot. Kept in step with the
## view dictionaries: same keys, same lifetime.
var _tower_defs: Dictionary = {}
var _enemy_defs: Dictionary = {}

## source enemy id -> its aura ring, and how long that ring has left. Not counted
## by view_counts(): these track a source's *ability*, not an entity, and the
## count invariant is about one view per sim entity.
var _aura_rings: Dictionary = {}
var _aura_life: Dictionary = {}

## Seconds between projectile trail sparks.
const TRAIL_INTERVAL: float = 0.045
var _trail_timer: float = 0.0

var _ghost: MeshInstance3D
var _ghost_material: StandardMaterial3D
## Two rings, not one: the placement preview and the selected tower can both be
## on screen at once, and sharing a node would make them flicker against each
## other as the mouse moves.
var _ghost_range: MeshInstance3D
var _selection_range: MeshInstance3D
var _hover_marker: MeshInstance3D
var _selection_marker: MeshInstance3D

var _selected_tower_id: String = ""
var _sell_mode: bool = false
var _hover_cell: Vector2i = Vector2i(-1, -1)
## The placed tower the player has clicked, in grid coordinates. (-1, -1) means
## nothing is selected. View state only - the simulation has no concept of a
## selection and must not grow one.
var _selected_cell: Vector2i = Vector2i(-1, -1)


func build(simulation, catalog_ref, map_resource) -> void:
	sim = simulation
	catalog = catalog_ref
	map_def = map_resource
	# The camera reads InputMap actions and tests/run_autoplay.gd builds a Level
	# without main.gd, so the actions have to exist by the time it does.
	InputActions.ensure_installed()

	_build_environment()
	_build_board()
	_build_camera()
	_build_ghost()

	effects = EffectsScript.new()
	effects.name = "Effects"
	add_child(effects)

	audio = AudioScript.new()
	audio.name = "Audio"
	add_child(audio)
	audio.build(catalog)

	damage_numbers = DamageNumbersScript.new()
	damage_numbers.name = "DamageNumbers"
	add_child(damage_numbers)
	damage_numbers.build()


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

	_ghost_range = RangeRingScript.new()
	_ghost_range.name = "GhostRange"
	_ghost_range.set_tint(COLOR_RANGE)
	add_child(_ghost_range)

	_selection_range = RangeRingScript.new()
	_selection_range.name = "SelectionRange"
	_selection_range.set_tint(COLOR_TOWER)
	add_child(_selection_range)

	_hover_marker = CellMarkerScript.new()
	_hover_marker.name = "HoverMarker"
	add_child(_hover_marker)

	_selection_marker = CellMarkerScript.new()
	_selection_marker.name = "SelectionMarker"
	add_child(_selection_marker)


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
		# Sound first and unconditionally, so the audio mapping lives in one file
		# rather than being sprinkled through the match below. It reads the event
		# and nothing else - see game/audio/audio_director.gd.
		if audio != null:
			audio.handle(event)

		var type: int = int(event["type"])
		# Handled ahead of the match because `match` needs constant patterns and
		# this id is resolved at runtime - see EVENT_TOWER_UPGRADED.
		if type == EVENT_TOWER_UPGRADED:
			_on_tower_upgraded(event)
			continue
		if type == EVENT_ENEMY_HEALED:
			_on_enemy_healed(event)
			continue
		if type == EVENT_ENEMY_SPLIT:
			_on_enemy_split(event)
			continue
		if type == EVENT_AURA_APPLIED:
			_on_aura_applied(event)
			continue

		match type:
			Types.Event.ENEMY_SPAWNED:
				_add_enemy_view(event)
			Types.Event.ENEMY_DAMAGED:
				var hit = _enemy_views.get(int(event["enemy_id"]), null)
				if hit != null:
					hit.flash()
				if damage_numbers != null:
					# Lifted to roughly the top of the body, not the feet, so the
					# number does not spawn inside the model it belongs to.
					damage_numbers.show_hit(
						_at_enemy(hit, event["position"]) + Vector3(0.0, 1.1, 0.0),
						int(event.get("amount", 0)), int(event.get("max_hp", 0)))
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


## A tower changed tier. Rebuilds its body from the new def in place, and
## refreshes the cached def so effect colours follow the new tier.
##
## Speculative until the sim emits it: written against the contract
##   {"type": TOWER_UPGRADED, "tower_id": int, "def_id": String, "tier": int}
## `tier` is deliberately unused here - the def carries everything the view
## needs, and reading a field for the sake of it would invent a second source of
## truth for what a tier looks like.
func _on_tower_upgraded(event: Dictionary) -> void:
	var tower_id: int = int(event.get("tower_id", 0))
	var view = _tower_views.get(tower_id, null)
	var def = catalog.get_tower(str(event.get("def_id", "")))
	if view == null or def == null:
		# An upgrade for a tower with no view, or to a def the catalog lacks.
		# Both are content errors rather than view errors; say so once instead of
		# every frame, and leave the old body standing so the board stays legible.
		push_warning("Level: TOWER_UPGRADED for tower %d -> '%s' could not be applied"
			% [tower_id, str(event.get("def_id", ""))])
		return

	_tower_defs[tower_id] = def
	view.rebuild(def)

	# A visible moment. Without one an upgrade is a silent mesh swap, and the
	# player has no confirmation that 140 credits did anything.
	var at: Vector3 = view.position
	effects.spawn_burst(at + Vector3(0.0, 1.3, 0.0), def.accent_color, 1.1)
	effects.spawn_ring(at, def.effect_color, 2.1)


## A Mender pulse. docs/design/enemies.md is explicit that without something
## visible the healed enemy's bar jumping backwards reads as a bug rather than as
## an enemy ability, so this is a ring and a number, not just a number.
##
## Speculative until the sim emits it. Contract:
##   {"type": ENEMY_HEALED, "enemy_id": int, "amount": int, "hp": int}
func _on_enemy_healed(event: Dictionary) -> void:
	var view = _enemy_views.get(int(event.get("enemy_id", 0)), null)
	if view == null:
		return
	var at: Vector3 = view.position
	effects.spawn_ring(at, COLOR_HEAL, 1.25)
	effects.spawn_burst(at + Vector3(0.0, 0.5, 0.0), COLOR_HEAL, 0.45)
	if damage_numbers != null:
		damage_numbers.show_heal(at + Vector3(0.0, 1.1, 0.0), int(event.get("amount", 0)))


## A Fission Crawler coming apart. The children arrive as their own
## ENEMY_SPAWNED events and get views the normal way; all this adds is the
## moment of the split, so the two new bodies are not simply there.
##
## Contract:
##   {"type": ENEMY_SPLIT, "enemy_id": int, "spawned": PackedInt32Array}
func _on_enemy_split(event: Dictionary) -> void:
	var view = _enemy_views.get(int(event.get("enemy_id", 0)), null)
	if view == null:
		return
	var def = _enemy_defs.get(int(event.get("enemy_id", 0)), null)
	var color: Color = def.body_color if def != null else Color(0.9, 0.7, 0.4)
	effects.spawn_burst(view.position + Vector3(0.0, 0.5, 0.0), color, 0.9)
	effects.spawn_ring(view.position, color, 1.6)


## A Warden's aura reaching an enemy. Draws a persistent radius on the SOURCE,
## because "shoot the shepherd" is a lesson the game can only teach if the
## shepherd is the thing marked - marking the buffed enemy points at the symptom.
##
## Contract:
##   {"type": AURA_APPLIED, "enemy_id": int, "source_id": int}
func _on_aura_applied(event: Dictionary) -> void:
	var source_id: int = int(event.get("source_id", 0))
	var source = _enemy_views.get(source_id, null)
	if source == null:
		return

	var ring = _aura_rings.get(source_id, null)
	if ring == null:
		ring = RangeRingScript.new()
		ring.name = "Aura%d" % source_id
		ring.set_tint(COLOR_AURA)
		ring.set_intensity(0.75)
		add_child(ring)
		_aura_rings[source_id] = ring
	ring.show_at(source.position, _aura_radius(source_id))
	_aura_life[source_id] = AURA_TTL

	# And a flicker on the enemy that just got covered, so the link between the
	# ring and the effect is visible rather than inferred.
	var covered = _enemy_views.get(int(event.get("enemy_id", 0)), null)
	if covered != null and covered != source:
		effects.spawn_burst(covered.position + Vector3(0.0, 0.9, 0.0), COLOR_AURA, 0.3)


## Radius of an aura, from the source's own def when the enemy schema carries
## one. Probed by name because it does not exist yet - the same reason the event
## ids above are resolved rather than written down.
func _aura_radius(source_id: int) -> float:
	var def = _enemy_defs.get(source_id, null)
	if def != null:
		for field in ["aura_radius", "ability_radius", "effect_radius"]:
			if field in def:
				var value: float = float(def.get(field))
				if value > 0.0:
					return value
	return AURA_FALLBACK_RADIUS


## Fades aura rings whose source has stopped emitting - a Warden that died, or
## one whose pulse simply ended. Called once per frame from sync().
func _step_auras(delta: float) -> void:
	if _aura_rings.is_empty():
		return
	for source_id in _aura_rings.keys():
		var left: float = float(_aura_life.get(source_id, 0.0)) - delta
		var ring = _aura_rings[source_id]
		var source = _enemy_views.get(source_id, null)
		if left <= 0.0 or source == null or not is_instance_valid(ring):
			if is_instance_valid(ring):
				ring.queue_free()
			_aura_rings.erase(source_id)
			_aura_life.erase(source_id)
			continue
		_aura_life[source_id] = left
		# Follows its source rather than sitting where the pulse landed.
		ring.show_at(source.position, _aura_radius(source_id))
		ring.set_intensity(0.75 * clampf(left / AURA_TTL, 0.0, 1.0))


func _on_enemy_killed(event: Dictionary) -> void:
	var enemy_id := int(event["enemy_id"])
	var def = _enemy_defs.get(enemy_id, null)
	var color: Color = def.body_color if def != null else Color(1.0, 0.75, 0.35)
	# Bigger enemies die harder. Scaled off the def's radius so a Brute's death
	# carries weight a Drone's does not.
	var scale: float = 1.0 if def == null else clampf(def.radius / 0.45, 0.7, 2.0)
	var position: Vector3 = _at_enemy(_enemy_views.get(enemy_id, null), event["position"])

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


## Where an effect belonging to a specific enemy should appear.
##
## The same drop as _on_ground for anything that walks, but a flier is not on the
## ground: its view sits at its cruise altitude, and a death explosion or a
## damage number pinned to y=0 would appear on the terrain underneath a Skiff
## rather than at it. Asking the view means this is right for both without the
## caller having to know which it is dealing with.
static func _at_enemy(view, position: Vector3) -> Vector3:
	var lift: float = BoardScript.PATH_TOP
	if view != null and is_instance_valid(view):
		lift = view.vertical_offset()
	return Vector3(position.x, position.y + lift, position.z)


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
	if audio != null:
		audio.step(delta)
	if damage_numbers != null:
		damage_numbers.step(delta)
	_step_auras(delta)
	_update_ghost()


## Feedback for input the simulation refused, which by definition emits no
## event. game/main.gd routes rejected builds and sells here.
func play_denied() -> void:
	if audio != null:
		audio.play_denied()


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


## All four pieces of placement feedback, refreshed every frame: the hovered
## cell, the ghost tower, the ghost's range, and whatever is selected.
##
## Everything here is derived - none of it is remembered between frames except
## `_selected_cell`, which is the one genuine piece of state. That is deliberate:
## a hover highlight that can get out of step with the mouse is worse than none.
func _update_ghost() -> void:
	_hover_cell = cell_under_mouse()
	var in_bounds: bool = sim.grid.in_bounds(_hover_cell)
	var world: Vector3 = sim.grid.cell_to_world(_hover_cell) if in_bounds else Vector3.ZERO
	var hovered_tower = sim.tower_at(_hover_cell) if in_bounds else null

	_update_hover_marker(in_bounds, world, hovered_tower)
	_update_ghost_tower(in_bounds, world)
	_update_selection(hovered_tower)


func _update_hover_marker(in_bounds: bool, world: Vector3, hovered_tower) -> void:
	if not in_bounds:
		_hover_marker.visible = false
		return

	var color: Color = COLOR_NEUTRAL
	var pulsing: bool = false
	if _selected_tower_id != "":
		# Armed to build: the marker answers "will this click work?", which is
		# the question the translucent box alone was answering too quietly.
		var allowed: bool = sim.build_blocked_reason(_hover_cell, _selected_tower_id) == ""
		color = COLOR_VALID if allowed else COLOR_INVALID
		pulsing = not allowed
	elif _sell_mode:
		color = COLOR_INVALID if hovered_tower != null else COLOR_NEUTRAL
	elif hovered_tower != null:
		color = COLOR_TOWER
	_hover_marker.show_at(world, sim.grid.cell_size, color, pulsing)


func _update_ghost_tower(in_bounds: bool, world: Vector3) -> void:
	var showing: bool = _selected_tower_id != "" and in_bounds
	_ghost.visible = showing
	if not showing:
		_ghost_range.visible = false
		return

	_ghost.position = Vector3(world.x, 0.45, world.z)

	var def = catalog.get_tower(_selected_tower_id)
	var radius: float = def.range_world if def != null else 1.0
	var allowed: bool = sim.build_blocked_reason(_hover_cell, _selected_tower_id) == ""

	_ghost_range.set_tint(COLOR_VALID if allowed else COLOR_INVALID)
	_ghost_range.set_invalid(not allowed)
	_ghost_range.set_intensity(1.0)
	_ghost_range.show_at(world, radius)

	_ghost_material.albedo_color = Color(COLOR_VALID, 0.32) if allowed else Color(COLOR_INVALID, 0.32)


## Shows the range of the selected tower, or - when nothing is selected and the
## player is only pointing - a dimmer preview of the hovered tower's range. The
## dim version is what makes coverage explorable without committing to a click.
func _update_selection(hovered_tower) -> void:
	var target = null
	var intensity: float = 1.0

	if sim.grid.in_bounds(_selected_cell):
		target = sim.tower_at(_selected_cell)
		if target == null:
			# Sold out from under the selection.
			_selected_cell = Vector2i(-1, -1)
	if target == null and _selected_tower_id == "" and hovered_tower != null:
		target = hovered_tower
		intensity = 0.5

	if target == null:
		_selection_range.visible = false
		_selection_marker.visible = false
		return

	_selection_range.set_intensity(intensity)
	_selection_range.show_at(target.position, target.range_world)
	if intensity < 1.0:
		# A hover preview gets the ring but not the bracket, or it fights the
		# hover marker already sitting on the same cell.
		_selection_marker.visible = false
	else:
		_selection_marker.show_at(target.position, sim.grid.cell_size, COLOR_TOWER)


## Clears any tower selection. game/main.gd calls this on Escape, alongside the
## ghost and sell-mode resets, so one key clears every mode.
func clear_selection() -> void:
	_selected_cell = Vector2i(-1, -1)


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
	else:
		# Neither building nor selling, so a click is an inspection. Clicking
		# empty ground clears, which is the behaviour every RTS trains for.
		_selected_cell = cell if sim.tower_at(cell) != null else Vector2i(-1, -1)
		if sim.grid.in_bounds(_selected_cell):
			tower_inspected.emit(_selected_cell)
