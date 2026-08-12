class_name SimTypes
extends RefCounted
## Shared enums and constants for the pure simulation layer.
##
## This file has NO engine/scene dependencies and must stay that way.
## Anything in `sim/` may import this; nothing in `sim/` may import `game/`.

## Simulation runs at a fixed rate. Never use `delta` inside `sim/`.
const TICK_HZ: int = 60
const TICK_DELTA: float = 1.0 / 60.0

## Grid cell kinds, stored as bytes in SimGrid.cells.
enum Cell {
	BUILDABLE = 0, ## Towers may be placed here. Enemies cannot walk here.
	PATH = 1,      ## Enemies walk here. Towers may not be placed here.
	BLOCKED = 2,   ## Decor / scenery. Nothing may occupy it.
}

enum DamageType { KINETIC = 0, ENERGY = 1, EXPLOSIVE = 2 }

enum ArmorType { LIGHT = 0, MEDIUM = 1, HEAVY = 2, SHIELDED = 3 }

enum TargetMode {
	FIRST = 0,     ## Furthest along the path.
	LAST = 1,      ## Least far along the path.
	CLOSEST = 2,   ## Nearest to the tower.
	STRONGEST = 3, ## Highest current HP.
	WEAKEST = 4,   ## Lowest current HP.
}

enum FireMode {
	HITSCAN = 0,    ## Damage applied immediately on fire.
	PROJECTILE = 1, ## Spawns a travelling projectile.
}

## Emitted by Simulation and drained by the presentation layer each frame.
## The sim never touches nodes; the view never mutates sim state.
enum Event {
	WAVE_STARTED = 0,
	WAVE_CLEARED = 1,
	ENEMY_SPAWNED = 2,
	ENEMY_MOVED = 3,
	ENEMY_DAMAGED = 4,
	ENEMY_KILLED = 5,
	ENEMY_LEAKED = 6,
	TOWER_BUILT = 7,
	TOWER_SOLD = 8,
	TOWER_FIRED = 9,
	PROJECTILE_SPAWNED = 10,
	PROJECTILE_HIT = 11,
	CREDITS_CHANGED = 12,
	LIVES_CHANGED = 13,
	GAME_WON = 14,
	GAME_LOST = 15,
	## A shot that ran out its fuse without landing. Carries no damage; it exists
	## only so the view layer can free the projectile node. Every projectile must
	## end in exactly one of PROJECTILE_HIT or PROJECTILE_EXPIRED, or views leak.
	PROJECTILE_EXPIRED = 16,
	## A tower became a higher tier in place. Carries the new def_id and tier.
	## Unlike every other view-affecting event this one MUTATES a view rather
	## than creating or destroying one, so the autoplay view-count invariant
	## cannot catch a missing consumer - an unconsumed upgrade is a tier-3 tower
	## still wearing its tier-1 mesh, and only a human will notice.
	TOWER_UPGRADED = 17,
}

enum Phase {
	BUILD = 0,   ## Between waves. Player may build/sell.
	COMBAT = 1,  ## Wave in progress.
	WON = 2,
	LOST = 3,
}

## Convenience: seconds -> ticks, rounded to nearest tick.
static func seconds_to_ticks(seconds: float) -> int:
	return int(round(seconds * float(TICK_HZ)))

static func ticks_to_seconds(ticks: int) -> float:
	return float(ticks) * TICK_DELTA
