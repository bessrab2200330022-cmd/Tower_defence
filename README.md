# Bastion Line

A deterministic 3D tower defence game built in Godot 4.7 with GDScript, structured so that the majority of the code can be written and verified by coding agents.

## Getting started

Install [Godot 4.7](https://godotengine.org/download) (standard build, not .NET) and make sure `godot` is on your `PATH`.

```bash
godot --headless --path . --import                              # one-time, builds the import cache
godot --headless --path . --script res://tests/run_tests.gd     # run the tests
godot --headless --path . --script res://tests/run_autoplay.gd  # play a match headless
godot --path .                                                  # play
```

Or open the folder in the Godot editor and press F5.

**Windows, without touching a terminal:** double-click `scripts\play.bat` to run the game, `scripts\test.bat` to run the suite, or `scripts\autoplay.bat` to watch a whole match resolve headless. They locate `godot.exe` themselves and cache the result; `scripts\where_is_godot.bat` reports what it found.

**Tests from inside the editor:** open `tests/run_tests_in_editor.tscn` and press **F6**. Results appear in the Output panel. Same suites as CI — both go through `tests/runner_core.gd`.

## Controls

| Input | Action |
| --- | --- |
| `1` `2` `3` | Select a tower to build |
| Left click | Place the selected tower / sell in sell mode |
| `X` | Toggle sell mode |
| `Space` | Start the next wave |
| `Esc` | Clear selection |
| `WASD` / arrows | Pan the camera |
| Right drag | Orbit — horizontal rotates, vertical tilts |
| Middle drag | Pan |
| Mouse wheel | Zoom |
| `Q` `E` | Orbit left / right |
| `R` `F` | Tilt down / up |
| `Home` | Reset the view |
| `P` | Pause |

## Layout

```
sim/     Pure, deterministic game logic. No engine dependencies. Unit tested.
data/    Towers, enemies, waves and maps as .tres files + ASCII map layouts.
game/    Godot nodes: rendering, camera, HUD, input.
tests/   Dependency-free headless test harness and suites.
docs/    Architecture notes, backlog, Steam release checklist.
.codex/  Sandbox setup script and task prompts for Codex.
```

## Working with agents

`AGENTS.md` is the contract every coding agent reads: architecture rules, commands, conventions, and the definition of done. `CLAUDE.md` points at it so both tools work from the same rules.

The critical property of this codebase is that the simulation is deterministic — same seed plus same commands produce the same result, tick for tick. That is what makes `tests/cases/test_determinism.gd` meaningful, and it is what lets an agent verify its own work instead of relying on you to play the game and report what broke.

## Status

Vertical slice: one map, three towers, four enemy types, five waves, working win/lose. See `docs/BACKLOG.md` for what comes next.
