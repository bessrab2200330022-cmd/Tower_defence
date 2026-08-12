# Prompt: add an enemy

Add a new enemy archetype called **`<NAME>`**.

Design intent: `<one sentence — what does this enemy punish the player for not doing?>`

Rough shape:
- Armour: `<light | medium | heavy | shielded>`
- Speed relative to `walker` (4.5 u/s): `<faster / slower / same>`
- HP budget: `<roughly N>`

## Requirements

1. Data file only — `data/enemies/<id>.tres`, copying `data/enemies/drone.tres`.
2. If it needs behaviour the current `EnemyState` cannot express (regeneration, splitting on death, armour that changes over time), add it to the schema and to `sim/simulation.gd`. Keep the logic in `sim/`, not in `game/views/`.
3. Reference it from at least one wave in `data/waves/` so it actually appears in the game.
4. Add a test covering the distinguishing behaviour. If it is purely a stat block, a `test_content.gd` assertion is enough; if it has new logic, it needs its own suite.
5. Sanity-check the bounty. Roughly: an enemy should pay back around 1/6 of the credits needed to reliably kill it, or the economy inverts.

## Done when

- The test suite exits 0 and the headless smoke run is clean
- `test_content.gd::test_every_armour_type_is_represented` still passes
- Wave pacing still resolves: `test_content.gd::test_first_wave_is_survivable_with_two_towers` must not regress
