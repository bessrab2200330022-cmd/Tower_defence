class_name EnemyDef
extends Resource
## Balance data for one enemy type.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Stats")
## Hit points, at the same 10x integer scale as TowerDef.damage. See sim/damage.gd.
@export var max_hp: int = 1000
## World units per second. The path is 122 units long on the first map.
@export var speed: float = 4.0
@export_enum("Light", "Medium", "Heavy", "Shielded") var armor_type: int = 0
@export var bounty: int = 10
## Lives removed if this enemy reaches the goal.
@export var leak_damage: int = 1

@export_group("Presentation")
## Optional .glb built by art/enemies/<id>.py. Empty falls back to a generated
## sphere, so a new enemy is playable the moment its .tres exists.
@export_file("*.glb") var mesh_path: String = ""
@export var mesh_scale: float = 1.0
## Name of a node inside the mesh to render as a translucent shell, if any.
## Used by the Shielded Scout: transparency is a render setting, so it belongs
## here rather than baked into the model.
@export var shell_node: String = ""
@export var body_color: Color = Color(0.85, 0.35, 0.35)
@export var radius: float = 0.45
@export var height: float = 1.0


func is_valid() -> String:
	if id.strip_edges() == "":
		return "enemy has an empty id"
	if max_hp < 1:
		return "enemy '%s' has max_hp < 1" % id
	if speed <= 0.0:
		return "enemy '%s' has non-positive speed" % id
	return ""
