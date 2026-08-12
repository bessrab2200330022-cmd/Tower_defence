# Backlog

Roughly in the order it should be tackled. Each item is sized to be one agent task. When you finish one, move it to **Done** with a one-line note.

The ordering is deliberate: prove the loop is fun before scaling content, and get a Steam page live long before you need it.

For the longer view — where graphics and mechanics are heading over the next several months, and why in that order — see [ROADMAP.md](./ROADMAP.md). This file stays the short queue.

---

## Now — make the loop good

### 1. Tower upgrades
Two upgrade tiers per tower, bought in place. Schema first: add `upgrade_ids: PackedStringArray` to `TowerDef` and make each tier its own `.tres`, so an upgrade is data, not a branch. `TowerState` keeps `credits_invested` so the sell refund already handles it.
*Tests: upgrade costs credits, stats change, sell refunds the total invested.*

### 2. Tower selection and inspection
Click a placed tower to see range, DPS, kills, damage dealt, and to change its target mode. `Simulation.set_target_mode()` already exists and is untested from the UI.
*Tests: target mode change is reflected in the next shot.*

### 4. Two more maps
One with a fork (two routes to the goal), one with a long single corridor and scarce build ground. Use `.codex/prompts/new-map.md`. This is where you find out whether the pathfinder needs multi-goal support.

### 5. First balance pass
Use `.codex/prompts/balance-pass.md`. Measure, don't guess — the sim is headless and deterministic, so run hundreds of matches.

### 6. Sound
Fire, impact, enemy death, leak, wave start, UI clicks. An `AudioStreamPlayer` pool driven off the same event queue the views read. Keep it entirely in `game/` — audio must never affect sim state.

---

## Next — make it a game

### 7. Save and load
Save = seed + map id + the ordered command log (`{tick, action, args}`). Load = replay it. This is only possible *because* the sim is deterministic, and it is far more robust than serialising entity state. Add a `Simulation.apply_command()` entry point so replay and live input share one path.
*Tests: a replayed command log reproduces the same `snapshot_hash()` sequence.*

### 8. Main menu, level select, pause menu, settings
Resolution, volume, key rebinding. Key rebinding means an `InputMap` layer — the game currently reads raw keycodes, which is fine for a prototype and not fine for shipping.

### 9. Meta progression
Between-run unlocks or a campaign map. Decide which before building either; they pull the game in different directions.

### 10. Art pass
Replace generated primitives with real models. `game/views/*.gd` is the only place that touches geometry, so this is contained. Decide on a style that a small team can actually produce — low-poly with flat colours is the honest answer for a solo project.

### 11. Localisation
Godot's CSV translation workflow. Do this *before* there are 300 strings, not after. All user-facing text currently sits in `.tres` `display_name`/`description` fields and `hud.gd`.

### 12. Accessibility
Colourblind-safe palette for damage/armour types (the current scheme leans on colour alone), scalable UI, no reliance on fast reactions.

---

## Ship — Steam

See `docs/STEAM.md` for the detail. Summary:

### 13. Steamworks integration
GodotSteam for achievements, cloud saves and the overlay. This is the only place a native dependency enters the project; keep it behind a thin wrapper in `game/` so the sim and the tests never see it.

### 14. Store page and wishlists
$100 Steam Direct fee per app, recouped after $1,000 revenue. Get the page live months before launch — wishlists are the single biggest lever on launch-day visibility.

### 15. Build pipeline
Extend CI to produce Windows and Linux release builds on tag, and upload via `steamcmd`. Export templates must match the engine version exactly.

### 16. Playtesting
The thing no amount of test coverage substitutes for. A green suite tells you the code does what it says; it tells you nothing about whether wave 4 is fun.

---

## Ideas — unscheduled

- Endless mode with scaling waves; the deterministic sim makes leaderboards verifiable.
- Enemy abilities: shielding aura, healing, splitting on death.
- Tower synergies (adjacency bonuses).
- Replay sharing — a seed and a command log is a few hundred bytes.
- Mod support: `Catalog` already scans directories, so a user content folder is a small change.

---

## Done

