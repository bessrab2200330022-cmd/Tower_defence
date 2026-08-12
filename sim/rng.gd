class_name DetRng
extends RefCounted
## Deterministic xorshift32 PRNG.
##
## The engine's RandomNumberGenerator is NOT used anywhere in `sim/` because its
## internals are not guaranteed stable across Godot versions. This one is.
## Same seed + same call sequence == same numbers, forever, on every platform.

const MASK: int = 0xFFFFFFFF
const DEFAULT_SEED: int = 0x9E3779B9

var _state: int = DEFAULT_SEED


func _init(seed_value: int = DEFAULT_SEED) -> void:
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	_state = seed_value & MASK
	if _state == 0:
		_state = DEFAULT_SEED


## Raw 32-bit step. All other methods are built on this one.
func next_uint() -> int:
	var x: int = _state
	x = (x ^ (x << 13)) & MASK
	x = x ^ (x >> 17)
	x = (x ^ (x << 5)) & MASK
	_state = x
	return _state


## Inclusive on both ends.
func randi_range(min_value: int, max_value: int) -> int:
	if max_value <= min_value:
		return min_value
	var span: int = max_value - min_value + 1
	return min_value + (next_uint() % span)


## Uniform in [0.0, 1.0).
func randf() -> float:
	return float(next_uint()) / 4294967296.0


## True with the given probability expressed in permille (0..1000).
## Integer probability keeps balance data readable and comparisons exact.
func chance_permille(permille: int) -> bool:
	return randi_range(0, 999) < permille


## Picks an index into `weights` proportionally. Returns -1 for an empty/zero list.
func weighted_index(weights: PackedInt32Array) -> int:
	var total: int = 0
	for w in weights:
		total += maxi(w, 0)
	if total <= 0:
		return -1
	var roll: int = randi_range(0, total - 1)
	var acc: int = 0
	for i in weights.size():
		acc += maxi(weights[i], 0)
		if roll < acc:
			return i
	return weights.size() - 1


## Snapshot/restore for save games and replay verification.
func get_state() -> int:
	return _state


func set_state(value: int) -> void:
	_state = value & MASK
	if _state == 0:
		_state = DEFAULT_SEED
