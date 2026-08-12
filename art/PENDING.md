# PENDING — .tres edits awaiting the lead

A5 owns `art/**` and `data/models/**` and does not edit `.tres` files. Every
resource change the art lane needs is recorded here for the lead to apply.

Delete an entry once it has landed. **Nothing in `art/` depends on these edits
to build** — a model with no def is inert, not broken, and the view layer's
primitive fallback keeps an unwired enemy playable.

Last updated: 12 Aug 2026 · session: five new enemy models + the F1 tint fix.

---

## 1. Five new enemy defs — NEW FILES

The models exist and are exported. The defs do not exist yet.

Balance fields (`max_hp`, `speed`, `armor_type`, `bounty`, `leak_damage`) are
A3's and are specified in `docs/design/enemies.md` §2 — not repeated here, so
there is one source of truth. Below is **only** the `Presentation` group.

| id | `mesh_path` | `mesh_scale` | `shell_node` | `body_color` | `radius` | `height` |
| --- | --- | --- | --- | --- | --- | --- |
| `courser` | `res://data/models/enemies/courser.glb` | 1.0 | `""` | `Color(0.95, 0.58, 0.3, 1)` | 0.40 | **0.53** |
| `skiff` | `res://data/models/enemies/skiff.glb` | 1.0 | `""` | `Color(0.88, 0.55, 0.42, 1)` | 0.55 | **1.00** |
| `warden` | `res://data/models/enemies/warden.glb` | 1.0 | **`"Field"`** | `Color(0.3, 0.62, 0.85, 1)` | 0.46 | **1.46** |
| `mender` | `res://data/models/enemies/mender.glb` | 1.0 | `""` | `Color(0.78, 0.42, 0.5, 1)` | 0.45 | **1.38** |
| `fission_crawler` | `res://data/models/enemies/fission_crawler.glb` | 1.0 | `""` | `Color(0.72, 0.38, 0.48, 1)` | 0.52 | **0.97** |

**`height` is not a preference — it is measured.** Each value is the model's
actual crown from a bounding-box pass on the exported `.glb`. The health bar
hangs at `height + 0.45`, so a def that disagrees with its model puts the bar
in the wrong place. Verified gap across all five: 0.448–0.460, against
0.456–0.489 for the shipped roster. Change a `height` here and the model has to
move with it.

`radius` is a gameplay footprint rather than a visual bound, so these are
proposals — A3 should overrule them if splash or collision wants otherwise.
They sit at 0.70–1.0 of each model's half-width, matching the shipped ratio.

**`body_color` is currently decorative for modelled enemies — see §4.** The
values above are what the models actually bake, so a def carrying them is at
least honest.

### Height ladder, measured — please keep this order

    courser 0.526 · drone 0.581 · crawler 0.970 · skiff 0.990 · scout 1.094
    walker 1.173 · mender 1.380 · warden 1.462 · brute 1.564

Three of those spacings are load-bearing and a retune should not casually cross
them:

- **Courser below Drone.** `enemies.md` §6 asks for "the lowest silhouette in
  the game". It first built at 0.591, above the Drone, and was corrected.
- **Brute above Warden**, by 0.10. WORKSTREAMS names "the Brute must be visibly
  the tallest thing on the board" as one of the two things in this project that
  cannot be written down. The Warden first built at 1.556 against the Brute's
  1.564 — a tie — and was brought down to 1.46.
- **Mender above Walker.** The Mender hides in a Walker column in wave 9 and
  must be pickable out of it. Note it currently clears the Walker's *model* by
  0.21 but its *def* by only 0.08 — see §3.

---

## 2. Waves 6–10

No action yet. `enemies.md` §8 gates each enemy behind sim work (2.4/2.5/2.6),
and the catalog cross-reference check will reject a wave naming an enemy that
does not exist. **The Courser needs nothing** — `enemies.md` §2: "Sim needs:
None. Pure data." It can go into wave 7 as soon as its def lands.

---

## 3. Existing defs — one correction requested

**`data/enemies/walker.tres` — `height = 1.3`, but the model's crown is 1.173.**

The bar floats 0.577 above the Line Walker's head where every other enemy in
the game sits at 0.444–0.489. Root cause is in my lane and not yours:
`art/enemies/walker.py` hardcodes `HEIGHT = 1.1` while the def says 1.3, and
every proportion derives from that constant.

Two ways to close it, and **the choice is yours because it is visible**:

- **(a) Fix the model** — raise `walker.py`'s `HEIGHT` so the crown lands at
  1.30. No `.tres` edit. The Walker gets slightly taller on screen, and the
  Mender's clearance over it drops from 0.21 to 0.08.
