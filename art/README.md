# art/ — procedural models

Every model in this game is a Python script. There are no `.blend` files, and there should not be.

```
art/lib/studio.py        Shared bmesh helpers, materials, export
art/towers/<id>.py       One script per tower
art/build_all.py         Rebuild everything headlessly
art/reload.py            Rebuild one model inside a running Blender (Alt+P)
                             ↓
data/models/<kind>/<id>.glb    Build output, committed to git
```

## Why scripts instead of .blend files

A `.blend` is opaque to everything except Blender. You cannot diff it, an agent cannot reason about it, and a change to a shared style decision means opening twenty files by hand. A script is reviewable, regenerable, and lets "make every tower 10% shorter" be a one-line edit in `studio.py`.

The cost is that you cannot sculpt. For a low-poly stylised game where forms are boxes, cylinders and bevels, that cost is close to zero. If a model ever genuinely needs hand-sculpting, commit the `.blend` next to the script and say so in the script's docstring — but expect that to be rare.

The `.glb` files are committed. CI then needs Godot but not Blender, which keeps the pipeline fast; rebuilding artefacts that change once a month is not worth tripling the CI job.

## Building

```powershell
scripts\build_art.ps1        # rebuild every model, no Blender window
```

```bash
scripts/build_art.sh
blender -b --python art/build_all.py
```

Reopen the Godot editor afterwards so it reimports the changed `.glb` files.

## Iterating

1. Blender → **Scripting** tab → **Text → Open** → `art/reload.py`
2. Set `MODEL` to the script you're working on
3. Set `EXPORT = False` while pushing shapes around — no need to churn a binary on every tweak
4. Edit the model script, press **Alt+P**, look

`reload.py` drops the cached `studio` module each run, so edits to shared helpers take effect without restarting Blender.

`studio.preview_viewport()` points the viewport at the model from roughly the angle `game/rts_camera.gd` uses. Judge silhouettes from there. A level-on close-up flatters shapes that will actually be seen from above at distance, which is how the first Arc Cannon ended up as a squat plinth with an invisible turret.

## Maps are assembled in Godot, not in Blender

Blender builds the **kit** — terrain slabs, placement pads, trees, rocks. `game/board.gd` **assembles** the board from `data/maps/*.layout.txt` at load time.

This is deliberate. That layout file is already the sim's source of truth: the pathfinder walks it, `MapDef.is_valid()` checks it, and the tests assert against it. A map hand-built in Blender would be a second description of the same thing, and the two would drift the first time someone moved a corridor — leaving a board that looks one way and routes another. That bug is invisible in a screenshot.

Assembling procedurally also means authoring a new map stays one text file. It gets terrain, a forested border, pads and scatter for free.

`art/preview_map.py` renders the same assembly inside Blender so the board can be reviewed without launching Godot. It reimplements the placement rules rather than sharing them; if the two disagree, **`game/board.gd` is correct**.

## Rules

**Use bmesh, never `bpy.ops` for geometry.** Operators depend on UI context and behave differently headless. `studio.py` wraps the bmesh calls you need.

**Never call settings-level operators.** `bpy.ops.wm.read_factory_settings()` in particular — it reloads preferences, unregisters every addon, and destroys the window context the exporter needs. `studio.reset_scene()` purges datablocks instead.

**Blender is Z-up, Godot is Y-up.** The exporter maps Blender `+Z → Godot +Y` and Blender `-Y → Godot +Z`. So anything that must point along Godot's forward is modelled pointing along Blender `-Y`. `studio.FORWARD` is that axis.

**Node names are a contract.** `game/views/tower_view.gd` finds `Base`, `Turret` and `Barrel` by name and drives them. Renaming any of those silently breaks turret rotation and recoil — the model still renders, it just stops moving. `Turret` must be an empty (a pivot); geometry parented directly to the pivot gets the recoil offset applied twice.

**Models carry no colour.** `TowerDef.body_color` / `accent_color` are applied as `material_override` in Godot, so `data/towers/*.tres` stays the single source of truth for palette. Materials in `studio.py` exist only to make the Blender preview readable.

**Mirror about the parent, not the part.** `studio.mirror_x(obj, about=...)` — Blender's Mirror modifier with no `mirror_object` mirrors around the object's *own* origin, so an off-centre part folds onto itself instead of pairing. This shipped a single-barrelled Arc Cannon that looked almost right. `mirror_x` defaults `about` to the parent, which is usually correct; pass it explicitly when the parent is itself off-centre.

**Stay inside the tile.** One grid cell is `2.0` world units (`studio.CELL_SIZE`). Keep towers' *bases* under about `1.8`. Barrels may overhang — turrets rotate, so a sweeping barrel over a neighbouring tile is expected.

**Enemies stand on the ground and end near `EnemyDef.height`.** `enemy_view.gd` puts the health bar at `height + 0.45`, so a model whose top is far below its def height gets a bar floating in space, and one that dips below `z = 0` clips through the board. Check both with a bounding-box pass after any proportion change — that check caught a Brute that was shorter than a Walker.

## Adding a model

Copy `art/towers/arc_cannon.py`. It must expose:

- `build()` returning the root object
- `OUTPUT_PATH`, the repo-relative `.glb` destination

Then set `mesh_path` on the matching `.tres`. Leave `mesh_path` empty and the view layer falls back to generated primitives, so an unmodelled tower is still playable.
