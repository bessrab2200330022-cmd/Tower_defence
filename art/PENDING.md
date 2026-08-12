# PENDING — .tres edits awaiting the lead

A5 owns `art/**` and `data/models/**`. **No `.tres` file was opened or written
this session** — A3 is rewriting `data/towers/` and A2 is writing
`data/enemies|waves|maps/` in parallel, and there is no per-agent branch yet.
Everything the art lane needs from a resource is recorded here as a one-line
edit for the lead.

Delete an entry once it has landed. Nothing in `art/` depends on any of these to
build: a model with no def is inert, and both view scripts fall back to
primitives, so an unwired tower or enemy stays playable.

Last updated: 13 Aug 2026 — round 2, tier meshes.

---

## 1. Nine tier meshes — A3 is already writing these files

A3 owns `data/towers/**` this round and `docs/ROUND-2.md` tells it to set
`mesh_path` on the nine new defs. **All nine `.glb` now exist**, so those paths
resolve — no fallback needed. Nothing for the lead to do unless A3 skipped it:

```
data/towers/arc_cannon_t2.tres     mesh_path = "res://data/models/towers/arc_cannon_t2.glb"
data/towers/arc_cannon_t3a.tres    mesh_path = "res://data/models/towers/arc_cannon_t3a.glb"
data/towers/arc_cannon_t3b.tres    mesh_path = "res://data/models/towers/arc_cannon_t3b.glb"
data/towers/plasma_lance_t2.tres   mesh_path = "res://data/models/towers/plasma_lance_t2.glb"
data/towers/plasma_lance_t3a.tres  mesh_path = "res://data/models/towers/plasma_lance_t3a.glb"
data/towers/plasma_lance_t3b.tres  mesh_path = "res://data/models/towers/plasma_lance_t3b.glb"
data/towers/frost_mortar_t2.tres   mesh_path = "res://data/models/towers/frost_mortar_t2.glb"
data/towers/frost_mortar_t3a.tres  mesh_path = "res://data/models/towers/frost_mortar_t3a.glb"
data/towers/frost_mortar_t3b.tres  mesh_path = "res://data/models/towers/frost_mortar_t3b.glb"
```

`mesh_scale = 1.0` on all nine. Every tier is modelled at true scale against the
2.0 grid cell; nothing needs rescaling and a non-1.0 value here would mean a
model is wrong, not that a number needs tuning.

**`plasma_lance_t3b` (Fork Array) is built even though the fork mechanic is
deferred.** If A3 ships the Lance temporarily linear — `upgrade_ids` with one
entry — the mesh simply sits unused. It costs nothing to leave on disk and it
is what Prime Focus was designed against; see §4.

---

## 2. Tier accent colours — `accent_color` / `effect_color`

`voice.md` §3 fixes the accent identity per branch and leaves the exact values
to A1/A5. These are my proposals, derived from the shipped base-tower values so
each family stays recognisably itself.

| def_id | `body_color` | `accent_color` | `effect_color` |
| --- | --- | --- | --- |
| `arc_cannon_t2` | `Color(0.35, 0.65, 0.95, 1)` | `Color(0.95, 0.85, 0.45, 1)` | `Color(1, 0.85, 0.5, 1)` |
| `arc_cannon_t3a` | `Color(0.35, 0.65, 0.95, 1)` | `Color(0.97, 0.95, 0.88, 1)` | `Color(1, 0.98, 0.92, 1)` |
| `arc_cannon_t3b` | `Color(0.35, 0.65, 0.95, 1)` | `Color(1, 0.62, 0.24, 1)` | `Color(1, 0.55, 0.18, 1)` |
| `plasma_lance_t2` | `Color(0.55, 0.4, 0.9, 1)` | `Color(0.6, 0.95, 1, 1)` | `Color(0.55, 0.85, 1, 1)` |
| `plasma_lance_t3a` | `Color(0.55, 0.4, 0.9, 1)` | `Color(0.94, 0.96, 1, 1)` | `Color(0.97, 0.98, 1, 1)` |
| `plasma_lance_t3b` | `Color(0.55, 0.4, 0.9, 1)` | `Color(0.35, 0.95, 1, 1)` | `Color(0.3, 0.92, 1, 1)` |
| `frost_mortar_t2` | `Color(0.45, 0.8, 0.85, 1)` | `Color(0.9, 0.98, 1, 1)` | `Color(0.75, 0.95, 1, 1)` |
| `frost_mortar_t3a` | `Color(0.45, 0.8, 0.85, 1)` | `Color(0.42, 0.55, 0.95, 1)` | `Color(0.35, 0.5, 0.95, 1)` |
| `frost_mortar_t3b` | `Color(0.45, 0.8, 0.85, 1)` | `Color(0.78, 0.84, 0.88, 1)` | `Color(0.8, 0.86, 0.9, 1)` |

Reading of `voice.md` §3: "Arc family stays warm brass; **Hailstorm sparks
white, Railshot burns orange**. Lance family stays cold violet; **Prime Focus
goes near-white, Fork Array splits cyan**. Mortar family stays glacial blue;
**Glacier deepens toward ultramarine, Shatterhead pales toward steel**."

`body_color` is deliberately **unchanged within each family** at every tier.
The family is the body colour; the branch is the accent. A player should read
"that is a Lance" from across the board and "that is a Prime Focus" on a second
look, and moving the body colour up-tier would collapse those two reads into
one.

*Note:* `voice.md` says the Arc family is "warm brass", but `arc_cannon.tres`'s
`body_color` is blue and only its `accent_color` is brass. I have followed the
shipped `.tres`, not the sentence. Worth settling in `voice.md` either way.

---

