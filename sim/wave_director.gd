class_name WaveDirector
extends RefCounted
## Turns wave definitions into per-tick spawn requests.
##
## Spawn timing is derived from tick arithmetic rather than accumulated
## countdowns, so a wave spawns identically no matter what the frame rate is.

var waves: Array = []          ## Array[WaveDef], in play order.
var wave_index: int = -1       ## -1 before the first wave starts.
var active: bool = false

var _wave_start_tick: int = 0
var _spawned_counts: PackedInt32Array = PackedInt32Array()
var _group_totals: PackedInt32Array = PackedInt32Array()


func _init(wave_list: Array = []) -> void:
	waves = wave_list


func wave_count() -> int:
	return waves.size()


func has_next_wave() -> bool:
	return wave_index + 1 < waves.size()


func current_wave():
	if wave_index < 0 or wave_index >= waves.size():
		return null
	return waves[wave_index]


## Begins the next wave at `tick`. Returns false if there are no waves left.
func start_next(tick: int) -> bool:
	if not has_next_wave():
		return false
	wave_index += 1
	_wave_start_tick = tick
	active = true

	var wave = waves[wave_index]
	var group_count: int = wave.groups.size()
	_spawned_counts = PackedInt32Array()
	_spawned_counts.resize(group_count)
	_spawned_counts.fill(0)
	_group_totals = PackedInt32Array()
	_group_totals.resize(group_count)
	for i in group_count:
		_group_totals[i] = maxi(int(wave.groups[i].count), 0)
	return true


## Enemy def ids that should spawn on this tick, in stable group order.
func step(tick: int) -> Array[String]:
	var out: Array[String] = []
	if not active:
		return out
	var wave = current_wave()
	if wave == null:
		return out

	var elapsed: int = tick - _wave_start_tick
	for i in wave.groups.size():
		var group = wave.groups[i]
		var already: int = _spawned_counts[i]
		var total: int = _group_totals[i]
		if already >= total:
			continue
		# The schedule is anchored one tick after the wave starts, never on the
		# start tick itself. Nothing ever steps the director at elapsed 0 -
		# Simulation.step() advances `tick` before calling step() - so anchoring
		# at 0 releases the first enemy late while leaving the rest of the
		# schedule pinned to 0, making the first gap `interval - 1`.
		var since_start: int = elapsed - maxi(int(group.start_delay_ticks), 1)
		if since_start < 0:
			continue
		var interval: int = maxi(int(group.interval_ticks), 1)
		var should_have_spawned: int = mini(total, since_start / interval + 1)
		while already < should_have_spawned:
			out.append(str(group.enemy_id))
			already += 1
		_spawned_counts[i] = already

	if _all_groups_emptied():
		active = false
	return out


func _all_groups_emptied() -> bool:
	for i in _spawned_counts.size():
		if _spawned_counts[i] < _group_totals[i]:
			return false
	return true


## True once every enemy in the current wave has been released. The wave is only
## "cleared" when the Simulation also sees zero live enemies.
func spawning_finished() -> bool:
	return not active


func total_enemies_in_wave() -> int:
	var total: int = 0
	for t in _group_totals:
		total += t
	return total


func spawned_so_far() -> int:
	var total: int = 0
	for s in _spawned_counts:
		total += s
	return total
