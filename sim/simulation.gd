class_name Simulation
extends RefCounted
## The whole game, minus pixels.
##
## Rules for this file (and everything under `sim/`):
##   * No Node, no SceneTree, no `delta` from the engine, no Input, no rendering.
##   * Exactly one entry point advances time: `step()`. One call == one tick.
##   * The view layer reads `drain_events()`; it never mutates state directly.
##   * All randomness goes through `rng`. Never call randi()/randf() here.
##
## That is what makes `snapshot_hash()` reproducible, which is what makes bugs
## reproducible, which is the whole reason the layer exists.

const Types := preload("res://sim/sim_types.gd")
const GridScript := preload("res://sim/grid.gd")
const PathFinderScript := preload("res://sim/path_finder.gd")
const RngScript := preload("res://sim/rng.gd")
const EconomyScript := preload("res://sim/economy.gd")
const DamageScript := preload("res://sim/damage.gd")
const TargetingScript := preload("res://sim/targeting.gd")
const WaveDirectorScript := preload("res://sim/wave_director.gd")
const EnemyScript := preload("res://sim/entities/enemy_state.gd")
const TowerScript := preload("res://sim/entities/tower_state.gd")
const ProjectileScript := preload("res://sim/entities/projectile_state.gd")

## Command names accepted by `apply_command`. These are the on-disk vocabulary of
## a saved command log, so renaming one invalidates every save and replay - treat
## them as a format, not as internal identifiers.
const COMMAND_BUILD := "build"
const COMMAND_SELL := "sell"
const COMMAND_START_WAVE := "start_wave"
const COMMAND_SET_TARGET_MODE := "set_target_mode"
const COMMAND_UPGRADE := "upgrade"

var tick: int = 0
var phase: int = Types.Phase.BUILD
var setup_error: String = ""
## Spawns the director released that never became an enemy. Always 0 for valid
## content; non-zero means a wave references an enemy id the catalog lacks.
var dropped_spawns: int = 0

var grid
var path_finder
var rng
var economy
var wave_director
var catalog
var map_def

var enemies: Array = []
var towers: Array = []
var projectiles: Array = []
var waypoints: Array[Vector3] = []
## The flier lane: a straight spawn-to-goal chord at SimTypes.AIR_CRUISE_HEIGHT.
## Two points, so a flier's path_index bookkeeping is the same code as a walker's.
var air_waypoints: Array[Vector3] = []

var events: Array[Dictionary] = []

var _next_enemy_id: int = 1
var _next_tower_id: int = 1
var _next_projectile_id: int = 1
var _enemy_by_id: Dictionary = {}
var _tower_by_cell: Dictionary = {}


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Returns true on success. On failure, read `setup_error`.
func setup(map_resource, catalog_ref, seed_value: int = 1) -> bool:
	setup_error = ""
	map_def = map_resource
	catalog = catalog_ref

	if map_def == null:
		setup_error = "map_def is null"
		return false
	if catalog == null:
		setup_error = "catalog is null"
		return false

	grid = GridScript.new()
	var layout_error: String = grid.load_from_layout(map_def.get_layout(), map_def.cell_size)
	if layout_error != "":
		setup_error = "map '%s': %s" % [map_def.id, layout_error]
		return false

	path_finder = PathFinderScript.new()
	if not path_finder.build(grid, grid.spawn, grid.goal):
		setup_error = "map '%s': %s" % [map_def.id, path_finder.last_error]
		return false

	waypoints = []
	for cell in path_finder.path:
		waypoints.append(grid.cell_to_world(cell))

	# Fliers ignore the route entirely. On The Crossing this chord is ~40 units
	# against the walkers' 122, which is why enemies.md insists fliers are
	# measured as their own column - the same HP is on the board for a third of
	# the time.
	var lift := Vector3(0.0, Types.AIR_CRUISE_HEIGHT, 0.0)
	air_waypoints = [grid.cell_to_world(grid.spawn) + lift, grid.cell_to_world(grid.goal) + lift]

	rng = RngScript.new(seed_value)
	economy = EconomyScript.new(map_def.starting_credits, map_def.starting_lives)

	var wave_list: Array = []
	for wave_id in map_def.wave_ids:
		var wave = catalog.get_wave(str(wave_id))
		if wave == null:
			setup_error = "map '%s' references unknown wave '%s'" % [map_def.id, str(wave_id)]
			return false
		wave_list.append(wave)
	if wave_list.is_empty():
		setup_error = "map '%s' has no waves" % map_def.id
		return false
	wave_director = WaveDirectorScript.new(wave_list)

	tick = 0
	phase = Types.Phase.BUILD
	dropped_spawns = 0
	enemies = []
	towers = []
	projectiles = []
	events = []
	_next_enemy_id = 1
	_next_tower_id = 1
	_next_projectile_id = 1
	_enemy_by_id = {}
	_tower_by_cell = {}
	return true


