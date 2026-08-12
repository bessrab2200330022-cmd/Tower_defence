class_name SpawnGroup
extends Resource
## One stream of identical enemies inside a wave. A wave is a list of these,
## which is how you get "8 drones, then 3 brutes arriving 4 seconds later".

@export var enemy_id: String = ""
@export var count: int = 1
## Ticks to wait after the wave starts before the first spawn. 60 == 1 second.
@export var start_delay_ticks: int = 0
## Ticks between spawns within this group.
@export var interval_ticks: int = 30


func duration_ticks() -> int:
	return start_delay_ticks + maxi(count - 1, 0) * maxi(interval_ticks, 1)


func is_valid() -> String:
	if enemy_id.strip_edges() == "":
		return "spawn group has an empty enemy_id"
	if count < 1:
		return "spawn group '%s' has count < 1" % enemy_id
	if interval_ticks < 1:
		return "spawn group '%s' has interval_ticks < 1" % enemy_id
	return ""
