# Round 2 — assignments

Paste one section into one chat. Each prompt is self-contained: an agent opening a
fresh session needs nothing from this conversation beyond the text of its own block.

**Round theme: convergence.** Round 1 produced more design and art than the sim can
consume. Nine enemy models exist against four enemy defs. `upgrades.md` is 166 lines
of finished design against zero lines of implementation. `maps.md` fully specifies two
maps against one shipped. Nothing in this round is speculative — every task closes a
gap between something already built and something that can't use it yet.

---

## The pinned contract

Four agents build parts of the upgrade system simultaneously. They converge only if
they agree on these six lines *before* anyone starts. This is a lead ruling, not a
proposal — it appears verbatim in all four prompts.

```
TIER IDS    arc_cannon_t2 / arc_cannon_t3a / arc_cannon_t3b
            plasma_lance_t2 / plasma_lance_t3a / plasma_lance_t3b
            frost_mortar_t2 / frost_mortar_t3a / frost_mortar_t3b
TIER FILES  data/towers/<def_id>.tres        — full stats, no deltas, no inheritance
TIER MESHES res://data/models/towers/<def_id>.glb
SCHEMA      TowerDef.upgrade_ids: PackedStringArray
            (0 entries = terminal, 1 = linear step, 2 = the fork)
STATE       TowerState.credits_invested: int   — refund = credits_invested * 70 / 100
COMMAND     apply_command("upgrade", {"tower_id": int, "def_id": String})
EVENT       {"type": TOWER_UPGRADED, "tower_id": int, "def_id": String, "tier": int}
```

`tier` is 1/2/3 and is carried on the event even though it is derivable, because the
view needs it to pick an effect without loading the def.

## Lead rulings already applied

- **`walker.tres` height 1.3 → 1.18.** A5 measured the model's crown at 1.173 against
  a declared 1.3, so the health bar floated 0.577 above it where every other enemy
  sits at 0.444–0.489. Fixed the def, not the model: nothing about the Walker looks
  wrong today, the new roster was drawn against its current size, and raising the
  model would cut the Mender's clearance over it from 0.21 to 0.08 — and the Mender
  has to be pickable out of a Walker column in wave 9. **Done — do not redo it.**
- **`art/PENDING.md` §1 is authoritative** for the five new enemies' presentation
  fields. §2 is now resolved. §3 goes to A4. §4–5 stay open.

## Ownership this round — disjoint, no exceptions

| Agent | Owns | Must not touch |
| --- | --- | --- |
| A3 Codex | `sim/**`, `tests/**`, `data/schemas/**`, `data/towers/**` | `game/**`, `art/**`, `data/enemies/**`, `data/waves/**`, `data/maps/**` |
| A2 Fable | `docs/design/**`, `data/enemies/**`, `data/waves/**`, `data/maps/**` | `sim/**`, `game/**`, `art/**`, `data/towers/**` |
| A4 Opus Max | `game/**` | `sim/**`, `data/**`, `art/**` |
| A5 Art | `art/**`, `data/models/**` | all code, all `.tres` |

Two agents write to `data/` this round. They are confined to different
subdirectories, which is the only reason this is safe. A3 owns `data/towers/`, A2 owns
`data/enemies/`, `data/waves/` and `data/maps/`. Neither may cross.

---

# A3 — Codex (Opus 5) · Tower upgrades

You are A3 on **Bastion Line**, a deterministic 3D tower defence game in Godot 4.7 /
GDScript. Read `AGENTS.md` first — it is the single source of truth for architecture,
commands and the definition of done. Then read `docs/design/upgrades.md` in full.

**You own `sim/**`, `tests/**`, `data/schemas/**` and `data/towers/**`. You must not
open `game/**`, `art/**`, `data/enemies/**`, `data/waves/**` or `data/maps/**` — other
agents are editing those in parallel this session.**

## Your task: ship the three-tier upgrade system

`docs/design/upgrades.md` is finished design and has been through a balance pass. It
specifies every tier's stats, the pricing doctrine, the family invariants and the
tuning latitude you have. Build what it describes. §7 is its own ask-list addressed to
you.

The contract below is fixed by the lead because three other agents are building
against it right now. Do not redesign it; if something in it is actually wrong, say so
in your report and keep going with it.

```
TIER IDS    arc_cannon_t2 / arc_cannon_t3a / arc_cannon_t3b
            plasma_lance_t2 / plasma_lance_t3a / plasma_lance_t3b
            frost_mortar_t2 / frost_mortar_t3a / frost_mortar_t3b
TIER FILES  data/towers/<def_id>.tres        — full stats, no deltas, no inheritance
TIER MESHES res://data/models/towers/<def_id>.glb   — A5 is building these now;
            set mesh_path to them even though the files do not exist yet.
            tower_view.gd falls back to primitives on a missing mesh by design.
SCHEMA      TowerDef.upgrade_ids: PackedStringArray
STATE       TowerState.credits_invested: int   — refund = credits_invested * 70 / 100
COMMAND     apply_command("upgrade", {"tower_id": int, "def_id": String})
EVENT       {"type": TOWER_UPGRADED, "tower_id": int, "def_id": String, "tier": int}
```