- **Vertical slice.** One map, three towers, four enemy types, five waves, build/sell, win/lose, deterministic sim, headless test suite, CI.
- **Wave spawn timing.** The director anchored each group's schedule on a tick nobody ever steps, so the first gap in every wave was `interval - 1`. Red suite, now green.
- **View-layer coverage.** `tests/run_autoplay.gd` plays a full match through the real `Level` and `Hud` and asserts view counts match sim entity counts every frame. Nothing in CI executed `game/views/` before it. Caught a projectile fuse that emitted no event (orphaned mesh) and an `RtsCamera.setup()` that silently required its node to be in the tree already.
- **Damage precision.** Shipped damage and HP moved to a 10× scale, and splash now folds armour and falloff into one division — the armour table was losing 5–11% of its own effect to integer truncation, worst exactly where the counter-play should be sharpest.
- **Art pipeline and models.** `art/` builds every model procedurally in Blender and exports `.glb`; the script is the asset, there are no `.blend` files. Three towers, four enemies, a projectile, a terrain kit and eight scatter props. Node names (`Base`, `Turret`, `Barrel`) are a contract with `game/views/tower_view.gd`. Both view scripts keep their primitive fallback, so an unmodelled tower or enemy stays playable.
- **Procedural board.** `game/board.gd` assembles terrain slabs, placement pads and a scattered border from the same `.layout.txt` the pathfinder walks — so a new map is still one text file and gets dressed automatically. Building the map in Blender was rejected: it would be a second source of truth for the grid.
- **Lighting and post.** `game/lighting.gd` — procedural sky, sun with angular penumbra, blue fill, SSAO, SSIL, screen-space reflections, ACES tonemapping and bloom, behind a three-step quality enum. Bloom threshold sits at 1.05 so only genuinely emissive things bloom and silhouettes stay crisp.
- **Map validation.** `test_content.gd` boots every shipped map, not just the first. `MapDef.is_valid()` never ran the pathfinder, so a severed route would have shipped undetected the moment a second map existed.
- **Balance harness (ROADMAP 0.1).** `tests/run_balance.gd`, run via `scripts/balance.sh` / `.bat`; deliberately not in CI. What was actually wrong: the shipped game has a **0% win rate over 120 matches** — every placement policy, every build order, every saving policy loses, best case wave 4 of 5. It is not a tower-mix problem, it is the economy: `starting_credits = 320` buys three Arc Cannons against a wave 1 of eight drones. Sweeping credits gives 0% / 15% / 40% / 65% / 93% / 98% at 320 / 480 / 560 / 640 / 800 / 960, so the entire difficulty range lives in a 1.7× window and the shipped value sits below the bottom of it. Two things learned about measurement itself: **seed is not a useful axis** — `sim/rng.gd` is never drawn from, so matches differing only by seed are byte-identical and averaging over them reports fake confidence; and **nominal DPS is the wrong instrument** — per 100 credits the Arc Cannon leads 250 to the Plasma Lance's 163, but what decides a match is damage landed while an enemy crosses the range circle, and one Arc Cannon deals 495 to a 600 HP drone in a full pass, i.e. it cannot solo the cheapest enemy in the game.
- **One door into the sim (`Simulation.apply_command`).** `try_build` / `try_sell` / `start_next_wave` / `set_target_mode` are now thin wrappers over a single `apply_command(action, args)`, so a save can be seed + map id + an ordered command log and a load can be replaying it. Routing only — no rule moved. The useful part is how it was verified: the pre-refactor `snapshot_hash()` sequence for a 400-tick scripted match was captured first and pinned as constants in `test_command_log.gd`, because `test_determinism.gd` compares a run against *itself* and therefore cannot notice a behaviour change at all. Negative control: reintroducing a one-point damage change is caught by tick 100 while the determinism suite stays green.
- **Render interpolation (backlog 3).** `main.gd` calls `level.capture_tick_start()` before each `Simulation.step()` and passes the accumulator remainder into `sync()`; views blend between the two. Capturing *inside* the step loop rather than in front of it is the part worth remembering — after a catch-up burst the interpolation source has to be the second-to-last tick, not wherever the entities were last frame. Measured on a tracked enemy, the largest single-frame movement was 2.41× the mean at 144 Hz and 4.00× at 240 Hz; it is now 1.00× at both, and unchanged at 60 Hz. 900 tick hashes are identical with and without the view layer attached, so `snapshot_hash()` is untouched.
- **Three ERROR floods the autoplay gate was carrying.** `run_autoplay.gd` exited 0 throughout, so this never read as a failure — but `AGENTS.md` §5.2 also requires no `ERROR:` lines, and there were thousands per run. (a) `projectile_view.gd` called `look_at()` *before* assigning the new position, so it asked the engine to look at the point the node was already standing on, every frame of every shot. (b) `lighting.gd` passed `index + 1` to `set_glow_level()`, which is zero-indexed: every bloom weight landed one level too high and the seventh went out of bounds, so the tight aliasing halo the array deliberately zeroes was running at 0.25 and the widest level was never set at all. (c) `rts_camera.gd::setup()` called `look_at()` during scene construction, which asserts the node is already in the tree — the same defect `run_autoplay.gd` was credited with catching once before. All three now use `Basis.looking_at` or the correct index; the gate prints zero `ERROR:` and zero `WARNING` lines.
- **Enemies face where they are walking.** They had no orientation at all — the sim tracks a position and a waypoint index and nothing else, so every enemy crabbed sideways down the serpentine leg. `enemy_view.gd` derives a heading from movement between ticks and eases onto it, matching the `atan2(x, z)` convention the sim already uses for tower facing. The body rotates, not the view root, so the health bar does not swing with it.
- **Health bars never actually shrank.** `BILLBOARD_ENABLED` rebuilds the model-view matrix from the camera and discards the node's scale unless `billboard_keep_scale` is set, which it was not — so the bar only ever changed colour. One flag.
- **Frame-rate-dependent recoil.** `tower_view.gd` decayed recoil by a fixed 0.12 per *call*, so a barrel recovered twice as fast on a 120 Hz display as on a 60 Hz one. Now 7.2 per second, which is the identical feel at the old reference rate. Turret traverse now eases onto `tower.facing` for the same class of reason: the sim only writes that field on the tick a shot fires, so it arrives as a step function.
