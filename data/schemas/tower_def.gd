class_name TowerDef
extends Resource
## Balance data for one tower. Adding a tower means adding a .tres file here,
## not a new class. Only add a script if the behaviour is genuinely novel.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Cost")
@export var cost: int = 100
@export_range(0, 100, 1) var sell_refund_percent: int = 70

@export_group("Combat")
## Radius in world units. Cell size is 2.0, so 8.0 covers roughly 4 cells.
@export var range_world: float = 8.0
## Damage per shot, at the project's 10x integer scale - a turret that "hits for
## 9" is written as 90. The armour table divides by 100, so small numbers lose
## real damage to truncation. See sim/damage.gd. Keep new towers on this scale.
@export var damage: int = 100
@export_enum("Kinetic", "Energy", "Explosive") var damage_type: int = 0
## Ticks between shots at 60 Hz. 30 == twice a second.
@export var fire_interval_ticks: int = 30
@export_enum("Hitscan", "Projectile") var fire_mode: int = 0
@export var projectile_speed: float = 30.0
## Zero means single target. Above zero applies falloff damage in this radius.
@export var splash_radius: float = 0.0
@export_range(0, 90, 1) var slow_percent: int = 0
@export var slow_ticks: int = 0
@export_enum("First", "Last", "Closest", "Strongest", "Weakest") var target_mode: int = 0

@export_group("Presentation")
## Optional .glb built by art/towers/<id>.py. Leave empty to fall back to the
## generated primitives, which is what every tower did before the art pass and
## what any new tower does until someone models it. The mesh must expose nodes
## named Base, Turret and Barrel - see game/views/tower_view.gd.
@export_file("*.glb") var mesh_path: String = ""
## Uniform scale applied to the loaded mesh. Only needed when a model was built
## against different proportions than this def's body_height.
@export var mesh_scale: float = 1.0
## Optional .glb for this tower's projectile, built by art/projectiles/<id>.py.
## Only used when fire_mode is Projectile. Empty falls back to a glowing sphere.
@export_file("*.glb") var projectile_mesh_path: String = ""
## Drives the beam, muzzle flash and impact colours in game/views/effects.gd.
## Separate from accent_color so a tower can have warm plating and a cold beam.
@export var effect_color: Color = Color(0.7, 0.95, 1.0)
@export var body_color: Color = Color(0.35, 0.65, 0.95)
@export var accent_color: Color = Color(0.95, 0.85, 0.45)
## Used by the primitive fallback. A loaded mesh carries its own proportions.
@export var body_height: float = 1.6
@export var barrel_length: float = 1.2


## Headline DPS ignoring armour matchups. Used by the build menu.
func nominal_dps() -> float:
	return float(damage) * 60.0 / float(maxi(fire_interval_ticks, 1))


func is_valid() -> String:
	if id.strip_edges() == "":
		return "tower has an empty id"
	if cost < 0:
		return "tower '%s' has negative cost" % id
	if fire_interval_ticks < 1:
		return "tower '%s' has fire_interval_ticks < 1" % id
	if range_world <= 0.0:
		return "tower '%s' has non-positive range" % id
	return ""
