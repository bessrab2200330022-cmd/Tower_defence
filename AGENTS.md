# AGENTS.md — Bastion Line

A deterministic 3D tower defence game in **Godot 4.7 / GDScript**, targeting a Steam release.

This file is the contract for any coding agent working in this repo (Codex, Claude Code, or otherwise). Read it fully before your first edit. If something here is wrong or out of date, fix this file in the same PR as the code change.

---

## 1. Environment

| Thing | Value |
| --- | --- |
| Engine | Godot **4.7**, standard build (not .NET). Anything 4.4+ should work; the project file targets 4.7. |
| Language | GDScript only. No C#, no GDExtension, no third-party addons. |
| Binary | `godot` on `PATH`. In the Codex sandbox, `.codex/setup.sh` installs it to `/usr/local/bin/godot`. |
| Test framework | Home-grown, in `tests/`. Do **not** add GUT or GdUnit4. |

Godot writes an import cache to `.godot/` on first load. It is gitignored. If a fresh checkout behaves strangely, run `scripts/import.sh` before anything else.

---

## 2. Commands

Run these from the repo root. Every one of them is non-interactive and safe in CI.

```bash
# Import assets / rebuild the class cache. Run once after a fresh clone.
godot --headless --path . --import

# The test suite. THIS IS THE GATE. Exit code 0 = pass.
godot --headless --path . --script res://tests/run_tests.gd

# Play a whole match headless through the real Level and Hud. THE SECOND GATE.
godot --headless --path . --script res://tests/run_autoplay.gd

# Boot the real scene and fail on any engine error. Note: --quit-after counts
# FRAMES, not simulation ticks, and headless runs unthrottled - 600 frames is
# roughly 180 ticks of game time. It also never starts a wave, which is exactly
# why run_autoplay.gd exists.
godot --headless --path . --quit-after 600

# Sweep hundreds of matches and report win rate, waves reached, idle credits
# and damage per tower. NOT A GATE - it exits non-zero only when the harness
# itself could not run, never because the game is unbalanced. Deliberately
# outside CI: it measures, it does not judge.
godot --headless --path . --script res://tests/run_balance.gd -- --seeds=40
godot --headless --path . --script res://tests/run_balance.gd -- --map=crossing --credits=320 --order=kinetic

# Play it (needs a display).
godot --path .

# Export a Windows build.
godot --headless --path . --export-release "Windows Desktop" build/BastionLine.exe
```

Shorthands: `scripts/import.sh`, `scripts/test.sh`, `scripts/autoplay.sh`, `scripts/smoke.sh`, `scripts/balance.sh`, `scripts/export.sh`.

On Windows, `scripts\test.bat`, `scripts\autoplay.bat`, `scripts\balance.bat`, `scripts\play.bat` and `scripts\smoke.bat` locate `godot.exe` themselves (see `scripts/find_godot.ps1`), so no PATH setup is required. `scripts\where_is_godot.bat` is the diagnostic.

**The balance harness is an instrument, not a gate.** `docs/design/difficulty.md` defines nine falsifiable targets (G1–G9) for it to measure against; a failing gate there is a design conversation, not a red build. Keeping it out of CI is deliberate — a test that fails because the game is *hard* teaches agents to relax assertions, which is exactly the habit `test_determinism.gd` cannot afford them to learn.

Without a terminal at all: open `tests/run_tests_in_editor.tscn` in the Godot editor and press **F6**. It runs the same suites through `tests/runner_core.gd` and prints to the Output panel. CI still uses the CLI runner and the exit code.

---

## 3. Architecture — the one rule that matters

The codebase is split into a **pure simulation** and a **dumb view**. This split is the reason the project is testable, and it is the thing most likely to be eroded by a careless change.

```
sim/     Pure GDScript game logic.  RefCounted only.  Fully unit tested.
data/    Balance content as .tres Resources + ASCII map files.
game/    Godot nodes. Renders sim state, forwards player input. No game rules.
tests/   Headless test harness and suites.
docs/    Architecture notes, backlog, Steam checklist.
```

### Hard constraints on `sim/`

