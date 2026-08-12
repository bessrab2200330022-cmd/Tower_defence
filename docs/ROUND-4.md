# Round 4 — assignments

Paste one section into one chat.

**Two headline items.** The island underside and the sourceless waterfalls are a
reported visual bug that affects *every* map, because the geometry is generated in
`game/board.gd` rather than authored per map. And A3's round 3B did not run at all, so
multi-route, the prop table and exposure-seconds are all still open.

---

## The island bug — diagnosed, so nobody has to rediscover it

A screenshot shows two distinct defects. Both are in `game/board.gd`. Both are mine
from an earlier round; neither is anyone's regression.

**1. The underside reads as boxes passing through boxes.**

`_build_island_mass()` places 2–3 `BoxMesh` chunks per layer. The offset clamp only
stops a chunk escaping *the layer above it* — `parent_half_x` / `parent_half_z`.
**Nothing stops two chunks in the same layer from overlapping each other**, and with
`chunk_scale` running 0.68–0.98 against offsets up to the full remaining room, they
routinely do.

On its own an overlap would be invisible — it is rock inside rock. What makes it a
visible artefact is the line immediately below it:

```gdscript
shade = shade.lightened(float(rng.randi_range(-4, 6)) / 100.0)
```

Per-chunk shade jitter was added so neighbouring chunks separate visually instead of
merging into one silhouette. It does that — and it also draws a hard line exactly where
two chunks interpenetrate, which is what reads as "texture through texture". The jitter
is not the bug; it is the thing that reveals it.

**The fix is to partition, not to overlap.** Give each chunk in a layer its own
non-overlapping slice of that layer's footprint and jitter *within* the slice. The
silhouette stays irregular, no two boxes intersect, and the shade jitter goes back to
doing only the job it was added for. Do not fix this by removing the jitter — that
trades a seam for a flat grey wall, which is the artefact the jitter was introduced to
solve in the first place.

**2. The waterfalls pour out of solid ground.**

`_build_waterfalls()` places each fall on a ring:

```gdscript
var angle: float = TAU * float(i) / float(WATERFALL_COUNT) + 0.6
var edge := Vector3(centre.x + cos(angle) * island_x * 0.46, top + 0.4, ...)
```

It never consults the layout. Three falls appear at fixed bearings regardless of what
is above them, so water leaves a rim that has no river, no pool and no source. The
screenshot catches this exactly.

**The cheap correct fix: water is decoration on cells the sim already ignores.**
`BLOCKED` cells are non-walkable and non-buildable *today*. Rendering some of them as
water needs **no sim change, no layout change, and no pathfinder risk** — and it works
on both shipped maps immediately. Pick `BLOCKED` cells near the rim, render them as
animated water, and anchor each waterfall beneath one. A fall with a pool above it is
the whole fix.

Authored water — a designer placing a river deliberately — is the follow-up, and it is
also small: a `~` glyph that parses to `BLOCKED` and is remembered as a render hint.
That half is split between A3 and A2 below. **A4's half must work without it**, so the
bug is fixed even if the glyph slips a round.

---

# A4 — Opus 5 Max · The island, and the icons nobody loaded

You are A4 on **Bastion Line**, a deterministic 3D tower defence game in Godot 4.7.
You own the view layer. Read `AGENTS.md`, then `docs/ARCHITECTURE.md`.

**You own `game/**` and nothing else.**

Menus, `InputMap`, settings and pause all landed and The Corridor is finally reachable —
that was the biggest built-but-unusable gap in the project and it is closed.

## 1. The island underside and the waterfalls

Read the diagnosis at the top of this file first; it names the exact lines and the
exact cause, so this should be a fix rather than an investigation.

- **`_build_island_mass()`** — partition each layer into non-overlapping slices instead
  of letting chunks overlap. Keep the per-chunk shade jitter; it is doing a real job
  and is only incriminated because it reveals the overlap.
- **`_build_waterfalls()`** — source each fall from a cell that exists. Pick `BLOCKED`
  cells near the rim, render them as water, put the fall under one. **No sim change and
  no layout change** — `BLOCKED` is already non-walkable and non-buildable, so this is
  pure decoration and cannot affect a single test.
- **Animate the water.** A scrolling UV on the surface and on the falling sheet. The
  falls already have looping droplets; the flat water above them must not read as ice
  by comparison.
- If A3 lands the `~` glyph this round, prefer authored water cells over auto-selected
  ones and fall back to auto-selection when a map declares none. Do not block on it.

Both shipped maps have this bug and neither map file needs editing to fix it, which is
the point of doing it here.

## 2. Load the icons

A5 shipped a full icon set in the same window you built the surfaces that should show
them, so nothing references them. `game/ui/` currently contains **zero** occurrences of
`icon`, `texture` or `data/icons`, and `main_menu.gd` builds its map cards from
`Button.text` alone.

```
data/icons/towers/<def_id>.png       12, 256x256 RGBA
data/icons/towers/tint/<def_id>.png  12 tint masks
data/icons/maps/<map_id>.png          2 thumbnails
```

