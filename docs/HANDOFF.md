# Handoff — start here

You are joining **Bastion Line**, a deterministic 3D tower defence game in Godot 4.7 / GDScript, aimed at a Steam release. Several agents work on this repo in parallel. This file exists so you can start without re-deriving what already exists, and without colliding with whoever else is working right now.

**Read [AGENTS.md](../AGENTS.md) before your first edit.** It is the canonical contract: architecture rules, commands, conventions, definition of done. This file does not repeat it — duplicating rules is exactly how two agents end up working from two subtly different sets of them.

---

## 1. Orient yourself (5 minutes, in this order)

| File | What it gives you |
| --- | --- |
| `AGENTS.md` | The rules. Non-negotiable. |
| `docs/ARCHITECTURE.md` | Why the code is shaped this way. Read the sim/view split section at minimum. |
| `docs/BACKLOG.md` | The short queue, plus a **Done** list of what has already shipped and why. |
| `docs/ROADMAP.md` | The longer view. |
| `art/README.md` | Only if you are touching models or the board. |

Then run the gates and confirm they are green **before** you change anything. If they are already red, that is your first finding and you should report it rather than building on top of it.

```bash
godot --headless --path . --import                              # once, after a fresh clone
godot --headless --path . --script res://tests/run_tests.gd     # the gate — must exit 0
godot --headless --path . --script res://tests/run_autoplay.gd  # the view-layer gate
```

Windows, no PATH setup needed: `scripts\test.bat`, `scripts\play.bat`, `scripts\smoke.bat`.

---

## 2. The three things that will bite you

**`sim/` is pure.** No `Node`, no `SceneTree`, no engine `delta`, no `randi()`, integer money and integer damage. Time advances only through `Simulation.step()`, called from exactly one place (`game/main.gd`). Break this and the tests stop being able to run the game headless, which is the property everything else depends on.

**`tests/cases/test_determinism.gd` is a release blocker.** If it fails, fix the cause. Never relax the assertion, never lower the tick count.

**Nothing in `tests/cases/` builds a node.** They are fast because they never touch the scene tree, and structurally blind to `game/` for the same reason. `tests/run_autoplay.gd` is the only check that executes the view layer — it plays a real match through a real `Level` and `Hud` and asserts view counts match sim entity counts every frame. **Run it before calling any view work done.**

---

## 3. Pick a lane

> **If you were given a workstream (W0–W7), read [WORKSTREAMS.md](./WORKSTREAMS.md) instead of this section.** It supersedes the lane table below with a fuller assignment: which agent suits which work, what depends on what, and what order to do it in. The lanes here are the same idea at lower resolution, kept for anyone working solo.

Parallel agents collide on files, not on ideas. Each lane below lists the files it owns. **Stay inside your lane's files.** If your work genuinely needs a file from another lane, say so in your summary rather than editing it quietly.

| Lane | Owns | Good first tasks |
| --- | --- | --- |
| **A — Simulation & balance** | `sim/**`, `data/**`, `tests/cases/**` | Tower upgrades (backlog 1), balance pass (backlog 5), save/load (backlog 7) |
| **B — Gameplay UI** | `game/ui/**`, `game/main.gd` | Tower selection and inspection (backlog 2), main menu and pause (backlog 8), settings |
| **C — Rendering & feel** | `game/lighting.gd`, `game/rts_camera.gd`, `game/views/**` | Render interpolation (backlog 3), audio (backlog 6), effects polish |
| **D — Art pipeline** | `art/**`, `data/models/**` | New tower/enemy models, upgrade-tier visuals, prop kit expansion |
| **E — Content** | `data/maps/**`, `data/waves/**` | New maps (backlog 4), wave design |
| **F — Build & release** | `.github/**`, `scripts/**`, `export_presets.cfg`, `docs/STEAM.md` | Export in CI (backlog 15), Steamworks wrapper (backlog 13) |

Shared, touched by nearly everything, so **coordinate before editing**: `game/level.gd`, `game/board.gd`, `AGENTS.md`, `docs/BACKLOG.md`.

Two lanes that are safe to run at the same time as anything: **A** and **D**. They meet only through `.tres` field names.

---

## 4. Current state

**Working:** one map, three towers, four enemy types, five waves, build/sell, win/lose. Deterministic simulation. Ten test suites plus a view-layer autoplay runner. CI runs tests, a headless boot and autoplay on every push.

**Art:** every model is a Python script in `art/` that builds geometry procedurally and exports `.glb`. There are no `.blend` files — the script *is* the asset. Node names (`Base`, `Turret`, `Barrel`) are a contract with `game/views/tower_view.gd`; renaming one leaves the model rendering but not moving.

**Board:** `game/board.gd` assembles terrain, scatter props and a floating island from the same `data/maps/*.layout.txt` the pathfinder walks. Building a map in Blender was rejected — it would be a second source of truth for the grid.

**Rendering:** `game/lighting.gd` — procedural sky, sun with angular penumbra, SSAO, SSIL, SDFGI, screen-space reflections, ACES tonemapping, bloom. Three-step quality enum; drop to `MEDIUM` if frame rate is a problem, which removes SDFGI first.

**Not done yet:** upgrades, save/load, audio, menus, localisation, accessibility, Steam integration, and any real balance work. Only one map exists.

---

## 5. Finishing

A change is done when **all** of these hold — this is the same list as `AGENTS.md` §5, repeated because it is the thing most often skipped:

1. `run_tests.gd` exits 0
2. `run_autoplay.gd` exits 0 (mandatory if you touched anything under `game/`)
3. New behaviour in `sim/` has a test
4. Public functions are statically typed
5. `docs/BACKLOG.md` updated — item moved to **Done** with a one-line note on *what was actually wrong or what was learned*, not just "did the thing"

That last point is the one that makes the next agent's job easier. The Done entries are the project's memory.

---

## 6. Handing back

End your session with:

- What changed, in one paragraph
- Which lane you worked in and which files you touched
- Anything you found but did not fix
- **Anything you could not verify.** Agents here often cannot run Godot. Saying "unverified: I changed `enemy_view.gd` and could not execute the autoplay gate" is far more useful than silence, because it tells the human exactly what to check.

---

## 7. Starter prompt

Paste this into a fresh chat, with the project folder open:

> This is the Bastion Line tower defence project. Read `docs/HANDOFF.md`, then `AGENTS.md`, then `docs/BACKLOG.md`. Run the test suite and the autoplay gate and confirm they are green before changing anything. I want you to work in **lane \_\_** on **\_\_**. Stay inside that lane's files; tell me if you need to touch a shared one.
