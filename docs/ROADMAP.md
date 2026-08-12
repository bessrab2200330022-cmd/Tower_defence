# Roadmap

`BACKLOG.md` is the ordered queue of the next few tasks. This file is the shape of the
game over the next several months: what it should become, in what order, and why that
order. `WORKSTREAMS.md` says *who*.

**Revised 12 Aug 2026, after rounds 1–3 of the five-agent fleet.** The previous
revision listed upgrades, flying enemies and enemy abilities as future work. All three
have shipped. Where a phase item is marked ✅ below, it is *done* — the description is
kept because the finding is usually worth more than the tick.

---

## Where the project actually is

Three rounds ago this was a vertical slice with a solid foundation and almost no game
on top. It is now a game with two maps, twelve tower states, ten enemies, four
abilities and no way to reach half of it.

**What exists.** Deterministic sim with a measured balance instrument. Three tower
families × three tiers, with a fork at the top — nine tier defs, nine tier meshes.
Ten enemy defs including a flier, a shield aura, a healer and a splitter. Two maps with
ten waves each. An upgrade panel, tower inspection, synthesised audio, a full Forward+
render stack, and a procedural art pipeline where the Python script *is* the asset.

**What it lacks, in the order it hurts.** No menu — `main.gd` calls
`catalog.first_map()`, so The Corridor is complete and unreachable. No save. Raw
keycodes, no `InputMap`. No boss, no endless, no meta beyond `campaign.md`'s decision.

**The shape of the deficit has inverted.** For two months the constraint was that the
sim had nothing in it. Now design and art routinely run ahead of what the sim and the
view can consume — five enemy models sat inert for a full round, a snow prop kit is
still scattered by nobody, and a second map shipped that no player can open. **Plumbing
is the bottleneck, not ideas.** Plan rounds accordingly: every round should close at
least one gap between something already built and something that cannot use it yet.

---

## Already done — do not rebuild

**Foundation.** Deterministic sim, fixed 60 Hz timestep, seeded RNG, integer money and
damage, event-queue view layer, 13 test suites, view-layer autoplay gate, CI, and
`Simulation.apply_command()` as the single door into the sim.

**Art pipeline.** Procedural Blender models exported to `.glb`, no `.blend` files.
Twelve towers, ten enemies, projectiles, a terrain kit, and three biome scatter sets
(grassland, snow, desert). `mesh_path` with a primitive fallback — the architectural
unlock that lets art and code move independently, and the reason five modelled enemies
could sit on disk with no defs without anything going red.

**Content.** Two maps, twenty waves, nine tower tiers, ten enemies.

**Presentation.** Procedural sky, SSAO, SSIL, SDFGI, SSR, ACES tonemapping, bloom;
floating island with satellites, waterfalls and an orbiting cloud deck; hitscan beams,
muzzle flashes, explosions with real light flashes, damage numbers; synthesised audio
with no binary assets in the repo.

---

## Phase 0 — Learn what the game is — ✅ COMPLETE

The harness (`tests/run_balance.gd`) enumerates the policy space and checks
`difficulty.md`'s nine gates. First pass took them from 1 of 9 to 8 of 9.

Two lessons about measurement that outlived the numbers. **Seed is not an axis** —
`sim/rng.gd` is never drawn from, so matches differing only by seed are byte-identical
and averaging over them reports fake confidence. **Nominal DPS is the wrong
instrument** — what decides a match is *shots per transit*, a small integer that moves
in steps.

**One column still missing.** `difficulty.md` §5 directs the harness to report **added
exposure-seconds** per tower — the extra time enemies spend inside *other* towers'
range because of a slow. Until it lands, the Frost Mortar's entire product is invisible
to every report and the whole family will keep scoring as decoration. Open, A3.

---

## Phase 1 — Feel

Six of eight shipped. Remaining: **1.5 path flow indication**, the **chill visual** half
of 1.6, **1.7 GPUParticles3D**, **1.8 screen shake and hit-stop**.