# ---------------------------------------------------------------------------
# Player commands
# ---------------------------------------------------------------------------

func is_over() -> bool:
	return phase == Types.Phase.WON or phase == Types.Phase.LOST


## Reasons a build would fail, as a message. Empty string means "allowed".
func build_blocked_reason(cell: Vector2i, tower_id: String) -> String:
	if is_over():
		return "the match is over"
	var def = catalog.get_tower(tower_id)
	if def == null:
		return "unknown tower '%s'" % tower_id
	if not grid.is_buildable(cell):
		return "cannot build there"
	if _tower_by_cell.has(cell):
		return "cell already occupied"
	if not economy.can_afford(def.cost):
		return "not enough credits"
	return ""


## The single door into the simulation for player intent.
##
## Every command - from live input, from a replayed log, later from a tower
## active - travels this one path, which is what lets a save be `seed + map id +
## an ordered command log` and a load be replaying it. The four `try_*` methods
## below are thin wrappers, kept because they are a nicer call site and because
## `game/` and the whole test suite already use them.
##
## Routing only: validation stays in the `_do_*` implementations where it always
## was. Returns false for an unknown action or malformed args rather than
## failing hard - a corrupt replay must not be able to crash the sim, and
## neither must a typo in a UI call site.
func apply_command(action: String, args: Dictionary = {}) -> bool:
	match action:
		COMMAND_BUILD:
			if not _arg_is_cell(args, "cell") or not _arg_is_text(args, "tower_id"):
				return false
			return _do_build(args["cell"], str(args["tower_id"]))
		COMMAND_SELL:
			if not _arg_is_cell(args, "cell"):
				return false
			return _do_sell(args["cell"])
		COMMAND_START_WAVE:
			return _do_start_next_wave()
		COMMAND_SET_TARGET_MODE:
			if not _arg_is_cell(args, "cell") or not _arg_is_int(args, "mode"):
				return false
			return _do_set_target_mode(args["cell"], args["mode"])
		COMMAND_UPGRADE:
			# Addressed by tower id rather than cell, unlike build and sell. That
			# is the lead's contract; A4's panel already has the tower selected
			# when the button is pressed, so it has the id and not the cell.
			if not _arg_is_int(args, "tower_id") or not _arg_is_text(args, "def_id"):
				return false
			return _do_upgrade(args["tower_id"], str(args["def_id"]))
	return false


# Arg checks are by exact type rather than by duck-typing. A replay that carries
# a float where a cell belongs is corrupt, and silently coercing it would
# reproduce the wrong match rather than refusing to reproduce anything.

static func _arg_is_cell(args: Dictionary, key: String) -> bool:
	return args.has(key) and typeof(args[key]) == TYPE_VECTOR2I


static func _arg_is_int(args: Dictionary, key: String) -> bool:
	return args.has(key) and typeof(args[key]) == TYPE_INT


## StringName is accepted alongside String because `.tres` ids arrive as either.
static func _arg_is_text(args: Dictionary, key: String) -> bool:
	if not args.has(key):
		return false
	var kind: int = typeof(args[key])
	return kind == TYPE_STRING or kind == TYPE_STRING_NAME


func try_build(cell: Vector2i, tower_id: String) -> bool:
	return apply_command(COMMAND_BUILD, {"cell": cell, "tower_id": tower_id})


func try_sell(cell: Vector2i) -> bool:
	return apply_command(COMMAND_SELL, {"cell": cell})


## Begins the next wave. No-op if a wave is already running or none are left.
func start_next_wave() -> bool:
	return apply_command(COMMAND_START_WAVE)