Scope, in the order I'd take it:

1. **Schema and the nine defs.** `upgrade_ids` on `TowerDef`; nine new `.tres` with
   the stats from upgrades.md §4–6. `Catalog.validate()` must reject an `upgrade_ids`
   entry that names a def that doesn't exist — that check is the whole safety net for
   a data-driven upgrade tree.
2. **`try_upgrade` through `apply_command`.** It must go through the single command
   door so it lands in the replay log for free (backlog 7 depends on this). Rules:
   legal exactly when build/sell is legal, costs credits, accrues into
   `credits_invested`, swaps the def, never changes footprint or cell.
3. **`TOWER_UPGRADED`.** Emit it. **This is a known open seam** — A4 is writing the
   consumer this session against the shape above, so the shape is load-bearing.
4. **Tests.** Upgrade costs credits and changes stats; sell at tier 3 refunds 70% of
   everything invested; an illegal upgrade (wrong def id, insufficient credits, wrong
   phase) is rejected without mutating state; `snapshot_hash()` covers the tower's
   current def id, or a replayed upgrade silently diverges.

Two implementation flags A2 raised in the design, both of which are yours to judge:

- **upgrades.md §4** — Hailstorm is hitscan *with splash*. Only the Frost Mortar
  exercises the projectile splash path today. Verify hitscan splash works; if the fix
  isn't trivial, ship Hailstorm as a fast projectile (speed 60) and say so.
- **upgrades.md §5** — Fork Array needs multi-target selection the sim doesn't have.
  **This is explicitly deferrable and I am deferring it.** Ship the Lance with Prime
  Focus as a lone tier-3 (temporarily linear, `upgrade_ids` with one entry) and leave
  Fork Array for a later round. Do not let it expand this session.

## Definition of done

- `godot --headless --path . --script res://tests/run_tests.gd` exits 0
- `godot --headless --path . --script res://tests/run_autoplay.gd` exits 0 with **zero
  `ERROR:` and zero `WARNING` lines** — the bar the last session set, hold it
- `tests/cases/test_determinism.gd` green, and green for the right reason
- `scripts/balance.bat` run at least once against the new tier ladder, with the
  damage-dealt-per-tower-per-credit numbers in your report

You may move any number in upgrades.md ±25% chasing the harness (§9 grants this
explicitly). Crossing a **family invariant** — the bolded lines in §4–6 — is a design
change: do it if the harness demands it, but flag it loudly in your report so it can
go back to A2.

## Report back

What you built, what the harness measured, and specifically: which numbers you moved
and why, whether hitscan splash worked, and anything about the contract above that
fought you. Note anything you had to leave undone.

---

# A2 — Fable 5 · The Corridor and the campaign

You are A2 on **Bastion Line**, a deterministic 3D tower defence game in Godot 4.7.
You own game design. Read `docs/design/README.md`, then your own `maps.md`,
`enemies.md` and `difficulty.md` — you wrote all three.

**This round you own `docs/design/**` and, newly, `data/enemies/**`, `data/waves/**`
and `data/maps/**`. You must not touch `sim/**`, `game/**`, `art/**` or
`data/towers/**`.** A3 is rewriting `data/towers/` this session and will collide with
you if you go near it.

You are writing `.tres` resource files for the first time. Copy the shape of an
existing one exactly — `data/enemies/drone.tres` and `data/maps/crossing.tres` are
your templates. The `[gd_resource]` header, the `ext_resource` script path and the
field names are all load-bearing; a malformed `.tres` fails `Catalog` at boot.

## Your task: ship the Corridor, and the Courser

Your own `maps.md` §1 makes the call for me: *"The Corridor needs zero new sim work —
it is one path, today's pathfinder, a layout file and a wave list. Build the Corridor
first."* That is exactly why it is yours and not A3's. Same logic for the Courser —
`enemies.md` §2 says *"None. Pure data."*

1. **`data/enemies/courser.tres`.** Stats from `enemies.md` §2. Presentation fields
   from `art/PENDING.md` §1 — the model is built and exported, and its `height` was
   measured off the exported `.glb`, so do not adjust it to taste; the health bar
   hangs off it.
2. **The Corridor.** `data/maps/corridor.layout.txt` and `data/maps/corridor.tres`,
   built to `maps.md` §4.1. Run your own §5 acceptance checks on the layout before you
   call it done. `starting_lives = 20` — fixed identity, as you specified.