Read `art/PENDING.md` §1–2 first. A5 rendered the tint masks specifically so you can
tint icons at runtime the way `tower_view.gd` tints meshes, keeping `.tres` the single
source of palette. Decide whether you want that and say so either way — if you don't,
A5 should stop generating them.

Wire icons into the map cards, the build bar and the upgrade panel. **Check them at
icon size, not at full resolution** — if `arc_cannon` and `arc_cannon_t2` are
indistinguishable in a 64px square, the upgrade panel cannot do its job.

## 3. If there is room: the prop table consumer

`board.gd::_scatter_props()` hardcodes seven grassland paths, so A5's snow and desert
kits are built and scattered by nobody. A3 is adding the `MapDef` fields this round to
A5's spec in `art/PENDING.md` §1. If they land, consume them; the empty-means-grassland
fallback keeps existing maps unaffected.

## Definition of done

`run_autoplay.gd` exits 0 with **zero `ERROR:` and zero `WARNING:` lines**. Screenshot
the island from the same low angle as the bug report and judge it there — the defect is
only visible from below the horizon, which is exactly where a floating island puts the
camera.

## Report back

Before/after on the underside, how you sourced the waterfalls, your ruling on runtime
icon tinting, and whether the prop table had landed in time.

---

# A3 — Codex (Opus 5) · The round that did not run, plus one glyph

You are A3 on **Bastion Line**, a deterministic 3D tower defence game in Godot 4.7 /
GDScript. Read `AGENTS.md` first, then `docs/design/maps.md` §2–3.

**You own `sim/**`, `tests/**`, `data/schemas/**`, `data/towers/**`, `data/enemies/**`.
You must not open `game/**`, `art/**`, `data/waves/**` or `data/maps/**`.**

**Last round produced nothing.** No route enumeration in `sim/`, no `route_hint` on
`SpawnGroup`, no prop-table fields on `MapDef`, no exposure-seconds column, no new test
files. Three other agents shipped against briefs that assumed yours would land, so
A2's Fork content is staged with nowhere to go and two biome kits are scattered by
nobody. This is that brief again, unchanged, plus one small addition.

## 1. Multi-route pathfinding

`maps.md` §3 is written directly to you and is unusually specific. The requirement in
one line: **both routes see traffic, deterministically, under wave-data control.**

- **Route enumeration with stable ids.** Route 0 = what BFS finds under the existing
  fixed neighbour order, and §3 asks that this tie-break be a *documented consequence*
  of that order rather than an accident a refactor can flip.
- **`route_hint` on `SpawnGroup`**: −1 alternates by index, 0 or 1 forces a road.
  Alternation rather than RNG — no seed interaction, trivially testable.
- **A route-count declaration on `MapDef`**, validated at content-check time, so a
  layout edit that opens a third route fails CI instead of silently breaking every
  wave's choreography.
- **Tests**: enumeration deterministic, alternation deterministic, and the determinism
  suite runs one fork-map match end to end.

A2 has staged `fork.layout.txt` and `fork.tres.pending`. **Do not promote them** — that
is a lead action once both halves verify. Write your own fixture under `tests/`.

`maps.md` §3 item 5 is the one most likely to bite: if the two routes differ in length,
BFS-shortest sends everyone down one road and the map dies. A test asserting both routes
are equal length on a fork map is cheap and catches a bad layout edit forever.

## 2. The prop table

`art/PENDING.md` §1 is a complete schema proposal — field names, inline documentation,
per-biome weights, keep-out radius. Your half is the `MapDef` fields plus validation;
A4 consumes them. Implement it as specified unless something is wrong with it.

## 3. Exposure-seconds

`difficulty.md` §5 directs the harness to report **added exposure-seconds** per tower:
the extra time enemies spend inside *other* towers' range because of a slow. Last open
Phase 0 item. Until it lands the Frost Mortar's entire product is invisible and every
tuning pass will keep concluding the family is weak — including the Glacier and
Shatterhead tiers that shipped two rounds ago and have never been measured.

## 4. New, and small: a water glyph

The board currently drops waterfalls at fixed bearings with nothing above them. A4 is
fixing that visually this round by rendering water on `BLOCKED` cells, which needs
nothing from you. The follow-up is letting a designer *place* water:

Add `~` to the layout parser as a cell that resolves to `BLOCKED` for every sim
purpose — unwalkable, unbuildable, identical in pathfinding — while remaining
distinguishable to the view layer as a render hint. **No new sim concept, no new
pathfinding case, no change to any existing map.** Expose it however is cleanest for
`board.gd` to read; say what you chose so A4 and A2 can use it.

If this looks like it is growing a sim concept, stop and report rather than building
one. It is a glyph, not a mechanic.

## Definition of done

- `run_tests.gd` exits 0; `run_autoplay.gd` exits 0 with **zero `ERROR:` and zero
  `WARNING:` lines**
- `test_determinism.gd` green, including one fork-map match
- `scripts/balance.bat` run with the exposure-seconds column, Frost Mortar numbers in
  your report

