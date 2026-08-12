# Round 3B — follow-on tasks for A2 and A5

A2 and A5 finished early. A3's abilities have landed; A4 is still building menus.
These two tasks are chosen to **feed the next round rather than fill time** — A2's
output is what A3 will build from next, and A5's output is what A4 is building a home
for right now.

Paste one section into one chat.

---

# A2 — Fable 5 · The Fork, and the boss

You are A2 on **Bastion Line**, a deterministic 3D tower defence game in Godot 4.7.
You own game design. Read `docs/design/README.md`, then your own `maps.md`,
`enemies.md`, `difficulty.md`, `upgrades.md` and `campaign.md`.

**You own `docs/design/**`, `data/waves/**` and `data/maps/**`. You must not touch
`sim/**`, `game/**`, `art/**`, `data/enemies/**` or `data/towers/**`.**

Two things from your last session are worth naming because I want more of both. Staging
waves 6–10 as `.tres.pending` and leaving `crossing.tres` pointing at five was the
right call — the content is written, the suite stays green, and promoting it is a
rename. And `campaign.md` §2's argument against between-run unlocks is the strongest
piece of design writing in the repo: the observation that meta state adds a third input
outside the command log, and therefore either grows an anti-cheat or desyncs replays,
is a real architectural consequence that nobody had spotted. That is the level to keep
working at.

## Your task

**1. The Fork — layout and waves, staged.**

`maps.md` §2 specifies it completely and §3 tells A3 what it needs. Multi-route
pathfinding does not exist yet, and the Fork is the natural next A3 round — so write
the content now and stage it the way you staged the Crossing's waves. When A3 lands
route support, the map promotes with a rename instead of a design session.

- `data/maps/fork.layout.txt` and `data/maps/fork.tres.pending`
- Ten waves as `.pending`, choreographed to §2.4's wave-arc
- **Run your own §5 acceptance checks on the layout before calling it done.** §3 item 5
  says equal route length is load-bearing: if the two routes differ, BFS-shortest sends
  everyone down one road and the map dies. That check is yours and it is the one that
  matters.
- `route_hint` on the spawn group is A3's proposal in §3 item 2. Write your waves
  assuming it exists and note in the file which groups depend on it.

**2. The boss.**

`upgrades.md` §5 sells Prime Focus partly on "Brutes, Wardens and the bosses ROADMAP
3.3 promises". `campaign.md` gives each map a completion record. Nothing has designed a
boss, and the campaign now has a shape that wants one at the end of a map.

Write `docs/design/bosses.md`. The questions I would want answered:

- Is a boss a single high-HP enemy, a scripted final wave, or a distinct entity with
  phases? Argue it. Cheapest is a wave-level construct with no new sim primitives —
  make the case for or against that honestly rather than defaulting to it.
- What does it break that the current roster cannot? Every enemy in `enemies.md` §2
  earns its place by invalidating an assumption. A boss that is just a Brute with a
  bigger number teaches nothing and, worse, is exactly what Prime Focus already
  answers.
- How does it interact with the abilities A3 just shipped — `AURA`, `HEAL_PULSE`,
  `SPLIT_ON_DEATH`, flight? A boss that composes existing abilities costs the sim
  almost nothing, which is the whole point of the enum-not-subclass rule.
- What does it need from A5? It needs a silhouette brief with the same specificity you
  gave the tier meshes, because A5 will build from it directly.
- Where does it sit in `difficulty.md`'s gates? A boss wave that the harness cannot
  measure is a boss wave that will ship broken.

Keep the sim ask small and say plainly what it is. If the honest answer is "a boss
needs one new primitive", name that primitive and defend it.

## Definition of done

`run_tests.gd` exits 0. Nothing you write this session should be loadable by `Catalog`
yet — the Fork content is staged, `bosses.md` is a document. If the suite goes red,
something got promoted that shouldn't have been.

## Report back

The Fork layout as ASCII with your §5 check results, the wave list with reasoning, and
the boss design with its sim ask stated in one line.

---

# A5 — Claude + Blender MCP · Icons and map thumbnails

