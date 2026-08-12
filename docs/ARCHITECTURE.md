# Architecture

## The premise

Almost all the code in this repo is written by coding agents. That single fact drives every structural decision here, because agents have a specific failure mode: they write plausible code, cannot see it run, and cannot tell you when they have quietly broken something three systems away.

The counter to that is a codebase where correctness is *checkable without a human playing the game*. Everything below follows from that.

## The sim/view split

```
              player input
                   |
                   v
   game/  ---- commands ---->  sim/          (try_build, try_sell, start_next_wave)
          <---- events -----                 (drain_events)
          <---- state ------                 (read-only: enemies, towers, economy)
```

`sim/` is plain GDScript objects with no engine coupling: no `Node`, no `SceneTree`, no `_process`, no `Input`, no signals, no rendering. It advances only through `Simulation.step()`, one 60 Hz tick at a time.

That means the entire game can run headless, at any speed, thousands of times, inside a test. `test_content.gd` plays whole waves in milliseconds. `test_determinism.gd` runs 400-tick matches twice and compares them tick for tick. Neither is possible if targeting logic lives inside a `_physics_process` on an `Area3D`.

`game/` is the opposite: it holds no rules. It builds meshes from `.tres` fields, moves nodes to positions the sim already computed, and turns clicks into commands. If you can delete a file in `game/` and the tests still pass, that file was correctly scoped.

## Why determinism

Determinism is not an aesthetic preference. It buys four concrete things:

1. **Reproducible bugs.** "It desyncs around wave 4" becomes a seed and a tick number.
2. **Replays and save games** become a seed plus a command log, rather than a serialisation of every object.
3. **Balance measurement.** You can run a thousand matches with different build orders and get real numbers rather than a feeling.
4. **Agent self-verification.** An agent can prove its change did not alter behaviour by comparing `snapshot_hash()` sequences — which is far stronger evidence than "the tests still pass".

The rules that preserve it:

* Fixed timestep. `SimTypes.TICK_DELTA` is a constant; engine `delta` never reaches `sim/`.
* Seeded RNG only (`sim/rng.gd`, xorshift32). The engine's `RandomNumberGenerator` is banned because its internals are not guaranteed stable across Godot versions.
* Integer money and integer damage. Damage multipliers are integer percentages (`sim/damage.gd`), so `20 damage vs shielded` is exactly 10 on every machine. The cost is truncation, which is why shipped damage and HP sit at a 10× scale — at single-digit damage the armour table was quietly losing 5–11% of its own effect, and splash hits truncated twice before `compute_splash()` folded the two percentages into one division.
* Fixed iteration order. `SimGrid.neighbours4()` returns a fixed order, which is what makes BFS pick the same path every time. Entity arrays are compacted in order rather than swap-removed.
* Deterministic tie-breaks. `Targeting.select()` falls back to the lower enemy id when scores are equal.

Positions are still floats, so this is determinism *within a platform*, not lockstep-multiplayer determinism across architectures. That is sufficient for a single-player game. If networked co-op is ever on the table, the migration is to fixed-point positions — which is why positions are confined to `sim/entities/` and touched in exactly one movement function.

## Why data-driven

Towers, enemies, waves and maps are `.tres` resources and ASCII text files, not classes. Adding content is a new file with no registry to update: `Catalog` scans the directories, and the HUD builds its build bar from `Catalog.tower_ids()`.

This matters more than usual here. An agent asked to "add a tower" will, given the chance, write a new script with its own firing logic — and now there are two firing implementations that drift. Making the data path the path of least resistance is the cheapest available defence against that.

`Catalog.validate()` cross-checks every reference (waves → enemies, maps → waves) and every definition's own `is_valid()`. `test_content.gd` runs it. A typo in a `.tres` fails CI rather than crashing at wave 4.

## Map layouts as text files

`data/maps/*.layout.txt` holds the board as ASCII rather than embedding an escaped string in the `.tres`. It costs one indirection and buys a map that shows up as a readable diff:

```diff
- .##################.
+ .#################X.
```

An agent can reason about that. It cannot reason about `"...\n.##...X#\n..."`.

## The test harness

`tests/` implements a small xUnit clone rather than pulling in GUT or GdUnit4. The reason is dependency surface: a fresh clone needs exactly one thing, the Godot binary. No addon to install, no version compatibility matrix, no `.godot/` state that differs between a developer machine and a CI container. The harness is ~120 lines and every agent working here can read all of it.

`tests/run_tests.gd` extends `SceneTree` so it runs under `--script` with no scene, discovers `tests/cases/*.gd` automatically, and exits non-zero on failure. Exit codes are the contract — nothing scrapes stdout.

### The view layer needs its own runner

Test cases extend `RefCounted` and never touch a node, which is what makes them fast — and what makes them structurally blind to `game/`. Booting the real scene headless doesn't cover the gap either: nothing starts a wave without a keypress, so `--quit-after` renders a board and idles.

`tests/run_autoplay.gd` closes it. It extends `SceneTree`, wires a real `Simulation` to a real `Level` and `Hud`, buys towers, starts waves, and plays to a result. Every frame it asserts:

```
level.view_counts() == { enemies, towers, projectiles } sizes in the sim
```

That invariant is load-bearing. View nodes are created and destroyed *only* from drained events, so if the counts diverge, an event went missing and a mesh has been orphaned — parented forever, never updated, never freed. It is not a thing a unit test can see, because a unit test never builds a view. Writing it caught two real defects on its first run: a projectile whose fuse expired emitted no event at all, and `RtsCamera.setup()` silently required its node to already be inside the tree.

### What the view-count invariant does not catch

The autoplay assert compares view counts to sim entity counts, so it catches any event that should have **created or destroyed** a node and didn't. It is blind to events that only *mutate* an existing view.

`TOWER_UPGRADED` is the first of these. A tier-2 tower is the same node as the tier-1 tower it replaced — no node is created, none destroyed — so a producer in `sim/` with no consumer in `level.gd` leaves a fully upgraded tower wearing its old mesh, firing at its new rate, with every gate green.

This class of event needs its own check. The cheapest is an assertion in the autoplay runner that after an upgrade command the view's `def_id` matches the sim's, which generalises to any future mutate-only event. Until that exists, treat mutate-only events as **unverified by CI** and say so at the seam.

## Event queue rather than signals

`Simulation` appends dictionaries to `events` and the view drains them once per frame. Signals would have been more idiomatic Godot, but they would have coupled the sim to `Object`, made ordering implicit, and made "what happened during tick 412" impossible to assert in a test. A drained array is inspectable, ordered, and free of engine types.

## Known trade-offs

* **Float positions.** Fine for single player, would need fixed-point for lockstep netcode.
* **`_tower_by_id` is a linear scan.** Towers number in the dozens; a dictionary is premature until they don't.
* **No render interpolation.** The sim runs at 60 Hz and most displays do too. At 144 Hz there is visible stepping. The fix is to interpolate in `level.gd::sync()` using the accumulator remainder from `main.gd` — deliberately deferred, listed in the backlog.
* **View nodes are created per entity.** Fine at current counts. If wave sizes reach the hundreds, enemies should move to a `MultiMeshInstance3D` the way the board already does.

## Adding a dependency

Don't, without adding a paragraph here explaining what the standard library could not do. The current dependency count is zero and that is a feature: it is why `.codex/setup.sh` is 30 lines and why CI takes under two minutes.