* **No engine coupling.** No `Node`, no `SceneTree`, no `get_tree()`, no `Input`, no `_process`, no signals, no rendering. `RefCounted`, `Resource`, and core value types (`Vector3`, `Vector2i`, `Dictionary`, `Packed*Array`) only.
* **No wall-clock time.** Time advances only through `Simulation.step()`, one fixed tick at a time (`SimTypes.TICK_DELTA`, 60 Hz). The engine's `delta` never enters `sim/`.
* **No ambient randomness.** `randi()`, `randf()` and `RandomNumberGenerator` are banned. Use `Simulation.rng` (`sim/rng.gd`, seeded xorshift32).
* **Integer money and integer damage.** Currency is whole credits; damage multipliers are integer percentages. No floats in either.
* **One-way data flow.** `sim/` never imports from `game/`. `game/` reads sim state and drains `Simulation.drain_events()`; it never mutates sim state except through the public command methods (`try_build`, `try_sell`, `start_next_wave`, `set_target_mode`).

If you need to break one of these, stop and open a discussion in `docs/ARCHITECTURE.md` first. A change that quietly makes the sim non-deterministic will not be caught by a human reviewer, only by `tests/cases/test_determinism.gd` — which is exactly why that suite must never be weakened.

### Where things live

| Path | Responsibility |
| --- | --- |
| `sim/sim_types.gd` | Enums, tick constants, event types. |
| `sim/rng.gd` | Deterministic PRNG. |
| `sim/grid.gd` | ASCII layout → byte grid, cell/world conversion. |
| `sim/path_finder.gd` | BFS over walkable cells; distance field + waypoints. |
| `sim/economy.gd` | Credits and lives. Integers only. |
| `sim/damage.gd` | Damage-type × armour-type table, splash falloff. |
| `sim/targeting.gd` | Target selection modes, splash queries. |
| `sim/wave_director.gd` | Wave definitions → per-tick spawn requests. |
| `sim/entities/*.gd` | Plain data structs for enemies, towers, projectiles. |
| `sim/simulation.gd` | The tick loop, player commands, event emission, `snapshot_hash()`. |
| `data/schemas/*.gd` | `Resource` subclasses defining the shape of content. |
| `data/catalog.gd` | Directory scan → id-keyed dictionaries + `validate()`. |
| `game/main.gd` | Fixed-timestep loop. The **only** caller of `Simulation.step()`. |
| `game/level.gd` | Builds the board, manages view nodes, handles placement clicks. |
| `game/ui/hud.gd` | HUD, built from the tower catalog at runtime. |
| `game/views/*.gd` | Per-entity visuals, generated from `.tres` fields. |

---

## 4. How to add content (do this before you add code)

Adding a tower, enemy, wave or map should be **a data file, not a class.** Only write a new script when the behaviour genuinely cannot be expressed by existing fields — and if you do, add the field to the schema so the next one is data again.

**Damage and HP are held at a 10x scale.** A turret that hits for 9 is written `damage = 90`; a 60 HP drone is `max_hp = 600`. The armour table multiplies by an integer percentage and divides by 100, so small numbers lose real damage to truncation — 9 kinetic vs heavy floors to 6 instead of 6.3, a 4.8% penalty the table never asked for. Keep new content on this scale. Credits, bounties and lives are *not* scaled.

**New tower:** copy `data/towers/arc_cannon.tres`, change `id`, `display_name` and the numbers. It appears in the build bar automatically (the HUD reads `Catalog.tower_ids()`).

**New enemy:** copy `data/enemies/drone.tres`. Reference it by `id` from a spawn group.

**New wave:** copy `data/waves/wave_01.tres`. Each `SubResource` is one `SpawnGroup`; groups run in parallel. Add the wave `id` to a map's `wave_ids`.

**New map:** add `data/maps/<name>.layout.txt` (ASCII board) plus `data/maps/<name>.tres` pointing at it via `layout_path`.

Layout legend — rows must all be the same length, exactly one `S` and one `G`:

```
.  buildable ground      #  enemy path
X  blocked scenery       S  spawn (walkable)      G  goal (walkable)
```