## Report back

Route enumeration and what makes the tie-break documented rather than accidental;
whether the prop table matched A5's spec; what exposure-seconds says about the mortar
family; and the shape you chose for `~`.

---

# A2 — Fable 5 · Water, and the campaign's missing middle

You are A2 on **Bastion Line**. You own game design. Read `docs/design/README.md`, then
your own `maps.md`, `campaign.md` and `bosses.md`.

**You own `docs/design/**`, `data/waves/**` and `data/maps/**`.**

`bosses.md` is the right answer and the right size. Landing on **zero new sim
primitives** — bosses composing abilities that already exist — and finding a real gap
in the process (a split child that itself splits, a two-link chain nothing has
exercised) is design review doing what code review cannot.

## 1. Water in the layouts

A4 is fixing sourceless waterfalls this round by rendering water on `BLOCKED` cells it
picks itself. A3 is adding a `~` glyph so you can place it deliberately instead. Once
that lands, `~` is a `BLOCKED` cell that renders as water — no new sim behaviour, no
pathfinding change.

Place water in `crossing.layout.txt`, `corridor.layout.txt` and `fork.layout.txt`.
Design questions worth answering rather than sprinkling:

- Water is `BLOCKED`, so it removes build ground. On The Corridor that is a real
  balance lever — `maps.md` §4 is explicitly about per-pad economics under scarcity —
  so water there is a *design* decision, not decoration.
- A waterfall needs its source at the rim. Which edges, and does that read as the
  island draining, or as a river crossing it?
- The Fork's two routes must stay equal length (`maps.md` §3 item 5). Water near the
  branch is exactly where an innocent edit breaks that.

If A3's glyph has not landed when you get there, write the layouts with `~` anyway and
stage them as `.pending`. That has worked twice now.

## 2. The campaign's missing middle

`campaign.md` settles a linear campaign of ordered maps gated by completion. Three maps
exist or are staged. What is undesigned is what happens *between* them — the player
finishes The Crossing and then what? A results screen, a record, a next-map prompt?

A4 built the menu but nothing designs the moment a run ends, which is the moment the
campaign either exists or doesn't. Write it into `campaign.md`: what the player sees on
win, on loss, and what makes them start the next map. Keep it as small as §1 was.

## 3. The 10× display ruling — third time of asking

Damage numbers print the raw 10× value, so a 2.7-damage hit reads as "272".
`DISPLAY_DIVISOR` in `damage_numbers.gd` is the one place it changes. This is a voice
decision as much as a UI one and it wants answering before the number appears in a
trailer. One paragraph in `voice.md` closes it.

## Definition of done

`run_tests.gd` exits 0. Anything depending on A3's glyph is staged `.pending`, not
promoted.

## Report back

The water placement per map with reasoning, the end-of-run design, and the 10× ruling.

---

# A5 — Claude + Blender MCP · Water, foam, and the boss

You are A5 on **Bastion Line**. You own the art pipeline. Read `art/README.md`.

**You own `art/**`, `data/models/**` and `data/icons/**`.**

The icon set is good work and the tint masks were the right call — you anticipated a
need A4 had not asked for yet. A4 is ruling on runtime tinting this round; if it says
no, stop generating them.

## 1. Water and foam props

A4 is rebuilding the waterfalls to fall from real sources. Everything in that system is
procedural `BoxMesh` and `CylinderMesh` today — functional, and the reason the falls
read as pillars rather than water.

Build a small kit: foam caps for where a fall leaves the rim, a spray/mist form for
where it lands, and a couple of rock lips a river can pour over. Same discipline as the
biome kits. Coordinate names with A4 through `PENDING.md` — it is consuming these, and
last round's icon miss happened because two lanes shipped into the same window without a
name to meet at.

## 2. The boss

`docs/design/bosses.md` §3 specifies four defs and §4 says what each agent needs — your
silhouette brief is in there. A2 wrote it to the same specificity as the tier meshes, so
build from it directly.

The constraint that matters: a boss must read as a boss **at RTS distance, in a crowd,
against enemies that already exist**. Your measured height ladder runs Courser 0.526 to
Brute 1.564. A boss that is merely the tallest thing on the board is the easy answer;
whether it is the right one is your call, and worth a sentence in your report either way.

## 3. Regeneration

`render_icons.py` and `render_thumbnails.py` need to cover any new tower or map without
editing. If A2's Fork promotes this round it needs a thumbnail, and that should be a
re-run rather than a code change.

## Definition of done

Every script exports, full pipeline regression, `art/PENDING.md` updated, measured
bounding boxes for the boss.

## Report back

Measured boxes, whether the boss reads at RTS distance in a crowd, and the names you
agreed with A4 for the water kit.

---

## Lead tasks

- Promote `fork.tres.pending` and the staged waves once A3's route support verifies.
- Branch-per-agent workflow into `AGENTS.md` — still not done, and round 3 had two
  agents writing in the same window again.
- Rule on runtime icon tinting if A4 and A5 disagree.