func set_target_mode(cell: Vector2i, mode: int) -> bool:
	return apply_command(COMMAND_SET_TARGET_MODE, {"cell": cell, "mode": mode})


func try_upgrade(tower_id: int, def_id: String) -> bool:
	return apply_command(COMMAND_UPGRADE, {"tower_id": tower_id, "def_id": def_id})


## Why an upgrade would be refused, as a message. Empty string means "allowed".
## Mirrors build_blocked_reason so the UI can grey a button with a reason
## attached rather than discovering the refusal by pressing it.
func upgrade_blocked_reason(tower_id: int, def_id: String) -> String:
	if is_over():
		return "the match is over"
	var tower = _tower_by_id(tower_id)
	if tower == null:
		return "no tower with id %d" % tower_id
	var current = catalog.get_tower(tower.def_id)
	if current == null:
		return "tower %d has unknown def '%s'" % [tower_id, tower.def_id]
	if not current.upgrade_ids.has(def_id):
		# Deliberately strict: only a tier the CURRENT def offers. That is what
		# stops a replayed or hand-written command jumping the ladder straight
		# to a tier 3 for one increment.
		return "'%s' is not an upgrade of '%s'" % [def_id, tower.def_id]
	var next_def = catalog.get_tower(def_id)
	if next_def == null:
		return "unknown tower '%s'" % def_id
	if not economy.can_afford(next_def.cost):
		return "not enough credits"
	return ""


func _do_upgrade(tower_id: int, def_id: String) -> bool:
	if upgrade_blocked_reason(tower_id, def_id) != "":
		return false
	var tower = _tower_by_id(tower_id)
	var next_def = catalog.get_tower(def_id)
	if not economy.spend(next_def.cost):
		return false

	# Bought in place: id, cell, position, facing and the tower's record of what
	# it has done all survive. Only the stats change, because an upgraded tower
	# simply *is* its new def.
	tower.credits_invested += next_def.cost
	_apply_def_to_tower(tower, next_def)

	_emit(Types.Event.TOWER_UPGRADED, {
		"tower_id": tower.id,
		"def_id": tower.def_id,
		"tier": int(next_def.tier),
	})
	_emit(Types.Event.CREDITS_CHANGED, {"credits": economy.credits})
	return true


## The single place a TowerDef's stats are copied onto a TowerState, shared by
## build and upgrade so a field added to one can never be forgotten by the other.
func _apply_def_to_tower(tower, def) -> void:
	tower.def_id = str(def.id)
	tower.range_world = def.range_world
	tower.damage = def.damage
	tower.damage_type = def.damage_type
	tower.fire_interval_ticks = maxi(def.fire_interval_ticks, 1)
	tower.fire_mode = def.fire_mode
	tower.projectile_speed = def.projectile_speed
	tower.splash_radius = def.splash_radius
	tower.slow_percent = def.slow_percent
	tower.slow_ticks = def.slow_ticks
	tower.target_mode = def.target_mode
	tower.can_target_air = def.can_target_air
	# A cooldown already ticking was measured against the OLD interval. Clamping
	# stops an upgrade to a faster gun from being a temporary downgrade, without
	# handing out a free instant shot the way resetting to zero would.
	tower.cooldown_ticks = mini(tower.cooldown_ticks, tower.fire_interval_ticks)


func _do_build(cell: Vector2i, tower_id: String) -> bool:
	if build_blocked_reason(cell, tower_id) != "":
		return false
	var def = catalog.get_tower(tower_id)
	if not economy.spend(def.cost):
		return false

	var tower = TowerScript.new()
	tower.id = _next_tower_id
	_next_tower_id += 1
	tower.cell = cell
	tower.position = grid.cell_to_world(cell)
	tower.credits_invested = def.cost
	_apply_def_to_tower(tower, def)

	towers.append(tower)
	_tower_by_cell[cell] = tower
	_emit(Types.Event.TOWER_BUILT, {"tower_id": tower.id, "def_id": tower.def_id, "cell": cell, "position": tower.position})
	_emit(Types.Event.CREDITS_CHANGED, {"credits": economy.credits})
	return true


