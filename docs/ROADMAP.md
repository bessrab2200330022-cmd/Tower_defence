# Roadmap

`BACKLOG.md` is the ordered queue of the next few tasks. This file is the shape of the game over the next several months: what it should become, in what order, and why that order.

`WORKSTREAMS.md` says *who* does each item.

---

## Where the project actually is

A vertical slice with an unusually solid foundation, a surprisingly complete look, and almost no game on top of either.

**Solid.** The sim/view split holds under inspection: `sim/` has no engine coupling at all, determinism is enforced by a test that runs 400 ticks twice, content is genuinely data-driven, and CI covers the simulation, the boot and a full played match.

**Visually further along than the code suggests.** Every model is a Python script in `art/` exported to `.glb`; the board, the floating island and its scatter are assembled procedurally from the same ASCII layout the pathfinder walks; lighting runs a full Forward+ stack. This was the last two weeks of work and it is largely done.

**Thin where it counts.** One map, three towers, four enemy types, five waves. No audio, no save, no menu, no upgrades, no status system beyond a hardcoded slow.

**Unbalanced, and now measurably so.** `tests/run_autoplay.gd` plays the campaign with a naive build order and loses on wave 3 with four towers standing. That is one data point from one build order, not a verdict — but it is the first real signal the project has produced about its own difficulty, and it says the numbers have never been tuned against anything.

That last point drives the ordering below. **There is no sense adding towers to a game whose existing three have never been measured against each other.**

---

## Already done — do not rebuild

An earlier version of this file listed much of the following as future work. It is not.

**Foundation:** deterministic sim, fixed timestep, seeded RNG, integer money and damage, event-queue view layer, 10 test suites, view-layer autoplay gate, CI.

**Art pipeline:** procedural Blender models exported to `.glb`, no `.blend` files. Three towers, four enemies, one projectile, a terrain kit and eight scatter props. `mesh_path` on `TowerDef`/`EnemyDef` with a primitive fallback — this was the architectural unlock that made art and code independent.

**Board:** procedural assembly from `.layout.txt`, floating island with stepped underside and roots, six satellite islands, three waterfalls, orbiting cloud deck with a geometric keep-out from the island and the camera.

**Rendering:** procedural sky, sun with angular penumbra, blue fill, SSAO, SSIL, SDFGI, screen-space reflections, ACES tonemapping, bloom, three-step quality enum.

**Effects:** hitscan beams with core and sheath, muzzle flashes, explosions with real light flashes, non-additive smoke, gravity debris, splash rings drawn at true radius, projectile trails, enemy hit flash, pulsing spawn/goal markers.

**Camera:** smoothed orbit on right-drag, keyboard orbit and tilt, clamped pitch, frame-rate-independent easing.

---

## Phase 0 — Learn what the game currently is

Cheap, unglamorous, and it makes every later decision better. Nothing here ships to a player. **Everything downstream is guesswork until it exists.**

### 0.1 Balance harness
`tests/run_autoplay.gd` is already 80% of one: it sets up a sim, buys towers, runs waves and reports. Parameterise it — seed, map, build order, tower mix — loop a few hundred matches, and report win rate, average wave reached, credits idle at the end, and damage dealt per tower type.

Only possible because the sim is deterministic and headless. It converts every later balance question from an argument into a measurement.

**Expected finding:** the Arc Cannon is over-efficient. At roughly 25 nominal DPS per 100 credits against the Plasma Lance's 16, it likely dominates every matchup where the armour multiplier gap is under about 1.6×.

### 0.2 Instrument the damage table
Report effective DPS for every tower × armour pair from the harness. The 10× damage scale makes the multipliers land honestly now; verify the table's *intent* survives contact with real fire rates and ranges.

### 0.3 Difficulty target
Decide, in writing, what wave 5 should feel like and what a competent player's life total should be at the end. Without a target, "balanced" is unfalsifiable. This is a design decision, not a measurement.

### 0.4 First balance pass
Tune against the harness. Report before/after numbers, not impressions.

---

## Phase 1 — Feel

The cheapest transformation available. None of it needs an artist, and it is where the remaining gap between "tech demo" and "game" actually lives.

### 1.1 Render interpolation
The sim steps at 60 Hz; on a 144 Hz display everything visibly stutters. Lerp view positions in `level.gd::sync()` using the accumulator remainder from `main.gd`, keeping the previous position in the view node and never in `sim/`. **Must not change `snapshot_hash()` — that is the test.**

### 1.2 Audio
Ranks here, not in Phase 4. A tower defence with no fire, impact or death sound feels broken in a way players will not articulate — they will just call it unfinished. An `AudioStreamPlayer` pool driven off the event queue that already exists. Entirely in `game/`; audio must never affect sim state.

### 1.3 Selection and hover feedback
An outline on the hovered cell and the selected tower. Today the only feedback is the ghost box.

### 1.4 Range ring shader
Replace the `TorusMesh` with a flat radial shader — crisper, no z-fighting, and it can pulse when placement is invalid.

### 1.5 Path flow indication
Scroll a UV on the path material so the route reads as directional at a glance. Solves a real readability problem on the serpentine map.

### 1.6 Damage numbers and chill visual
`ENEMY_DAMAGED` already carries amount, hp and position, so no sim change is needed. The Frost Mortar's 40% slow currently reads as a 15% squash; it deserves a colour shift.

### 1.7 GPUParticles3D
Migrate `effects.gd` from hand-rolled pooling. **Keep the pooling discipline** — nothing may leak when the game is paused or at 4× speed, which is exactly why the current version is hand-ticked.

