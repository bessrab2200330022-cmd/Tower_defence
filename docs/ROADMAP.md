# Roadmap

`BACKLOG.md` is the ordered queue of the next few tasks. This file is the shape of the game over the next several months: what it should become, in what order, and why that order.

`WORKSTREAMS.md` says *who* does each item.

---

## Where the project actually is

A vertical slice with an unusually solid foundation, a surprisingly complete look, and almost no game on top of either.

**Solid.** The sim/view split holds under inspection: `sim/` has no engine coupling at all, determinism is enforced by a test that runs 400 ticks twice, content is genuinely data-driven, and CI covers the simulation, the boot and a full played match.

**Visually further along than the code suggests.** Every model is a Python script in `art/` exported to `.glb`; the board, the floating island and its scatter are assembled procedurally from the same ASCII layout the pathfinder walks; lighting runs a full Forward+ stack. This was the last two weeks of work and it is largely done.

**Thin where it counts.** One map, three towers, four enemy types, five waves. No save, no menu, no upgrades, no status system beyond a hardcoded slow.

**Balanced against a written target, once.** *Superseded, 12 Aug 2026 — the paragraph here previously said "unbalanced, and now measurably so", citing autoplay losing on wave 3 with four towers standing.* Phase 0 shipped in full: the harness (`tests/run_balance.gd`) enumerates the policy space, `difficulty.md` §4 states nine gates over it, and the first balance pass took them from 1 of 9 passing to 8 of 9. The wave-3 story was wrong — the wallet was the problem, not the tower mix. See BACKLOG's Done list for the findings, which are the most load-bearing paragraphs in the project.

The ordering below still holds for the same reason it always did: **there is no sense adding towers to a game whose existing three have not been measured against each other.** They now have been, once, on one map. That does not survive the second map or the upgrade ladder without re-running.

---

## Already done — do not rebuild

An earlier version of this file listed much of the following as future work. It is not.

**Foundation:** deterministic sim, fixed timestep, seeded RNG, integer money and damage, event-queue view layer, 10 test suites, view-layer autoplay gate, CI.

**Art pipeline:** procedural Blender models exported to `.glb`, no `.blend` files. **17 scripts, 33 `.glb`** as of 12 Aug: three towers, **nine enemies**, one projectile, a terrain kit, eight grassland scatter props and **an eight-piece snow kit**. `mesh_path` on `TowerDef`/`EnemyDef` with a primitive fallback — this was the architectural unlock that made art and code independent, and it is why five modelled enemies can sit on disk with no defs without anything being red.

**Audio:** synthesised at load into `AudioStreamWAV` — no binary sound assets in the repo. Fixed 20-voice pool driven off the event queue.

**Board:** procedural assembly from `.layout.txt`, floating island with stepped underside and roots, six satellite islands, three waterfalls, orbiting cloud deck with a geometric keep-out from the island and the camera.

**Rendering:** procedural sky, sun with angular penumbra, blue fill, SSAO, SSIL, SDFGI, screen-space reflections, ACES tonemapping, bloom, three-step quality enum.

**Effects:** hitscan beams with core and sheath, muzzle flashes, explosions with real light flashes, non-additive smoke, gravity debris, splash rings drawn at true radius, projectile trails, enemy hit flash, pulsing spawn/goal markers.

**Camera:** smoothed orbit on right-drag, keyboard orbit and tilt, clamped pitch, frame-rate-independent easing.

---

## Phase 0 — Learn what the game currently is — ✅ COMPLETE (12 Aug 2026)

**Do not rebuild any of this.** All four items shipped. Kept here with their outcomes because the *findings* are the point, not the tick.

### 0.1 Balance harness — ✅ `tests/run_balance.gd`, run via `scripts/balance.sh` / `.bat`
Enumerates the policy space (build order × placement × saving policy) across S1/S2/S3 classes and checks difficulty.md's nine gates. Deliberately **not** in CI: it is an instrument, not a gate, and exits non-zero only when the harness itself could not run.

Two things it taught about measurement, both worth more than the numbers: **seed is not an axis** — `sim/rng.gd` is never drawn from, so matches differing only by seed are byte-identical and averaging over them reports fake confidence; and **nominal DPS is the wrong instrument** — what decides a match is *shots per transit*, a small integer that moves in steps, not a sustained rate.

The "expected finding" this section used to carry (Arc Cannon over-efficient at ~25 DPS/100cr) was directionally right and mechanically wrong: per 100 credits the Arc led 250 to the Lance's 163, but one Arc Cannon could not solo a 600 HP drone in a full pass.

### 0.2 Instrument the damage table — ✅
Effective DPS per tower × armour pair now comes out of the harness. G8 (energy ≥ 3× kinetic vs Shielded) is checked from measured numbers.