You are A5 on **Bastion Line**. You own the art pipeline. Read `art/README.md` — it is
the contract.

**You own `art/**` and `data/models/**`. You must not open any `.tres` file.** Record
anything you need from one in `art/PENDING.md`.

Your prop-table proposal in `PENDING.md` §1 is exactly the right shape — field names,
inline documentation, a keep-out radius quoting the maps brief that motivated it, and a
fallback that leaves existing maps unaffected. It is a ready task rather than a
discussion, which is what I asked for. It goes to A3 next round.

## The gap

**A4 is building the main menu, level select and upgrade panel right now.** Every one
of those surfaces displays things it has no art for:

- The build bar and upgrade panel need **tower icons** — and there are twelve tower
  states now, not three, because each tier is its own def and the fork means a player
  chooses between two pictures.
- Level select needs **map thumbnails**. `campaign.md` settles a linear campaign with
  per-map records, so the level select is a list of maps that has to show *something*
  per map, and "The Corridor" as a text label is not it.

You already have most of the machinery. `art/preview_towers.py` and
`art/preview_roster.py` set up cameras and lighting to judge models at a chosen angle —
an icon renderer is that, plus an orthographic camera, a transparent film, and a
deterministic output path.

## Your task

**1. Tower icons.** One per tower def, twelve total:

```
arc_cannon · arc_cannon_t2 · arc_cannon_t3a · arc_cannon_t3b
plasma_lance · plasma_lance_t2 · plasma_lance_t3a · plasma_lance_t3b
frost_mortar · frost_mortar_t2 · frost_mortar_t3a · frost_mortar_t3b
```

Build `plasma_lance_t3b`'s icon even though its def is still deferred — same reasoning
as building its mesh: the family's visual language is cheaper to finish in one pass.

Constraints that make these usable rather than decorative:

- **Identical camera, framing and lighting for every icon.** A set where the angle
  drifts reads as sloppy at a glance even when each individual image is fine.
- **The tier must be readable at icon size.** This is the same judgement call as the
  RTS-distance test, and it is harder: if `arc_cannon` and `arc_cannon_t2` are
  indistinguishable in a 64px square, the upgrade panel cannot do its job. Render at a
  small size and look at it small. Do not judge these at 512px.
- Transparent background, square, power-of-two.
- The models carry no colour by contract — `body_color` and `accent_color` live in the
  `.tres`. Pick a neutral studio palette for the icons and **note in `PENDING.md` that
  A4 may want to tint them at runtime** the way `tower_view.gd` tints the meshes. If
  runtime tinting is wanted, the icons need to be rendered so it is possible; flag
  which parts are which.

**2. Map thumbnails.** One per map — `crossing`, `corridor`, and `fork` if A2's layout
has landed by the time you get there. You already have `art/preview_map.py`. An
orthographic top-down-ish render of the assembled board is the obvious approach; if it
is easier to generate these from the `.layout.txt` directly than to rebuild the board
in Blender, do that instead and say so.

**3. Where they go.** These are not models, so `data/models/` is wrong. Propose a path
convention in `PENDING.md` and use it — `data/icons/towers/<def_id>.png` and
`data/icons/maps/<map_id>.png` unless you have a better idea. Godot imports PNGs
automatically; flag any import settings A4 will need (filtering matters at icon size).

## Definition of done

Twelve tower icons, two or three map thumbnails, a script that regenerates all of them
from scratch, and `PENDING.md` updated with the path convention and the tinting
question. The script matters more than the images — an icon set that cannot be
regenerated after a mesh changes is a set that goes stale the first time A5 touches a
model.

## Report back

The icons themselves if you can show them, whether tier reads at icon size, the path
convention you chose, and your answer on runtime tinting.

---

---

# A3 — Codex (Opus 5) · Multi-route pathfinding, and two small unblocks

You are A3 on **Bastion Line**, a deterministic 3D tower defence game in Godot 4.7 /
GDScript. Read `AGENTS.md` first. Then `docs/design/maps.md` §2 and §3.

