# Prompt: add a tower

Add a new tower archetype called **`<NAME>`**.

Design intent: `<one sentence — what problem does this tower solve that existing towers don't?>`

Rough shape:
- Cost: `<credits>`
- Role: `<single-target / crowd clear / support / anti-armour>`
- Damage type: `<kinetic | energy | explosive>`
- Fire mode: `<hitscan | projectile>`

## Requirements

1. Implement it as a **data file only** — `data/towers/<id>.tres`, copying the structure of `data/towers/arc_cannon.tres`. Do not add a new script.
2. If the behaviour cannot be expressed with the existing `TowerDef` fields, add the field to `data/schemas/tower_def.gd`, wire it through `Simulation.try_build` into `TowerState`, and handle it in `sim/simulation.gd`. Then it is data again for the next tower.
3. Give it a distinct niche. Check `sim/damage.gd` — the damage-type × armour-type table is the main lever. A tower that is strictly better than an existing one is a bug.
4. Add a test in `tests/cases/` proving the distinguishing behaviour, using `tests/support/fixtures.gd` to build content in code rather than depending on shipped balance values.
5. Update `test_content.gd` if the tower introduces a new invariant worth guarding.

## Done when

- `godot --headless --path . --script res://tests/run_tests.gd` exits 0
- `godot --headless --path . --quit-after 600` prints no errors
- The tower appears in the build bar automatically (the HUD reads `Catalog.tower_ids()` — you should not need to touch `hud.gd`)
- You have written one paragraph in the PR description explaining when a player should buy this over the alternatives