**Still missing one column:** `difficulty.md` §5 directs the harness to report **added exposure-seconds** per tower — the extra time enemies spend inside *other* towers' range because of a slow. Until that lands, the Frost Mortar's actual product is invisible to every report and it will always score as decoration. Open, assigned to A3.

### 0.3 Difficulty target — ✅ `docs/design/difficulty.md`, revision 2
Nine gates (G1–G9), quantified over **policy classes** rather than seeds. Revision 2 exists because the harness disagreed with revision 1 twice and was right both times.

### 0.4 First balance pass — ✅ 1 of 9 gates → 8 of 9
The fix was never one number. See BACKLOG's Done list.

---

## Phase 1 — Feel

The cheapest transformation available. None of it needs an artist, and it is where the remaining gap between "tech demo" and "game" actually lives.

**Five of eight shipped (12 Aug 2026): 1.1, 1.2, 1.3, 1.4 and the first half of 1.6.** Remaining: 1.5, the chill visual, 1.7, 1.8.

### 1.1 Render interpolation — ✅
`main.gd` captures inside the step loop and passes the accumulator remainder into `sync()`. Largest single-frame movement on a tracked enemy went from 2.41× the mean at 144 Hz (4.00× at 240 Hz) to 1.00× at both. `snapshot_hash()` untouched over 900 ticks.

### 1.2 Audio — ✅
`game/audio/` — a `SoundBank` that *synthesises* every sound into an `AudioStreamWAV` at load (~40 ms, ~135 KB, no binary assets to review) and an `AudioDirector` mapping drained events onto a fixed 20-voice pool. Placeholders, and a recipe like "190 Hz falling to 70 over 130 ms" is reviewable in a way a `.ogg` is not. The trap it left behind — deferred `AudioStreamPlayback` release under the Dummy driver leaking ObjectDB instances at exit — is written up in BACKLOG's Done list and is the reason the gate now runs three times.

### 1.3 Selection and hover feedback — ✅
Corner brackets rather than a closed outline (the board is already full of terrain-slab seams). Emits `tower_inspected(cell)`, which nothing consumes yet — deliberately, it is the hook 2.3 hangs off.

### 1.4 Range ring shader — ✅
The `TorusMesh` is gone. A quad lifted 0.09 above the ground with a radial shader, which cannot z-fight by construction.

### 1.5 Path flow indication
Scroll a UV on the path material so the route reads as directional at a glance. Solves a real readability problem on the serpentine map. **Not started.**

### 1.6 Damage numbers and chill visual — 🟡 half
Floating numbers shipped: a 28-strong `Label3D` pool, hand-ticked on the render delta, with hits ≥ 22% of max HP drawn larger and warmer. **The chill visual has not** — the Frost Mortar's 40% slow still reads as a 15% squash and deserves a colour shift.

**Open design question from the shipped half:** the numbers print the raw 10× value, so a 2.7-damage hit reads as "272", matching the HUD's "225 dps". `DISPLAY_DIVISOR` in `damage_numbers.gd` is the single place to change it. A2 should rule on whether the 10× scale is visible to the player at all — it is a voice decision as much as a UI one, and it wants answering before the number appears in a trailer.

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

### 3.1 Save and load — 🟡 the hard half already shipped
`Simulation.apply_command(action, args)` exists: `try_build` / `try_sell` / `start_next_wave` / `set_target_mode` are now thin wrappers over one door, so the command vocabulary is already an on-disk format (renaming one invalidates every save — treat them as a format, not as identifiers). **2.8 and 3.4 are unblocked.**

What remains is only serialisation: write `{seed, map_id, [{tick, action, args}]}` to disk and replay it on load. Note how the refactor was verified, because it generalises — the pre-refactor `snapshot_hash()` sequence was captured *first* and pinned as constants in `test_command_log.gd`. `test_determinism.gd` compares a run against *itself* and therefore cannot notice a behaviour change at all; the pinned sequence can. Negative control: reintroducing a one-point damage change is caught by tick 100 while the determinism suite stays green.

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

*Revised 12 Aug 2026 — the first two of the previous three shipped. Kept below the line for the record.*

1. **InputMap migration (2.1), then tower upgrades (2.2).** In that order and for a mechanical reason: upgrades add a hotkey, and every binding added before the migration doubles its cost. `upgrades.md` has already made the branching call and specified all nine defs, so 2.2 is spec-complete and waiting.
2. **Tower inspection (2.3).** Five targeting modes are implemented, validated, and reachable from no UI. `tower_inspected(cell)` is already emitted and consumed by nothing. This is the cheapest real depth in the project and it got cheaper overnight.
3. **Status effects and flying enemies (2.4, 2.5).** The two mechanics that turn the existing three towers from a sum into a decision. 2.4 first — 2.6 and 3.3 both lean on the same schema, and building them in the wrong order means designing it twice.

*Done: balance harness (0.1); interpolation and audio (1.1, 1.2).*