- **(b) Fix the def** — set `height = 1.18`. No rebuild. The Walker stays as it
  looks today and the Mender keeps its clearance.

I lean to **(b)**: nothing about the Walker looks wrong right now, the roster is
drawn against its current size, and (a) quietly shrinks the gap the Mender
depends on. But (a) is the one that makes the def honest. Say which and I will
do it.

---

## 4. Two seams that are not mine to close

### `EnemyDef.body_color` does nothing for a modelled enemy — for A4

`game/views/enemy_view.gd::_setup_from_mesh()` instantiates the `.glb`, applies
`mesh_scale`, applies `shell_node` translucency, and never tints. `body_color`
is only read by `_setup_from_primitive()`. Every enemy sets `mesh_path`, so
every enemy's colour comes from the material baked into the mesh by
`studio.py`, and the def field is inert.

Walker, Brute and Drone only *look* correct because the value was hand-copied
into both files. It has already drifted once: `shielded_scout.tres` declares
`Color(0.35, 0.75, 0.9)` while the model bakes `(0.2, 0.42, 0.55)`. Nothing
catches it.

Either enemies get a tint pass like towers, or `body_color` is documented as
fallback-only and the model becomes the source of truth. Worth settling before
six more enemies are built on the ambiguity — and it matters for the
colourblind pass (BACKLOG 12), which will want one place to change a palette.

### `ACCENT_PARTS` misses two towers — for A4

I fixed the body half of this in `art/` this session: `tower_view.gd` tints
`BODY_PARTS = ["Base", "Plinth", "TurretHead"]` **by node name**, and the Frost
Mortar called its body mass `Drum` while the Plasma Lance called its shaft
`Pylon`, so neither ever received `body_color`. Both are now named `Plinth` and
both hand-tinted `Hull` colours are back to neutral. **No `.tres` edit needed
and `mesh_path` is unchanged.**

The accent half cannot be fixed the same way. `ACCENT_PARTS = ["AmmoDrum",
"Sight", "Muzzle"]` — only the Arc Cannon has all three. Unreached today:

| Tower | Parts that should take `accent_color` but do not |
| --- | --- |
| Frost Mortar | `CoolantTank` |
| Plasma Lance | `Capacitor`, `CapacitorRear`, `Fin` |

Renaming a coolant tank to `AmmoDrum` would be a lie in the source, so this one
wants A4 to extend the list. Cheapest durable fix is prefix matching —
`Accent*` / `Body*` — which would also stop the next new tower silently
shipping grey.

**Unverified:** I cannot run Godot, so the `Plinth` fix is confirmed only at
the mesh level (both `.glb` files now export a node named `Plinth`). Someone
should look at a placed Plasma Lance and confirm its shaft takes the def's
violet.

---

## 5. Open questions blocking further art

1. **Skiff cruise altitude.** `enemies.md` says "straight line, spawn to goal,
   at fixed cruise height" and never gives the number. The model carries a
   built-in 0.42 float so it reads as airborne even on a build without the air
   lane, but the real altitude is A3's and the health bar rides on top of it.
2. **Fission Spawn has no model and is not in my brief.** `enemies.md` §2
   defines it as a full enemy def (450 HP, speed 6.5, Light) and `voice.md` §4
   gives it canon text, so it needs a `mesh_path` like any other. I did **not**
   build it — the brief said five. It is cheap when you want it:
   `fission_crawler.py` is built from a `build_segment()` function called twice,
   precisely so the child can be one segment of its parent. Say the word.
3. **Warden aura film.** `enemies.md` §6 wants the aura drawn as a translucent
   film over *protected escorts*, generalising `shell_node`. That is view work
   (A4), not a model. The Warden's own `Field` globe is wired and ready.

---

## 6. Applied this session — no action needed, recorded for the log

- `art/towers/frost_mortar.py` — `Drum` → `Plinth`, `Hull` colour neutralised.
- `art/towers/plasma_lance.py` — `Pylon` → `Plinth`, `Hull` colour neutralised.
- Both `.glb` rebuilt. Node contracts re-verified: `Base`, `Turret`, `Barrel`,
  `Plinth`, `TurretHead`, `Muzzle` all present in both.
- `art/preview_roster.py` — new. Lines the whole enemy roster up at the RTS
  angle, ordered by measured height, so silhouettes can be judged comparatively.
  Lives at `art/` top level, so `build_all.py::discover()` does not sweep it.