func _do_sell(cell: Vector2i) -> bool:
	if is_over() or not _tower_by_cell.has(cell):
		return false
	var tower = _tower_by_cell[cell]
	var def = catalog.get_tower(tower.def_id)
	var refund: int = 0
	if def != null:
		refund = EconomyScript.refund_for(tower.credits_invested, def.sell_refund_percent)
	economy.earn(refund)

	_tower_by_cell.erase(cell)
	towers.erase(tower)
	_emit(Types.Event.TOWER_SOLD, {"tower_id": tower.id, "cell": cell, "refund": refund})
	_emit(Types.Event.CREDITS_CHANGED, {"credits": economy.credits})
	return true


func tower_at(cell: Vector2i):
	return _tower_by_cell.get(cell, null)


## Rejects modes outside TargetMode. Targeting falls back to FIRST for anything
## it does not recognise, so an out-of-range value would otherwise be accepted
## here and then silently ignored every tick.
func _do_set_target_mode(cell: Vector2i, mode: int) -> bool:
	if is_over():
		return false
	if mode < 0 or mode >= Types.TargetMode.size():
		return false
	var tower = tower_at(cell)
	if tower == null:
		return false
	tower.target_mode = mode
	return true


func _do_start_next_wave() -> bool:
	if phase != Types.Phase.BUILD:
		return false
	if not wave_director.start_next(tick):
		return false
	phase = Types.Phase.COMBAT
	var wave = wave_director.current_wave()
	_emit(Types.Event.WAVE_STARTED, {
		"wave_index": wave_director.wave_index,
		"wave_id": str(wave.id) if wave != null else "",
		"total_waves": wave_director.wave_count(),
		"enemy_count": wave_director.total_enemies_in_wave(),
	})
	return true


# ---------------------------------------------------------------------------
# The tick
# ---------------------------------------------------------------------------

func step() -> void:
	if is_over():
		return
	tick += 1
	var delta: float = Types.TICK_DELTA

	if phase == Types.Phase.COMBAT:
		_spawn_due_enemies()

	_step_enemies(delta)
	# Auras are resolved before anything fires, so every shot this tick sees the
	# same membership. Resolving lazily at damage time would make the answer
	# depend on tower iteration order.
	_recompute_auras()
	_step_abilities()
	_step_towers(delta)
	_step_projectiles(delta)
	_compact_entities()
	_resolve_phase()


func _spawn_due_enemies() -> void:
	for enemy_id in wave_director.step(tick):
		_spawn_enemy(enemy_id)


func _spawn_enemy(def_id: String) -> void:
	var def = catalog.get_enemy(def_id)
	if def == null or waypoints.is_empty():
		# The director has already counted this spawn, so the wave will still
		# "clear" - just short a few enemies, and paying the bonus for it.
		# Catalog.validate() is the real guard; this counter makes the damage
		# visible to a test instead of scrolling past in the engine log.
		dropped_spawns += 1
		return

	_create_enemy(def, 1, _route_for(def.flies)[0], 0.0)


## The flier lane or the walking route. One function so nothing downstream has
## to remember which array an enemy belongs to.
func _route_for(flies: bool) -> Array:
	return air_waypoints if flies else waypoints


## Total length of a lane, so FIRST/LAST targeting can compare a flier's chord
## against a walker's tour as fractions rather than as raw distances.
func _route_length(flies: bool) -> float:
	var route: Array = _route_for(flies)
	var total: float = 0.0
	for i in range(1, route.size()):
		total += route[i - 1].distance_to(route[i])
	return maxf(total, 0.001)