## 3. The accent prefix hazard — A4, and this one can break shipped towers

`docs/ROUND-2.md` gives A4 item 4: replace exact-name accent matching with
`Body*` / `Accent*` prefix matching. **At the time these nine models were built
that had not landed** — `game/views/tower_view.gd` still reads:

```gdscript
const BODY_PARTS: Array = ["Base", "Plinth", "TurretHead"]
const ACCENT_PARTS: Array = ["AmmoDrum", "Sight", "Muzzle"]
```

**A pure prefix swap breaks all three shipped towers.** None of `Base`,
`Plinth`, `TurretHead`, `AmmoDrum`, `Sight` or `Muzzle` begins with `Body` or
`Accent`, so replacing the lists outright would leave every existing tower
untinted. And `Base` cannot be renamed to fix it: `tower_view.gd:89` finds it by
name to drive the tower, so it is a behaviour contract, not just a tint entry.

**Recommended: make it additive, not a replacement** — match the existing
literal list **OR** the prefix:

```gdscript
if name in BODY_PARTS or name.begins_with("Body"):   -> body_color
if name in ACCENT_PARTS or name.begins_with("Accent"): -> accent_color
```

The nine tier meshes are named to survive **either** decision:

- Body parts use the exact names `Base` / `Plinth` / `TurretHead` — correct today.
- Every tier carries exactly one node named `Muzzle`, so at least one accent
  part is tinted under today's list.
- All other accent detail is named `Accent<Thing>` — 2 to 12 nodes per tier —
  which stays on its exported neutral metal until prefix matching lands and
  tints correctly the moment it does.

If A4 does go pure-prefix, the follow-up is a mechanical rename of the three
base towers' `AmmoDrum` / `Sight` / `Muzzle` and a special case for `Base`. That
is my lane and one edit; just tell me which way it landed.

Also still open from last round: `_tint()` uses `find_child(name, true, false)`,
which returns only the **first** match. Hailstorm has six barrel tubes and
Glacier has eight vanes — under exact matching only one of each would ever tint.
Prefix matching should iterate all matches, or the multi-part tiers stay
half-grey.

---

## 4. Measured tier ladder — parsed from the exported `.glb`, not from the log

| def_id | name | height | width | depth | base w | rank pips |
| --- | --- | --- | --- | --- | --- | --- |
| `arc_cannon` | — | 1.590 | 1.575 | 2.385 | 1.570 | 0 |
| `arc_cannon_t2` | Overclock | **1.760** | 1.680 | 2.526 | 1.611 | 1 |
| `arc_cannon_t3a` | Hailstorm | **1.900** | 1.660 | 1.966 | 1.651 | 2 |
| `arc_cannon_t3b` | Railshot | **1.965** | 1.532 | **3.390** | 1.532 | 2 |
| `plasma_lance` | — | 2.010 | 1.212 | 2.660 | 1.380 | 0 |
| `plasma_lance_t2` | Focused Array | **2.283** | 1.275 | 2.800 | 1.452 | 1 |
| `plasma_lance_t3a` | Prime Focus | **2.620** | 1.344 | 2.220 | 1.532 | 2 |
| `plasma_lance_t3b` | Fork Array | **2.519** | 1.309 | 2.386 | 1.492 | 2 |
| `frost_mortar` | — | 1.709 | 1.701 | 1.915 | 1.701 | 0 |
| `frost_mortar_t2` | Deep Barrel | **1.892** | 1.721 | 1.771 | 1.721 | 1 |
| `frost_mortar_t3a` | Glacier | **1.761** | 1.741 | 1.741 | 1.741 | 2 |
| `frost_mortar_t3b` | Shatterhead | **2.055** | 1.581 | 1.819 | 1.581 | 2 |

Every tier stands on the ground (floor 0.000), keeps its `Base` under the 1.8
tile limit, and exports `Base` / `Turret` / `Barrel` / `Plinth` / `TurretHead` /
`Muzzle`. Nine meshes, 9,752 triangles total.

**Glacier is deliberately shorter than Deep Barrel** (1.761 vs 1.892) — it is
the branch that converts its purchase into area and duration rather than
damage, and `upgrades.md` §8 asks for "a broad squat mortar". It is still above
the un-upgraded mortar, which is the line that must not be crossed.

**Railshot is 3.390 deep** — by far the longest thing on the board, which is the
only way range 12 gets a silhouette. It sweeps roughly one tile either side of
its pad when the turret rotates. `art/README.md` explicitly permits barrel
overhang, but it is worth knowing before someone reports it as clipping.

---

## 5. Still open from earlier rounds

1. **Skiff cruise altitude.** `enemies.md` says "at fixed cruise height" and
   never gives the number. The model carries a built-in 0.42 float so it reads
   as airborne without the air lane, but the real altitude is A3's and the
   health bar rides on it.
2. **Fission Spawn has no model.** `enemies.md` §2 defines it as a full enemy
   def (450 HP, speed 6.5, Light). Not built — it was the stretch goal and the
   tier work took the session. Cheap when wanted: `fission_crawler.py` is two
   calls to `build_segment()` precisely so the child can be one segment of its
   parent.
3. **`EnemyDef.body_color` is inert for modelled enemies.** `_setup_from_mesh`
   never tints; only the primitive fallback reads it. That is why every enemy
   model bakes its colour. `shielded_scout.tres` has already drifted from its
   model (`0.35,0.75,0.9` declared vs `0.2,0.42,0.55` baked).
4. **Snow kit and `crystal.glb` are scattered by nobody.**
   `board.gd::_scatter_props()` hardcodes seven grassland paths. Deferred by
   lead ruling to ride with the Fork map.
