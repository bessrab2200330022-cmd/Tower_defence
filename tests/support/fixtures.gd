extends RefCounted
## Hand-built test content. Numbers here are chosen to be easy to reason about:
## a 10x3 board, a 10-cell straight path, and round HP/damage values.

const TowerDefScript := preload("res://data/schemas/tower_def.gd")
const EnemyDefScript := preload("res://data/schemas/enemy_def.gd")
const WaveDefScript := preload("res://data/schemas/wave_def.gd")
const SpawnGroupScript := preload("res://data/schemas/spawn_group.gd")
const MapDefScript := preload("res://data/schemas/map_def.gd")
const FakeCatalogScript := preload("res://tests/support/fake_catalog.gd")
const EnemyStateScript := preload("res://sim/entities/enemy_state.gd")
const TowerStateScript := preload("res://sim/entities/tower_state.gd")

## Row 0 is the path: 10 cells, so 9 steps == 18 world units at cell_size 2.0.
const STRAIGHT_LAYOUT := "S########G\n..........\n.........."
const BLOCKED_LAYOUT := "S...#....G\n..........\n.........."


static func make_tower(overrides: Dictionary = {}):
	var def = TowerDefScript.new()
	def.id = "test_tower"
	def.display_name = "Test Tower"
	def.cost = 100
	def.sell_refund_percent = 70
	def.range_world = 6.0
	def.damage = 20
	def.damage_type = 0
	def.fire_interval_ticks = 30
	def.fire_mode = 0
	def.projectile_speed = 30.0
	def.splash_radius = 0.0
	def.slow_percent = 0
	def.slow_ticks = 0
	def.target_mode = 0
	for key in overrides:
		def.set(key, overrides[key])
	return def


static func make_enemy(overrides: Dictionary = {}):
	var def = EnemyDefScript.new()
	def.id = "test_enemy"
	def.display_name = "Test Enemy"
	def.max_hp = 100
	def.speed = 6.0
	def.armor_type = 1
	def.bounty = 10
	def.leak_damage = 1
	for key in overrides:
		def.set(key, overrides[key])
	return def


static func make_group(enemy_id: String, count: int, start_delay_ticks: int = 0, interval_ticks: int = 30):
	var group = SpawnGroupScript.new()
	group.enemy_id = enemy_id
	group.count = count
	group.start_delay_ticks = start_delay_ticks
	group.interval_ticks = interval_ticks
	return group


static func make_wave(id: String, groups: Array):
	var wave = WaveDefScript.new()
	wave.id = id
	wave.display_name = id
	wave.groups = groups
	return wave


static func make_map(overrides: Dictionary = {}):
	var def = MapDefScript.new()
	def.id = "test_map"
	def.display_name = "Test Map"
	def.layout_path = ""
	def.layout_inline = STRAIGHT_LAYOUT
	def.cell_size = 2.0
	def.starting_credits = 500
	def.starting_lives = 10
	def.wave_ids = PackedStringArray(["test_wave"])
	for key in overrides:
		def.set(key, overrides[key])
	return def


## A catalog with one tower, one enemy, one wave and the straight map.
static func make_catalog(tower_overrides: Dictionary = {}, enemy_overrides: Dictionary = {},
		groups: Array = [], map_overrides: Dictionary = {}):
	var catalog = FakeCatalogScript.new()
	var tower = make_tower(tower_overrides)
	var enemy = make_enemy(enemy_overrides)
	catalog.towers[tower.id] = tower
	catalog.enemies[enemy.id] = enemy

	var wave_groups: Array = groups
	if wave_groups.is_empty():
		wave_groups = [make_group(enemy.id, 1, 0, 30)]
	var wave = make_wave("test_wave", wave_groups)
	catalog.waves[wave.id] = wave

	var map_def = make_map(map_overrides)
	catalog.maps[map_def.id] = map_def
	return catalog


## Bare enemy state for targeting tests, no simulation required.
static func make_enemy_state(id: int, position: Vector3, hp: int = 100, travelled: float = 0.0):
	var enemy = EnemyStateScript.new()
	enemy.id = id
	enemy.def_id = "test_enemy"
	enemy.max_hp = maxi(hp, 1)
	enemy.hp = hp
	enemy.position = position
	enemy.distance_travelled = travelled
	enemy.alive = true
	return enemy


static func make_tower_state(position: Vector3, range_world: float, target_mode: int):
	var tower = TowerStateScript.new()
	tower.id = 1
	tower.def_id = "test_tower"
	tower.position = position
	tower.range_world = range_world
	tower.target_mode = target_mode
	return tower