## Every enemy in the game is born here, whether it walked out of the spawn point
## or fell out of a Fission Crawler mid-path. Split children therefore inherit
## exactly the same movement bookkeeping - path_index, position and the
## distance_travelled that FIRST/LAST targeting reads - which is what enemies.md
## flags as the Crawler's real determinism risk.
func _create_enemy(def, path_index: int, position: Vector3, distance_travelled: float):
	var enemy = EnemyScript.new()
	enemy.id = _next_enemy_id
	_next_enemy_id += 1
	enemy.def_id = str(def.id)
	enemy.max_hp = maxi(def.max_hp, 1)
	enemy.hp = enemy.max_hp
	enemy.base_speed = def.speed
	enemy.armor_type = def.armor_type
	enemy.bounty = def.bounty
	enemy.leak_damage = maxi(def.leak_damage, 0)
	enemy.flies = def.flies
	enemy.ability = def.ability
	enemy.ability_radius = def.ability_radius
	enemy.ability_percent = def.ability_percent
	enemy.ability_amount = def.ability_amount
	enemy.ability_interval = maxi(def.ability_interval, 1)
	enemy.spawn_on_death = def.spawn_on_death
	# Anchored on THIS enemy's spawn tick, never on a global clock: two Menders
	# that arrive 40 ticks apart stay 40 ticks out of phase for their whole
	# lives. ROADMAP trap 2 is a schedule anchored on a tick nobody steps.
	enemy.ability_next_tick = tick + enemy.ability_interval
	enemy.position = position
	enemy.path_index = path_index
	enemy.distance_travelled = distance_travelled
	enemy.route_length = _route_length(def.flies)

	enemies.append(enemy)
	_enemy_by_id[enemy.id] = enemy
	_emit(Types.Event.ENEMY_SPAWNED, {
		"enemy_id": enemy.id,
		"def_id": enemy.def_id,
		"position": enemy.position,
		"max_hp": enemy.max_hp,
	})
	return enemy


func _step_enemies(delta: float) -> void:
	for enemy in enemies:
		if not enemy.alive or enemy.reached_goal:
			continue
		enemy.tick_status()
		var route: Array = _route_for(enemy.flies)
		var remaining: float = enemy.current_speed() * delta
		while remaining > 0.0 and enemy.path_index < route.size():
			var target: Vector3 = route[enemy.path_index]
			var to_target: Vector3 = target - enemy.position
			var distance: float = to_target.length()
			if distance <= remaining:
				enemy.position = target
				enemy.distance_travelled += distance
				remaining -= distance
				enemy.path_index += 1
			else:
				enemy.position += to_target / distance * remaining
				enemy.distance_travelled += remaining
				remaining = 0.0

		if enemy.path_index >= route.size():
			enemy.reached_goal = true
			var lost: int = economy.lose_lives(enemy.leak_damage)
			# def_id rides along because the enemy is compacted away this same
			# tick - without it a listener has to mirror every ENEMY_SPAWNED to
			# find out what just leaked.
			_emit(Types.Event.ENEMY_LEAKED, {
				"enemy_id": enemy.id,
				"def_id": enemy.def_id,
				"lives_lost": lost,
			})
			_emit(Types.Event.LIVES_CHANGED, {"lives": economy.lives})


## AURA and HEAL_PULSE, dispatched on the enum. A fifth ability is a new branch
## here plus a new value in SimTypes.Ability - never a subclass. ROADMAP 2.6.

## Membership is recomputed from scratch every tick, in fixed entity-array order,
## so it can never drift out of sync with who is alive and where they are.
func _recompute_auras() -> void:
	for enemy in enemies:
		enemy.aura_percent = 100

	for source in enemies:
		if source.ability != Types.Ability.AURA:
			continue
		if not source.alive or source.reached_goal:
			continue
		var radius_sq: float = source.ability_radius * source.ability_radius
		for target in enemies:
			if target == source or not target.alive or target.reached_goal:
				continue
			# Aura-bearers never protect each other, so a Warden pair cannot
			# become a mutual fortress.
			if target.ability == Types.Ability.AURA:
				continue
			var offset: Vector3 = target.position - source.position
			if offset.x * offset.x + offset.z * offset.z > radius_sq:
				continue
			# Non-stacking: overlapping auras apply once, strongest wins. Two
			# Wardens must not multiply to 36%.
			if target.aura_percent == 100 or source.ability_percent < target.aura_percent:
				target.aura_percent = source.ability_percent
				target.aura_source_id = source.id

	# Edge-triggered rather than level-triggered: emitting for every protected
	# enemy every tick would put hundreds of events a second on the queue for
	# state that rarely changes. Loss of protection is the same event with
	# source_id 0, since enemy ids start at 1 - flagged to A4.
	for enemy in enemies:
		if enemy.aura_percent == enemy.aura_reported_percent:
			continue
		enemy.aura_reported_percent = enemy.aura_percent
		if enemy.aura_percent == 100:
			enemy.aura_source_id = 0
		_emit(Types.Event.AURA_APPLIED, {
			"enemy_id": enemy.id,
			"source_id": enemy.aura_source_id,
		})