3. **A 10-wave list for the Corridor** in the Crossing grammar: one new fact per wave,
   exams recombine. Use the four shipped enemies plus the Courser. **You cannot use
   Skiff, Warden, Mender or Fission Crawler** — all four need sim abilities that do
   not exist yet, and a wave referencing a def that isn't there fails the catalog
   cross-check at boot.
4. **`difficulty.md` §4.** Still outstanding from last round and now blocking honest
   measurement. The percentile gates are void as written: `sim/rng.gd` is never drawn
   from, so matches differing only by seed are byte-identical and every percentile in
   there has a sample size of one. Restate the gates **over the policy space** —
   placement policies, build orders, saving behaviour — not over seeds. Do not propose
   adding randomness to the sim; determinism is the property the whole test suite
   rests on.

The four ability-bearing enemies you designed are not forgotten — they are queued for
A3's next round, because `AURA`, `HEAL_PULSE` and `SPLIT_ON_DEATH` are sim work and
`sim/` is A3's exclusive lane. Your specs for them are good and are what that round
will be built from.

## Definition of done

`godot --headless --path . --script res://tests/run_tests.gd` exits 0. That suite
already boots **every** shipped map and runs the pathfinder over it, so a Corridor with
a severed route or a malformed `.tres` fails there — which is the point.

If you cannot run Godot, say so plainly in your report rather than guessing. An
unverified map is fine to hand over; a map claimed as verified that was not is not.

## Report back

The layout as ASCII, the wave list with your reasoning per wave, and what changed in
difficulty.md §4. Flag anything where you had to guess at `.tres` syntax.

---

# A4 — Opus 5 Max · Upgrade UI and the view seam

You are A4 on **Bastion Line**, a deterministic 3D tower defence game in Godot 4.7.
You own the view layer. Read `AGENTS.md`, then `docs/ARCHITECTURE.md` — in particular
the section "What the view-count invariant does not catch", which is about the exact
bug your first task exists to prevent.

**You own `game/**` and nothing else. You must not touch `sim/**`, `data/**` or
`art/**`.**

## The seam you are closing

A3 is shipping tower upgrades in a parallel session right now. It produces a
`TOWER_UPGRADED` event. **If nothing consumes it, a fully upgraded tier-3 tower keeps
its tier-1 mesh, fires at its new rate, and every gate in the project stays green** —
because `run_autoplay.gd` compares view counts to sim entity counts, and an upgrade
creates no node and destroys none. CI cannot catch this. You are the check.

The contract is fixed by the lead and A3 is building against it:

```
EVENT       {"type": TOWER_UPGRADED, "tower_id": int, "def_id": String, "tier": int}
TIER MESHES res://data/models/towers/<def_id>.glb    — A5 is building these now
COMMAND     apply_command("upgrade", {"tower_id": int, "def_id": String})
STATE       TowerState.credits_invested — refund = credits_invested * 70 / 100
```

A3 may land after you. Write the consumer against the shape above regardless; if the
event never arrives your code is inert, not broken.

## Scope, in priority order

1. **Consume `TOWER_UPGRADED`** in `level.gd`, rebuilding the tower's view from its new
   def. `tower_view.gd::setup()` already handles a missing `.glb` by falling back to
   primitives, so a tier whose mesh A5 hasn't finished stays playable — do not add a
   second fallback.
2. **The upgrade panel** (`docs/design/upgrades.md` §8). One button at tiers 1–2, a
   two-option choice at the fork, each option previewing the stat diff before purchase.
   The sell button shows the refund computed from invested credits. Nothing else — the
   target-mode UI is a separate backlog item, do not absorb it.
3. **Tower selection and inspection** (backlog item 2). Click a placed tower: range
   ring, DPS, kills, damage dealt. `Simulation.set_target_mode()` already exists and
   has never been called from the UI.
4. **`ACCENT_PARTS` reaches only one tower of three.** From `art/PENDING.md` §3:
   `tower_view.gd` tints by exact node name, so `accent_color` never reaches the Frost
   Mortar's `CoolantTank` or the Plasma Lance's `Capacitor`, `CapacitorRear` and `Fin`.
   Renaming the art would be a lie in the source — A5 named those parts what they are.
   **Fix it with prefix matching (`Body*` / `Accent*`) rather than a longer list**, so
   the next tower doesn't silently ship grey. Coordinate the naming convention in your
   report; A5 will rename to match.

Item 4 is small and safe. If items 1–3 fill the session, do 4 anyway — it is the kind
of thing that never gets done otherwise.

## Definition of done

- `godot --headless --path . --script res://tests/run_autoplay.gd` exits 0 with **zero
  `ERROR:` and zero `WARNING:` lines**. Nothing in `tests/cases/` builds a node, so
  autoplay is the only check in the project that executes your code at all.