Shipped: render interpolation (largest single-frame movement 2.41× → 1.00× at 144 Hz),
synthesised audio, selection brackets, range ring shader, damage numbers.

**Open design question, unanswered for two rounds.** Damage numbers print the raw 10×
value, so a 2.7-damage hit reads as "272". `DISPLAY_DIVISOR` in `damage_numbers.gd` is
the one place to change it. A2 should rule on whether the 10× scale is visible to the
player at all — a voice decision as much as a UI one, and it wants answering before the
number appears in a trailer.

---

## Phase 2 — Depth

### 2.1 InputMap migration — 🟡 in flight (A4)
The game reads raw keycodes. Every mechanic adds bindings and the migration cost
compounds. Assigned this round; do not let it slip again.

### 2.2 Tower upgrades — ✅
Three tiers, fork at the top, nine tier defs each carrying full stats. `upgrade_ids` on
`TowerDef`, `credits_invested` on tower state, `try_upgrade` through `apply_command` so
it lands in the replay log for free, `TOWER_UPGRADED` consumed by the view.

**The finding worth keeping:** this shipped across four parallel agent sessions against
a six-line contract pinned before anyone started. The producer and consumer of
`TOWER_UPGRADED` were written in different chats, on different days, and matched —
because A4 resolved the enum *by name* rather than hard-coding the integer, so its
consumer was inert instead of wrong while the sim was still being written. That pattern
is now the house answer to a parallel-session race.

### 2.3 Tower inspection and target modes — ✅
`tower_panel.gd`. Five targeting modes had been implemented and validated for two
months with no UI reaching any of them.

### 2.4 Generalise status effects — **next, and now overdue**
`EnemyState` still hardcodes `slow_percent` and `slow_ticks_left`. Replace with a small
status stack: burn, armour shred, mark, stun. All integers over tick counts, so
determinism survives by construction.

**This moved up the list because 2.6 shipped without it.** Abilities landed on top of a
hardcoded status field, and bosses (3.3) lean on the same schema. Doing it before
bosses means designing it once.

### 2.5 Flying enemies — ✅
`EnemyDef.flies` — straight line spawn to goal at fixed cruise height. The Skiff.
Measured as its own column, per `enemies.md`: a ~40-unit chord against the Walker's
122-unit tour means per-second threat density far exceeds what 900 HP suggests.

### 2.6 Enemy abilities — ✅
`AURA`, `HEAL_PULSE`, `SPLIT_ON_DEATH` behind an enum, never a subclass. The Warden's
reduction folds into the damage computation as a second percentage in a **single**
division — `base × armour% × aura% / 10000` — because a separate division reopens the
double-truncation wound the 10× rescale closed.

### 2.7 Economy agency
**Call the wave early** for a credit bonus proportional to build time forfeited — turns
the build phase from a pause into a risk decision. **Interest between waves.** Both are
pure integer arithmetic on the existing `Economy` and trivially testable. Small,
elegant, still unbuilt.

### 2.8 Tower actives
A manually triggered ability on a cooldown. Route it through `apply_command` so it
lands in the replay log for free.

---

## Phase 3 — Content

### 3.1 Save and load — 🟡 the hard half shipped
`apply_command` exists, so the command vocabulary is already an on-disk format —
renaming an action invalidates every save; treat them as a format, not identifiers.
What remains is serialisation: write `{seed, map_id, [{tick, action, args}]}` and replay
it.

**How the refactor was verified generalises.** The pre-refactor `snapshot_hash()`
sequence was captured *first* and pinned as constants in `test_command_log.gd`.
`test_determinism.gd` compares a run against *itself* and therefore cannot notice a
behaviour change at all; the pinned sequence can.

### 3.2 Multi-path maps — **next for A3**
A fork is where `PathFinder` stops being trivially correct: equal-length routes need a
deterministic tie-break, and towers can no longer cover everything. `maps.md` §3
specifies route enumeration with stable ids, `route_hint` on the spawn group, and a
route-count declaration validated at content-check time.