**You own `sim/**`, `tests/**`, `data/schemas/**`, `data/towers/**` and
`data/enemies/**`. You must not open `game/**`, `art/**`, `data/waves/**` or
`data/maps/**`** — A2 is writing the Fork's layout and waves in a parallel session
right now, and you will collide.

Abilities landed clean. The enum-not-subclass discipline held, the Warden's aura folds
into a single division, and `test_abilities.gd` exists. Four enemies that were modelled
and inert for two rounds are now real.

## 1. Multi-route pathfinding — the main task

`maps.md` §3 is a brief written directly to you and it is unusually specific. The
design requirement in one line: **both routes see traffic, deterministically, under
wave-data control.** The proposal is §3 items 1–4; the pathfinder is yours, so overrule
the proposal if you have a better shape — but keep the requirement.

- **Route enumeration with stable ids.** Route 0 = what BFS finds under the existing
  fixed neighbour order. §3 asks that this tie-break be a *documented consequence* of
  that order rather than an accident a refactor can flip — that sentence is the whole
  task in miniature.
- **`route_hint` on the spawn group**: −1 alternates by index, 0 or 1 forces a road.
  Alternation rather than RNG, so there is no seed interaction and it is trivially
  testable.
- **A route-count declaration on `MapDef`**, validated at content-check time, so a
  layout edit that opens a third route fails CI instead of silently breaking every
  wave's choreography.
- **Tests**: route enumeration deterministic, spawn alternation deterministic, and the
  determinism suite runs at least one fork-map match end to end.

A2 is staging `fork.layout.txt` and `fork.tres.pending` this session. **Do not promote
them** — that is a lead action once both halves are verified. If you need a fork layout
to test against, write your own fixture under `tests/`.

`maps.md` §3 item 5 is the thing most likely to bite: **if the two routes differ in
length, BFS-shortest sends everyone down one road and the map dies.** That is A2's
layout responsibility, but your route enumeration is what makes it observable — a test
that asserts both routes are equal length on a fork map is cheap and would catch a bad
layout edit forever.

## 2. The prop table — A5 has written you a ready task

`art/PENDING.md` §1 is a complete schema proposal: field names, inline documentation,
per-biome weights, and a keep-out radius quoting the maps brief that motivated it. It
exists because a snow kit and a desert kit are built and scattered by nobody —
`board.gd::_scatter_props()` hardcodes seven grassland paths.

Your half is the `MapDef` fields plus validation. The consumer is A4's. Implement it as
A5 specified unless something is wrong with it, and note that the empty-means-grassland
fallback is what keeps existing maps unaffected.

## 3. Exposure-seconds — the harness column that has been missing since Phase 0

`difficulty.md` §5 directs the harness to report **added exposure-seconds** per tower:
the extra time enemies spend inside *other* towers' range because of a slow. Until it
lands, the Frost Mortar's entire product is invisible to every report — the family
scores as decoration, and any tuning pass will keep concluding it is weak.

This is the last open item from Phase 0 and it is blocking honest measurement of a
whole tower family, including the two Glacier and Shatterhead tiers that just shipped.

## Definition of done

- `run_tests.gd` exits 0; `run_autoplay.gd` exits 0 with **zero `ERROR:` and zero
  `WARNING:` lines**
- `test_determinism.gd` green, including at least one fork-map match
- `scripts/balance.bat` run with the new exposure-seconds column, and the Frost Mortar
  family's numbers in your report — this is the first time anyone will have seen them

## Report back

How you enumerated routes and what makes the tie-break documented rather than
accidental; whether the prop table matched A5's proposal; and what exposure-seconds
says about the mortar family now that it is measurable.

---

## Still queued, not this round

- **Generalise status effects (2.4)** — `EnemyState` still hardcodes `slow_percent`.
  Abilities shipped on top of it and bosses lean on the same schema, so this is the
  round after, paired with A2's boss design.
- **Fork Array** — model exists, def deferred, needs multi-target selection.
- **Save/load serialisation (3.1)** — the hard half is done; only writing the log to
  disk remains.