- Any new node type is created and freed in step with its sim entity, or the view-count
  assert will tell you immediately.

## Report back

What you wired, and specifically whether `TOWER_UPGRADED` had arrived from A3 by the
time you finished or whether your consumer is still speculative. Name the prefix
convention you chose for item 4.

---

# A5 — Claude + Blender MCP · Tier meshes

You are A5 on **Bastion Line**. You own the art pipeline. Read `art/README.md` — it is
the contract — then `docs/design/upgrades.md` §8, which specifies what each tier must
look like and why.

**You own `art/**` and `data/models/**`. You must not open any `.tres` file.** A3 and
A2 are both editing `data/` in parallel this session. Record anything you need from a
`.tres` in `art/PENDING.md` as a one-line edit for the lead, exactly as you did last
round — that file worked, keep using it.

Your last round was clean: nine enemy models, nine exports, 17/17 scripts regressing,
and a `PENDING.md` that caught a real defect in `walker.tres` by measurement rather
than by eye. Same standard here.

## Your task: the upgrade tier meshes

You asked last round whether to build these ahead of the schema. The answer is now yes
— the schema is being built this session and the naming is fixed:

```
art/towers/<def_id>.py    ->    data/models/towers/<def_id>.glb

arc_cannon_t2    arc_cannon_t3a    arc_cannon_t3b
plasma_lance_t2  plasma_lance_t3a  plasma_lance_t3b
frost_mortar_t2  frost_mortar_t3a  frost_mortar_t3b
```

`upgrades.md` §8 gives the silhouette brief for each: tier 2 is the same silhouette
visibly bulkier; tier 3 is a distinct silhouette per branch — Hailstorm a multi-barrel
rotary, Railshot one long rail, Prime Focus a single large emitter, Fork Array split
emitter prongs, Glacier a broad squat mortar with vanes, Shatterhead a reinforced
heavy barrel.

**Build `plasma_lance_t3b` (Fork Array) anyway even though A3 is deferring the fork
mechanic this round.** A model costs you one script; rebuilding the family's visual
language later because one member was skipped costs more.

Non-negotiable, because `game/views/tower_view.gd` drives these by name:

- Every tier exports `Base`, `Turret` and `Barrel`. A tier that renames one is a tier
  that doesn't rotate.
- `Plinth` and `TurretHead` take `body_color`; the accent parts take `accent_color`.
  **A4 is changing accent tinting to prefix matching this session** — check its report
  for the convention it lands on and rename accordingly, or your accents stay grey.
- The player must be able to tell tier 1 from tier 2 from tier 3 at RTS camera
  distance, with no UI. Screenshot at that angle and judge it there, not in a close-up
  — that is how the Arc Cannon's first pass got caught reading as a squat plinth.

If you finish early: `enemies.md` §2 defines **Fission Spawn** (450 HP, speed 6.5,
Light) as a full enemy def with no model. `art/PENDING.md` §5 already notes
`fission_crawler.py` is factored into a `build_segment()` function precisely so the
child can be one segment of its parent. Cheap, and it unblocks `SPLIT_ON_DEATH` for a
later round.

## Definition of done

Nine `.py`, nine `.glb`, a full pipeline regression, and `art/PENDING.md` updated. Verify
by parsing the exported glTF node hierarchy, not by trusting the export log — that is
how you caught the Brute being shorter than the Walker.

## Report back

The measured bounding boxes per tier, whether the tier ladder reads at RTS distance,
and any `.tres` edits your work needs recorded in `PENDING.md`.

---

## What is deliberately not in this round

- **Enemy abilities** (`AURA`, `HEAL_PULSE`, `SPLIT_ON_DEATH`, air routing). Four of
  the five new models stay inert until these land. They are sim work, `sim/` is A3's
  exclusive lane, and A3 is full. This is the next A3 round and it is the biggest
  remaining content unlock in the project.
- **The Fork map.** Needs multi-route pathfinding (`maps.md` §3). Ships after the
  Corridor, as A2 recommended.
- **Fork Array.** Deferred by lead ruling; the Lance ships temporarily linear.
- **The snow and desert biome prop tables.** `board.gd::_scatter_props()` hardcodes
  seven grassland paths. A5's eight snow props and `crystal.glb` are built and
  scattered by nobody. The durable fix is a prop table on `MapDef` — an A3 schema
  change plus an A4 consumer — and it should ride with the Fork.

## Lead tasks

- Apply `art/PENDING.md` §1 if A2 doesn't get to the five enemy defs — but only the
  Courser is legal this round; the other four wait on abilities.
- Branch-per-agent workflow into `AGENTS.md` now that git exists. Five agents on one
  working copy means whoever commits second absorbs the other's half-finished edits.
- Reconcile `PENDING.md` §3's contract corrections against whatever A4 lands.