func _step_abilities() -> void:
	for source in enemies:
		if source.ability != Types.Ability.HEAL_PULSE:
			continue
		if not source.alive or source.reached_goal:
			continue
		if tick < source.ability_next_tick:
			continue
		# Advancing by the interval rather than rebasing on `tick` keeps the
		# cadence anchored on the spawn tick for the enemy's whole life.
		source.ability_next_tick += source.ability_interval
		_heal_pulse(source)


func _heal_pulse(source) -> void:
	var radius_sq: float = source.ability_radius * source.ability_radius
	for target in enemies:
		if target == source or not target.alive or target.reached_goal:
			continue
		# Never another healer: no mutual-tank loops, no immortal pairs.
		if target.ability == Types.Ability.HEAL_PULSE:
			continue
		var offset: Vector3 = target.position - source.position
		if offset.x * offset.x + offset.z * offset.z > radius_sq:
			continue
		var healed: int = target.heal(source.ability_amount)
		if healed <= 0:
			continue
		_emit(Types.Event.ENEMY_HEALED, {
			"enemy_id": target.id,
			"amount": healed,
			"hp": target.hp,
		})


## SPLIT_ON_DEATH. Children are born at the parent's exact path progress in the
## same tick its death is processed, with sequential ids in fixed order, through
## the same _create_enemy every other spawn uses.
func _split_on_death(parent) -> void:
	var spawned := PackedInt32Array()
	for child_id in parent.spawn_on_death:
		var def = catalog.get_enemy(str(child_id))
		if def == null:
			dropped_spawns += 1
			continue
		var child = _create_enemy(def, parent.path_index, parent.position, parent.distance_travelled)
		if child != null:
			spawned.append(child.id)
	if not spawned.is_empty():
		_emit(Types.Event.ENEMY_SPLIT, {"enemy_id": parent.id, "spawned": spawned})


func _step_towers(_delta: float) -> void:
	for tower in towers:
		tower.tick_cooldown()
		if not tower.is_ready():
			continue
		var target = TargetingScript.select(tower, enemies)
		if target == null:
			continue

		tower.facing = atan2(target.position.x - tower.position.x, target.position.z - tower.position.z)
		tower.start_cooldown()
		_emit(Types.Event.TOWER_FIRED, {
			"tower_id": tower.id,
			"target_id": target.id,
			"facing": tower.facing,
			"fire_mode": tower.fire_mode,
			"origin": tower.position,
			"target_position": target.position,
		})

		if tower.fire_mode == Types.FireMode.HITSCAN:
			_apply_payload(tower, target, target.position, tower.damage, tower.damage_type,
				tower.splash_radius, tower.slow_percent, tower.slow_ticks)
		else:
			_spawn_projectile(tower, target)


func _spawn_projectile(tower, target) -> void:
	var projectile = ProjectileScript.new()
	projectile.id = _next_projectile_id
	_next_projectile_id += 1
	projectile.owner_tower_id = tower.id
	projectile.target_enemy_id = target.id
	projectile.position = tower.position + Vector3(0.0, 1.0, 0.0)
	projectile.target_position = target.position
	projectile.speed = maxf(tower.projectile_speed, 1.0)
	projectile.damage = tower.damage
	projectile.damage_type = tower.damage_type
	projectile.splash_radius = tower.splash_radius
	projectile.slow_percent = tower.slow_percent
	projectile.slow_ticks = tower.slow_ticks
	projectiles.append(projectile)
	_emit(Types.Event.PROJECTILE_SPAWNED, {
		"projectile_id": projectile.id,
		"tower_id": tower.id,
		"position": projectile.position,
		"speed": projectile.speed,
	})


func _step_projectiles(delta: float) -> void:
	for projectile in projectiles:
		if not projectile.alive:
			continue
		projectile.ticks_left -= 1
		if projectile.ticks_left <= 0:
			projectile.alive = false
			# The view frees its node on this event. Without it the mesh is
			# orphaned: still parented, never updated, never released.
			_emit(Types.Event.PROJECTILE_EXPIRED, {
				"projectile_id": projectile.id,
				"position": projectile.position,
			})
			continue

		var destination: Vector3 = projectile.target_position
		var target = _enemy_by_id.get(projectile.target_enemy_id, null)
		if target != null and target.alive and not target.reached_goal:
			destination = target.position
		else:
			target = null

		if projectile.step_towards(destination, delta):
			projectile.alive = false
			_emit(Types.Event.PROJECTILE_HIT, {
				"projectile_id": projectile.id,
				"position": projectile.position,
				"splash_radius": projectile.splash_radius,
			})
			var owner = _tower_by_id(projectile.owner_tower_id)
			_apply_payload(owner, target, projectile.position, projectile.damage,
				projectile.damage_type, projectile.splash_radius,
				projectile.slow_percent, projectile.slow_ticks)