### 1.8 Screen shake and hit-stop
On brute deaths and on leaks. Gated behind an accessibility toggle from the start, not retrofitted.

---

## Phase 2 — Depth

Ordered so each item makes the *existing* content deeper before any of it makes the content wider. A fifth tower is worth less than a reason for the current three to interact.

### 2.1 InputMap migration
**Do this before anything else in Phase 2.** The game reads raw keycodes. Every mechanic below adds another binding and the migration cost compounds with each one.

### 2.2 Tower upgrades
Schema-first. The decision worth making now: **linear tiers or a branching choice at tier 2?** Branching is dramatically more interesting per unit of content — one tower with two divergent tier-3s reads as three towers — and the cost is only in the schema, if the schema is designed for it on the first pass.

### 2.3 Tower inspection and target modes
Five targeting modes are already implemented and validated, and no UI reaches any of them. The cheapest real depth in the project.

### 2.4 Generalise status effects
`EnemyState` hardcodes `slow_percent` and `slow_ticks_left`. Replace with a small status stack and the design opens immediately: burn, armour shred, mark, stun. All integers over tick counts, so determinism is preserved by construction.

Genuine new `sim/` logic rather than data, so it needs real test coverage — and it is the foundation everything in 2.6 and 3.3 leans on.

### 2.5 Flying enemies
The most conspicuous absence. Mechanically cheap: a second waypoint list running straight from spawn to goal, plus `can_target_air` on `TowerDef`. Forces building for two threat axes and instantly makes tower selection a decision rather than a DPS calculation.

### 2.6 Enemy abilities
Where waves stop being "the same thing with bigger numbers": shield aura, healer, splitter, sprinter. Composable data-selected behaviours with an enum — **not a subclass per ability**, which is exactly the drift `ARCHITECTURE.md` warns about.

The splitter needs sim support for spawning at an arbitrary path position; design that carefully, it is the one with real determinism risk.

### 2.7 Economy agency
Small, elegant, high value. **Call the wave early** for a credit bonus proportional to build time forfeited — turns the build phase from a pause into a risk decision. **Interest between waves** — rewards saving, creating tension with building now. Both are pure integer arithmetic on the existing `Economy` and trivially testable.

### 2.8 Tower actives
A manually triggered ability on a cooldown. Adds a skill ceiling and a moment-to-moment input loop a pure builder lacks. Route it through the existing `try_*` command surface so it lands in the replay log for free.

---

## Phase 3 — Content

Only now, once the mechanics make content worth designing around.

### 3.1 Save and load
Save = seed + map id + ordered command log. Load = replay it. Possible *because* the sim is deterministic, and far more robust than serialising entity state. Needs `Simulation.apply_command()` so replay and live input share one path — which also unblocks 2.8 and 3.4.

### 3.2 Multi-path maps
A fork is where `PathFinder` stops being trivially correct: equal-distance routes need a deterministic tie-break, and towers can no longer cover everything. Do it after 2.4 and 2.5 so the new map has mechanics worth designing around.

### 3.3 Boss waves
The payoff for 2.4 and 2.6 together: immunities that invalidate a lazy build, phase transitions at HP thresholds, and a reason to have kept a niche tower.

### 3.4 Endless mode
Scaling waves, no defined end. The deterministic sim makes a leaderboard **verifiable** — a score is a seed plus a command log, replayable server-side. Very few games in this genre can honestly claim that.

---

## Phase 4 — The game around the game

Main menu, level select, pause, settings, key rebinding (trivial once 2.1 is done), localisation via Godot's CSV workflow, accessibility.

Two notes. **Localisation before there are 300 strings, not after.** And the palette currently leans on colour alone to carry armour type — the colourblind pass is a real design constraint, not a checkbox.

---

## Phase 5 — Ship

`docs/STEAM.md` covers it. The correction worth repeating: **CI does not build releases yet, only tests.** That is real work, not a formality, and an export pipeline found to be broken on launch week is entirely avoidable.

Get the store page live months before launch. Wishlists are the single biggest lever on launch-day visibility.

---

## Cross-cutting rules

| Layer | What it costs | The gate |
| --- | --- | --- |
| `sim/` change | A test in `tests/cases/`, and a determinism check | `run_tests.gd` exits 0 |
| `data/` change | Cross-reference validity; keep damage/HP on the 10× scale | `test_content.gd` |
| `game/` change | The view-count invariant must survive | `run_autoplay.gd` exits 0 |
| New event type | Both a producer in `sim/` and a consumer in `level.gd` | `run_autoplay.gd` — a missing consumer orphans a node |
| New model | Node-name contract, ground-standing, inside the tile | Bounding-box check; see `art/README.md` |

Four traps worth naming, because all four have already happened once in this repo:

1. **An event that creates a view must have exactly one terminal event that destroys it.** A projectile whose fuse expired used to emit nothing, orphaning its mesh silently.
2. **A schedule anchored on a tick nobody steps is off by one.** The wave director anchored spawns at elapsed 0, which no caller reaches.
3. **MultiMesh instances mesh data, not scene nodes.** Extracting a `Mesh` from a `.glb` and discarding the node transform sank every tower and enemy by half a block.
4. **Blender's mirror modifier mirrors about the object's own origin.** An off-centre part folds onto itself, producing a single-barrelled cannon that looks almost right.

---

## If you only do three things

1. **Balance harness (0.1).** Everything downstream is guesswork without it, and the instrument already half-exists.
2. **Interpolation and audio (1.1, 1.2).** The cheapest possible transformation of how the game feels, neither requiring an artist.
3. **Status effects and flying enemies (2.4, 2.5).** The two mechanics that turn the existing three towers from a sum into a decision.