After any content change, `test_content.gd` must still pass. It checks cross-references, that every damage type and armour type is represented, and that wave 1 is neither unwinnable nor free.

---

## 5. Definition of done

A change is not finished until **all** of these hold:

1. `godot --headless --path . --script res://tests/run_tests.gd` exits 0.
2. `godot --headless --path . --script res://tests/run_autoplay.gd` exits 0 and prints no `ERROR:` lines. This is the only check that executes `game/views/`.
3. `godot --headless --path . --quit-after 600` prints no `ERROR:` or `SCRIPT ERROR:` lines.
4. New behaviour in `sim/` has a test in `tests/cases/`. Untested sim logic is not done.
5. Public functions are statically typed (`func f(x: int) -> bool:`). No bare `var` in new code where a type is knowable.
6. No new warnings introduced. `untyped_declaration` is on in `project.godot`.
7. `AGENTS.md` / `docs/` updated if you changed a rule, a command, or the layout.

Do not commit `.godot/`, `build/`, or exported binaries.

---

## 6. Conventions

* **Indentation is tabs.** Godot's parser rejects mixed indentation — never introduce spaces into a `.gd` file.
* `snake_case` for files, functions, variables. `PascalCase` for `class_name`. `SCREAMING_SNAKE` for constants.
* Prefix private members with `_`.
* Cross-file references use `const Foo := preload("res://path/to/foo.gd")` rather than bare global class names. The global class cache is generated at import time and may not exist in a clean CI checkout; `preload` always works. Keep the `class_name` declarations too — the editor and `.tres` files use them.
* Comment **why**, not what. `## ` doc comments on public API, `# ` for inline reasoning.
* Prefer adding a field to a schema over adding a branch in `simulation.gd`.

---

## 7. Testing

Tests live in `tests/cases/` and are discovered automatically — any file there is loaded, instantiated, and every `test_*` method is run. Extend the base class:

```gdscript
extends "res://tests/test_case.gd"

const Fixtures := preload("res://tests/support/fixtures.gd")

func before_each() -> void:
    pass

func test_thing_does_the_thing() -> void:
    assert_eq(2 + 2, 4, "arithmetic still works")
```

Available assertions: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_almost_eq`, `assert_gt`, `assert_lt`, `assert_null`, `assert_not_null`, `assert_empty`.

Use `tests/support/fixtures.gd` to build content in code rather than depending on shipped `.tres` balance values — otherwise a balance tweak breaks a logic test. `tests/cases/test_content.gd` is the one suite that deliberately does test shipped data.

**`tests/cases/test_determinism.gd` is a release blocker.** If it fails, you have broken replays, save games and reproducible bug reports simultaneously. Fix the cause; never relax the assertion.

**`tests/run_autoplay.gd` is the only thing that runs the view layer.** Test cases extend `RefCounted` and never build a node, so nothing in `tests/cases/` can catch a broken `game/views/*.gd`. The autoplay runner plays a full match against the real `Level` and `Hud`, and every frame asserts that the number of view nodes equals the number of live entities in the sim — views are created and destroyed only from drained events, so a mismatch means an event went missing and a mesh is orphaned. If you add an event that creates or destroys a view, it belongs in that invariant.

---

## 8. What not to do

* Don't add engine dependencies to `sim/`.
* Don't call `Simulation.step()` anywhere except `game/main.gd`.
* Don't hardcode balance numbers in `.gd` files — they belong in `data/`.
* Don't use `localStorage`-style ad-hoc persistence; save/load is a backlog item with a designed shape (see `docs/BACKLOG.md`).
* Don't add addons, plugins, or dependencies without a note in `docs/ARCHITECTURE.md` explaining why the standard library was insufficient.
* Don't reformat files you aren't otherwise changing.
* Don't commit large binary assets without adding them to `.gitattributes`.

---

## 9. Current state

A working vertical slice: one map, three towers, four enemy types, five waves, build/sell, wave pacing, win and lose conditions, and a headless test suite covering the whole simulation layer.

What it is **not** yet: content-complete, balanced, saved, localised, audio-equipped, or Steam-integrated. `docs/BACKLOG.md` holds the prioritised list, roughly in the order it should be tackled.