## Single place where damage lands, for both hitscan and projectile hits.
## `primary` may be null when a projectile's target died mid-flight; splash still applies.
##
## Armour and splash falloff are resolved here rather than in `_damage_enemy` so
## that a splash hit divides once (see DamageTable.compute_splash) instead of
## truncating twice on its way to the enemy.
func _apply_payload(source_tower, primary, impact: Vector3, damage: int, damage_type: int,
		splash_radius: float, slow_percent: int, slow_ticks: int) -> void:
	var reaches_air: bool = source_tower == null or source_tower.can_target_air
	if splash_radius > 0.0:
		for enemy in TargetingScript.in_radius(enemies, impact, splash_radius, reaches_air):
			var offset: Vector3 = enemy.position - impact
			var distance: float = sqrt(offset.x * offset.x + offset.z * offset.z)
			var falloff: int = DamageScript.splash_percent_at(distance, splash_radius)
			# Armour, falloff and aura fold into ONE division. Splitting them
			# truncates three times and hands out protection the Warden never
			# advertised - see DamageTable.compute_splash_with_aura.
			var final_damage: int = DamageScript.compute_splash_with_aura(
				damage, damage_type, enemy.armor_type, falloff, enemy.incoming_percent())
			_damage_enemy(source_tower, enemy, final_damage, slow_percent, slow_ticks)
	elif primary != null:
		_damage_enemy(source_tower, primary,
			DamageScript.compute_with_aura(damage, damage_type, primary.armor_type,
				primary.incoming_percent()),
			slow_percent, slow_ticks)


## `final_damage` has already been through the armour table. Callers resolve the
## matchup; this function only applies the result.
func _damage_enemy(source_tower, enemy, final_damage: int,
		slow_percent: int, slow_ticks: int) -> void:
	if enemy == null or not enemy.alive or enemy.reached_goal or final_damage <= 0:
		return
	var dealt: int = enemy.take_damage(final_damage)
	if slow_percent > 0 and slow_ticks > 0:
		enemy.apply_slow(slow_percent, slow_ticks)

	if source_tower != null:
		source_tower.damage_dealt += dealt
	_emit(Types.Event.ENEMY_DAMAGED, {
		"enemy_id": enemy.id,
		"amount": dealt,
		"hp": enemy.hp,
		"max_hp": enemy.max_hp,
		"position": enemy.position,
	})

	if not enemy.alive:
		economy.earn(enemy.bounty)
		if source_tower != null:
			source_tower.kills += 1
		_emit(Types.Event.ENEMY_KILLED, {
			"enemy_id": enemy.id,
			"def_id": enemy.def_id,
			"bounty": enemy.bounty,
			"position": enemy.position,
			"killer_tower_id": source_tower.id if source_tower != null else 0,
		})
		# Order is fixed by enemies.md: parent ENEMY_KILLED, then each child's
		# ENEMY_SPAWNED, then ENEMY_SPLIT naming ids the consumer has already seen.
		if not enemy.spawn_on_death.is_empty():
			_split_on_death(enemy)
		_emit(Types.Event.CREDITS_CHANGED, {"credits": economy.credits})


func _compact_entities() -> void:
	var live_enemies: Array = []
	for enemy in enemies:
		if enemy.alive and not enemy.reached_goal:
			live_enemies.append(enemy)
		else:
			_enemy_by_id.erase(enemy.id)
	enemies = live_enemies

	var live_projectiles: Array = []
	for projectile in projectiles:
		if projectile.alive:
			live_projectiles.append(projectile)
	projectiles = live_projectiles


## Nothing will advance again once the match ends, so a shot still in the air is
## stranded: its fuse never ticks down and the view never hears it land. Retire
## the lot explicitly rather than leaving meshes hanging over the results screen.
func _retire_projectiles() -> void:
	for projectile in projectiles:
		if not projectile.alive:
			continue
		projectile.alive = false
		_emit(Types.Event.PROJECTILE_EXPIRED, {
			"projectile_id": projectile.id,
			"position": projectile.position,
		})
	projectiles = []