A2 is writing the Fork's layout and waves now, staged as `.pending`, so the map
promotes with a rename when this lands.

### 3.3 Boss waves
The payoff for 2.4 and 2.6 together. A2 is designing it now. The brief given: a boss
that is a Brute with a bigger number teaches nothing and is exactly what Prime Focus
already answers.

### 3.4 Endless mode
The deterministic sim makes a leaderboard **verifiable** — a score is a seed plus a
command log, replayable server-side. Very few games in this genre can honestly claim
that. `campaign.md` §2 protects this explicitly by refusing between-run unlocks, which
would add a third input outside the log.

---

## Phase 4 — The game around the game

**Promoted from "later" to urgent by content.** Two maps exist and one is unreachable.
Main menu, level select, pause, settings, key rebinding — in flight with A4 this round.
`campaign.md` settles the structure: a linear campaign of ordered maps gated by
completion, with one thin per-map record and nothing else persisting.

Then: **localisation before there are 300 strings, not after**, and a colourblind pass —
the palette currently leans on colour alone to carry armour type, which is a real design
constraint rather than a checkbox.

**Also here, and still open:** the biome prop table. `board.gd::_scatter_props()`
hardcodes seven grassland paths, so a snow kit and a desert kit are built and scattered
by nobody. A5 has written the schema proposal in `art/PENDING.md` §1 as a ready task.

---

## Phase 5 — Ship

`docs/STEAM.md` covers it. The correction worth repeating: **CI does not build releases
yet, only tests.** An export pipeline found to be broken on launch week is entirely
avoidable. Get the store page live months before launch.

---

## Cross-cutting rules

| Layer | What it costs | The gate |
| --- | --- | --- |
| `sim/` change | A test in `tests/cases/`, and a determinism check | `run_tests.gd` exits 0 |
| `data/` change | Cross-reference validity; keep damage/HP on the 10× scale | `test_content.gd` |
| `game/` change | The view-count invariant must survive | `run_autoplay.gd` exits 0 |
| New event type | A producer in `sim/` **and** a consumer in `level.gd` | `run_autoplay.gd` — usually |
| New model | Node-name contract, ground-standing, inside the tile | Bounding-box check |

**Six traps, all of which have happened here at least once:**

1. **An event that creates a view must have exactly one terminal event that destroys
   it.** A projectile whose fuse expired emitted nothing, orphaning its mesh.
2. **A schedule anchored on a tick nobody steps is off by one.** The wave director
   anchored spawns at elapsed 0, which no caller reaches.
3. **MultiMesh instances mesh data, not scene nodes.** Discarding the node transform
   from a `.glb` sank every tower and enemy by half a block.
4. **Blender's mirror modifier mirrors about the object's own origin.** An off-centre
   part folds onto itself — a single-barrelled cannon that looks almost right.
5. **An event that only *mutates* a view is invisible to every gate.** `TOWER_UPGRADED`
   creates no node and destroys none, so an unconsumed one leaves a tier-3 tower wearing
   tier-1 armour with the whole suite green. `ENEMY_SPLIT` is safe; the next
   mutation-only event will not be.
6. **Name-matching in the view is a contract with the art.** `tower_view.gd` tints by
   node name, so a pure prefix swap would have left all three shipped towers untinted.
   Additive matching, always.

---

## If you only do three things

1. **Finish Phase 4's menu (A4, in flight).** A complete map that no player can open is
   the worst ratio of built-to-usable in the project.
2. **Multi-route pathfinding (3.2).** A2 is writing the Fork content right now; landing
   the sim support in the same window means the third map promotes by rename.
3. **Generalise status effects (2.4).** Overdue, and bosses lean on it. Building 3.3
   first means designing the schema twice.

*Done since the last revision: tower upgrades (2.2), inspection (2.3), flying enemies
(2.5), enemy abilities (2.6), a second map, nine tier meshes, the campaign decision.*
