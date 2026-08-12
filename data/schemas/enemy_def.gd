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

@export_group("Ability")
## One ability per enemy, selected by enum rather than by subclass. Adding the
## fifth ability must stay a matter of a new enum value plus a branch in
## Simulation - never a new EnemyDef subclass. See ROADMAP 2.6.
## The four parameter fields below are read according to `ability`; an ability
## that does not use one leaves it at its default.
@export_enum("None", "Aura", "HealPulse", "SplitOnDeath") var ability: int = 0
## AURA: protection radius. HEAL_PULSE: heal radius. World units.
@export var ability_radius: float = 0.0
## AURA: percent of computed damage a protected ally takes (60 = a 40% reduction).
@export_range(0, 100, 1) var ability_percent: int = 100
## HEAL_PULSE: hit points restored per pulse, at the 10x scale.
@export var ability_amount: int = 0
## HEAL_PULSE: ticks between pulses. Each instance is anchored on its own spawn
## tick, never on a global clock - see Simulation._step_abilities.
@export var ability_interval: int = 0
## SPLIT_ON_DEATH: enemy ids spawned at this enemy's exact path progress when it
## dies. These ids are referenced by ability rather than by any spawn group, so
## Catalog.validate() resolves them from here.
@export var spawn_on_death: PackedStringArray = PackedStringArray()

## Ignores the path entirely: flies a straight line from spawn to goal at
## SimTypes.AIR_CRUISE_HEIGHT. Only towers with can_target_air may shoot it.
@export var flies: bool = false

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
	# Each ability declares which parameters it actually needs. A radius of zero
	# on an aura is not a subtle balance choice, it is a typo that silently
	# disables the enemy's whole reason to exist.
	match ability:
		1:  # AURA
			if ability_radius <= 0.0:
				return "enemy '%s' has AURA with no radius" % id
			if ability_percent < 0 or ability_percent > 100:
				return "enemy '%s' has AURA percent outside 0-100" % id
		2:  # HEAL_PULSE
			if ability_radius <= 0.0:
				return "enemy '%s' has HEAL_PULSE with no radius" % id
			if ability_interval < 1:
				return "enemy '%s' has HEAL_PULSE with interval < 1" % id
			if ability_amount < 1:
				return "enemy '%s' has HEAL_PULSE with amount < 1" % id
		3:  # SPLIT_ON_DEATH
			if spawn_on_death.is_empty():
				return "enemy '%s' has SPLIT_ON_DEATH but spawns nothing" % id
	return ""