func _resolve_phase() -> void:
	if economy.is_defeated():
		phase = Types.Phase.LOST
		_retire_projectiles()
		_emit(Types.Event.GAME_LOST, {"tick": tick, "wave_index": wave_director.wave_index})
		return

	if phase != Types.Phase.COMBAT:
		return
	if not wave_director.spawning_finished() or not enemies.is_empty():
		return

	var bonus: int = maxi(map_def.wave_clear_bonus, 0)
	economy.earn(bonus)
	_emit(Types.Event.WAVE_CLEARED, {"wave_index": wave_director.wave_index, "bonus": bonus})
	_emit(Types.Event.CREDITS_CHANGED, {"credits": economy.credits})

	if wave_director.has_next_wave():
		phase = Types.Phase.BUILD
	else:
		phase = Types.Phase.WON
		_retire_projectiles()
		_emit(Types.Event.GAME_WON, {"tick": tick, "lives_left": economy.lives})


# ---------------------------------------------------------------------------
# Events and introspection
# ---------------------------------------------------------------------------

func _emit(event_type: int, data: Dictionary) -> void:
	data["type"] = event_type
	data["tick"] = tick
	events.append(data)


## Hands the queue to the caller and clears it. Call once per rendered frame.
func drain_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = events
	events = []
	return out


func _tower_by_id(id: int):
	for tower in towers:
		if tower.id == id:
			return tower
	return null


## Cheap order-sensitive checksum of the whole simulation.
## Two runs with the same seed and the same commands must produce the same value
## at every tick. `tests/cases/test_determinism.gd` enforces exactly that.
func snapshot_hash() -> int:
	var h: int = 1469598103
	h = _mix(h, tick)
	h = _mix(h, phase)
	h = _mix(h, economy.credits)
	h = _mix(h, economy.lives)
	h = _mix(h, rng.get_state())
	h = _mix(h, wave_director.wave_index)
	h = _mix(h, enemies.size())
	h = _mix(h, projectiles.size())
	for enemy in enemies:
		h = _mix(h, enemy.id)
		h = _mix(h, enemy.hp)
		h = _mix(h, int(round(enemy.distance_travelled * 1000.0)))
		# Status must be hashed, not inferred. A slow only shows up in
		# distance_travelled a tick later and cancels out entirely if it expires
		# between samples, so without these two a status bug can travel a whole
		# match invisibly - and status effects are about to become a stack.
		h = _mix(h, enemy.slow_percent)
		h = _mix(h, enemy.slow_ticks_left)
		# Three of the four abilities mutate entity state outside the damage
		# path. Healed HP rides in enemy.hp above, and split offspring are real
		# enemies caught by this same loop - but aura membership and each
		# healer's private schedule would otherwise be invisible to a replay.
		h = _mix(h, enemy.aura_percent)
		h = _mix(h, enemy.ability_next_tick)
	for tower in towers:
		h = _mix(h, tower.id)
		h = _mix(h, tower.cooldown_ticks)
		h = _mix(h, tower.damage_dealt)
		# The tower's current tier IS its def id. Without this a replayed upgrade
		# diverges silently: the credits are spent identically, so the economy
		# matches, and only the damage numbers drift a few ticks later.
		h = _mix_text(h, tower.def_id)
	for projectile in projectiles:
		h = _mix(h, projectile.id)
		h = _mix(h, int(round(projectile.position.x * 1000.0)))
		h = _mix(h, int(round(projectile.position.z * 1000.0)))
	return h


static func _mix(h: int, value: int) -> int:
	var mixed: int = (h ^ value) & 0xFFFFFFFF
	return (mixed * 16777619) & 0xFFFFFFFF


## Folds a string byte by byte rather than calling String.hash(), whose
## algorithm is an engine implementation detail and not promised to be stable
## across Godot versions. Determinism here has to outlive an engine upgrade.
static func _mix_text(h: int, text: String) -> int:
	var mixed: int = h
	for byte in text.to_utf8_buffer():
		mixed = _mix(mixed, int(byte))
	return mixed
