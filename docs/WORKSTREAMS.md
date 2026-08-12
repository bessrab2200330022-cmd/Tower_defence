# Workstreams — the four agents

Who does what, in what order, and how they avoid stepping on each other.

`ROADMAP.md` says *what* the game should become. `HANDOFF.md` orients a fresh agent. **This file assigns the work.** Each agent's section below is self-contained — paste it and start.

---

## The fleet

| Agent | Role | Owns these files | Never touches |
| --- | --- | --- | --- |
| **A1 — Claude Cowork** | Lead. Specs, review, integration, docs | `docs/**`, `AGENTS.md`, `CLAUDE.md` | all code and art |
| **A2 — Fable 5** | Design & writing | `docs/design/**` only | all code |
| **A3 — Codex (Opus 5)** | Simulation, tests, build | `sim/**`, `tests/**`, `data/schemas/**`, `data/towers,enemies,waves,maps/**`, `.github/**`, `scripts/**` | `game/**`, `art/**` |
| **A4 — Claude Opus 5 Max** | View layer, UI, bugs | `game/**` | `sim/**`, `art/**` |
| **A5 — Claude Cowork + Blender** | Art | `art/**`, `data/models/**` | all code |

**A1 writes no code.** With four agents producing, integration and review become the bottleneck, and the lead's scarce resource is context to review *with* — not throughput. A1 keeps whole-project context, writes the specs the others implement, resolves the seams and keeps the docs true.

**A5 needs Blender MCP connected** — it is the only requirement that is not just a folder. Any Claude Desktop chat has it once the connector is configured; see `art/README.md` for the workflow.

**That split is close to collision-free by construction.** Each agent owns a top-level directory. The two seams:

- **`data/*.tres`** — A3 owns the balance fields, A1 owns `mesh_path`, `mesh_scale` and the colour fields. Neither may reformat the file.
- **New events** — a new event type needs a producer in `sim/` (A3) and a consumer in `game/level.gd` (A4). Whoever goes first says so; the other adds their half in the same session if possible. An event with only one half orphans a node, and `run_autoplay.gd` will catch it.

### Standing decisions

Rulings the lead has made that agents may act on without asking again.

| Decision | Ruling |
| --- | --- |
| `starting_credits` may leave the ±60 band in `difficulty.md` §7 | **Granted, once — and now spent.** The harness found a 0% win rate at 320 with the playable range at 560–960. A3 landed on **640**; A2 rewrote §7 to anchor the band to the measurement. Closed. The rule it established stands: *a knob's band is anchored to a measurement, or it is marked provisional.* |
| Percentile gates over seeds | **Resolved.** `difficulty.md` revision 2 restates G1–G9 over policy classes, and `maps.md` §2.5 and §4.5 follow for F1–F8 and C1–C8. Exact counts, no confidence intervals. Do not add randomness to the sim to fix a dead seed axis — if a future mechanic legitimately needs it, seeds become a *second* axis, never a replacement. |
| Art may not edit `.tres` while a balance pass is running | **Enforced, and it worked.** A5 opened no `.tres` this session and logged every needed edit in `art/PENDING.md`. Verified by diff: the four shipped `data/enemies/*.tres` show balance-field changes only, with `mesh_path`, `mesh_scale` and the colour fields untouched. Keep the convention — it is the only reason there is no clobber to report. |
| `walker.tres` height 1.3 vs a measured model crown of 1.173 (`PENDING.md` §2) | **(b) — fix the def to 1.18.** A5's own lean, and the right one. Nothing about the Walker looks wrong today, the new five-model roster was drawn against its current size, and option (a) shrinks the Mender's clearance from 0.21 to 0.08 — a gap `enemies.md` deliberately relies on for wave 9 pickability. Honesty about the def is worth less than a silhouette ladder that already reads correctly. A3 applies the one-line edit; A5 deletes the PENDING entry. |
| Arc Cannon: `difficulty.md` §5's failing anchor vs the balance pass | **See "Open seams" below — unresolved, and the day's first decision.** |

### Open seams

| Event / seam | Producer | Consumer | Status (verified on disk, 12 Aug 2026) |
| --- | --- | --- | --- |
| `TOWER_UPGRADED` | A3 (ROADMAP 2.2) | A4 (`level.gd`, swap the view's mesh and def) | **Neither half exists.** Not in `sim/sim_types.gd`'s `Event` enum, not in `level.gd`. Clean — no orphan. CI cannot catch this one. |
| `ENEMY_HEALED` | A3 (Mender, `enemies.md` §2) | A4 (pulse ring + health bar) | **Not built.** Same mutate-only class as `TOWER_UPGRADED` — a healed enemy whose bar doesn't move reads as a bug and no gate will say so. |
| `tower_inspected(cell)` | A4 (`level.gd:12`, emitted at `:601`) | **Nobody** | **Deliberate, and correct.** A signal, not a sim event, so no view is orphaned and no gate is at risk. It is the hook ROADMAP 2.3 hangs off, and it means selection has exactly one owner before any UI depends on it. |
| Arc Cannon 90 → 110 | A2 (`difficulty.md` §5 asks for **damage** 90→110) | A3 (shipped **cost** 90→110, damage still 90) | **Contradiction. Needs an A1 ruling — see below.** |
| Five enemy models with no defs | A5 (`.glb` × 5 exported) | A3 (`data/enemies/*.tres` × 5) | **Half-built.** `Catalog` scans `data/enemies/`, so a model with no def is inert, not broken. Specs are in `art/PENDING.md` §1 (presentation) and `enemies.md` §2 (balance). |
| Per-map prop table | A5 (snow kit × 8 exported) | A3 (`MapDef` field) or A4 (`board.gd`) | **Blocked on a decision.** `board.gd::_scatter_props()` hardcodes seven grassland paths. `PENDING.md` §4b proposes a weighted list on `MapDef` — that serves both and also wires `crystal.glb`, which is built by nothing and scattered by nobody. |

**`TOWER_UPGRADED` still needs flagging louder than the others**, and A2 spotted why: it *mutates* a view rather than creating or destroying one, so the autoplay view-count assert stays green while an upgraded tower wears its old mesh and fires at its new rate. See `ARCHITECTURE.md` — "What the view-count invariant does not catch". `ENEMY_HEALED` is the second member of that class, which makes it worth building the check itself rather than remembering twice: an assert in the autoplay runner that a view's `def_id` matches the sim's after any mutating command generalises to every future mutate-only event. Whichever agent ships their half first must say so in their report, because nothing automated will.

### The Arc Cannon contradiction

`difficulty.md` §5 carries an anchor as a *measured failure*: "a lone drone must lose to a lone, well-placed Arc Cannon — and today it does not." One transit is five shots; at 90 damage × 110% vs Light that is 495 against 600 HP. The drone walks out. The stated fix is **damage 90 → 110** (five shots → 605), and `upgrades.md` §9 has already pre-committed Overclock to rescale with it.

The balance pass instead moved **cost** 90 → 110 and left damage at 90. On disk today: `cost = 110`, `damage = 90`. The anchor is still failing and no Done-list note mentions it.

This is not obviously a mistake, and that is what makes it a lead decision rather than a bug report. The two changes point in opposite directions and both are defensible:

- **Design wants the Arc stronger.** The anchor is the first thing a player ever watches happen, and watching one cannon fail to kill one drone teaches the wrong lesson on wave 1.
- **Balance wants the Arc weaker.** The pass's central finding was that spamming the cheapest tower beat the designed kit at every credit level. Raising Arc damage lifts S1 faster than S2 and pushes directly against G1 and G5.

Both may be satisfiable at once — damage up *and* cost up makes one Arc kill one drone while keeping massed Arcs expensive — but that is a claim to measure, not to assert. Route: A3 re-runs the sweep with `damage = 110, cost = 110` and reports G1/G5 before deciding. If the gates hold, ship it and let Overclock rescale. If they do not, the anchor is the thing that gives, and A2 rewrites §5 to say why — an anchor that survives its own disproof is how a design document stops being falsifiable.

---

## Why each agent got what it got

One question decides everything: **what is the verification gate, and can this agent reach it?**

- **A3 (Codex)** has its own sandbox, installs Godot via `.codex/setup.sh`, and runs the suite itself. Give it a spec and a hard gate and it works async without you. That makes it the right home for all pure-logic work — the sim is *entirely* test-verifiable, which is the whole point of the architecture.
- **A4 (Opus Max)** can look at a screenshot. No test tells you a barrel is invisible from the RTS camera angle, or that the range ring z-fights. Everything in `game/` is judged by eye, so it goes here.
- **A5 (Claude + Blender)** is the only agent that can model, render, inspect the exported glTF and iterate in one loop. Art has to live there and nowhere else.
- **A2 (Fable)** writes. Design documents, flavour, naming, store copy. **It should not touch code**, and its output is prose that A3 and A4 implement.
- **A1 (lead)** writes nothing but documents. That is deliberate: see the note under the fleet table.

### Why art was split out of the lead role

It could not have been, until recently. The rules that make art safe to hand over — mirror-about-parent, the `Base`/`Turret`/`Barrel` node contract, ground-standing bounding-box checks, the Blender→Godot axis mapping, never calling settings-level operators — lived only in the lead's working memory. They are now all in `art/README.md`, each recorded next to the bug that produced it.

Style, the part that genuinely cannot be written down, is also no longer a blank page: twelve shipped assets exist to match. A fresh agent copies a reference implementation rather than interpreting a description.

**The lead keeps a style veto** and can open `art/preview_map.py` in Blender to look at a render before accepting work.

Second question: **can the context be written down?** `AGENTS.md` and the tests carry the rules, so most work is disposable — do it, close the chat. Two things cannot be written down: **taste** (why the Brute must be visibly the tallest thing on the board) and **measurement intuition** (what actually happens when a fire interval drops 4 ticks). Those live in long-running chats: art in A1, balance in A3.

---

## Order of work

*Revised 12 Aug 2026. Everything in the old NOW and NEXT blocks shipped overnight — harness, interpolation, audio, selection, difficulty target, upgrade design, enemy design. The plan below replaces it.*

```
NOW (parallel, zero shared files)
  A3 ─ Arc Cannon ruling: re-sweep damage=110/cost=110, report G1+G5
     └ then the five enemy defs (unblocks A5's models, already on disk)
  A4 ─ InputMap (2.1)  ←── HARD BLOCKER on 2.2, and it is now the only one
  A2 ─ voice.md pass on the 10x damage scale (is "272" ever player-facing?)
  A5 ─ Fission Spawn model  ←── the only unblocked art on the list
  A1 ─ commit the overnight work per-agent; doc upkeep

NEXT
  A4 ─ tower inspection UI (2.3)  ←── tower_inspected() already emitted
  A3 ─ tower upgrades (2.2)  ←── needs A4's InputMap first
  A3 ─ exposure-seconds column in the harness (difficulty.md 5 directive)
  A2 ─ reconcile difficulty.md 4 with the harness's implemented gates

THEN
  A5 ─ upgrade-tier visuals  ←── needs A3's upgrade schema first
  A3 ─ status effects (2.4) → flying (2.5) → abilities (2.6)
  A4 ─ chill visual (1.6 second half), path flow (1.5)
```

**Four hard dependencies:**

1. ~~Nothing balance-related is real until A3 ships the harness.~~ **Discharged.** The harness shipped and the first pass landed at 8 of 9 gates.
2. **InputMap (A4) before new hotkeys (A3).** Unchanged, and now the critical path — 2.2 is spec-complete in `upgrades.md` and waiting on nothing else.
3. **Status effects (A3, 2.4) before enemy abilities (2.6) and bosses.** Both lean on the same schema; building them in the wrong order means designing it twice.
4. **The five enemy defs (A3) before any of A5's five models do anything.** The `.glb` files are exported and `Catalog` scans `data/enemies/` — a model with no def is inert, not broken, so nothing is red. It is just five assets doing nothing.

**One measurement caveat that outranks most of the above.** The nine gates in `difficulty.md` §4 and the nine `_gate()` calls in `tests/run_balance.gd` are not the same nine. Three drift:

| Gate | `difficulty.md` §4 says | `run_balance.gd` implements |
| --- | --- | --- |
| G2 | no winning S2 policy finishes below 8 | 5th percentile ≥ 8 |
| G3 | median idle ≤ **30% of the tuned start** (192 at 640) | median idle ≤ **200**, hardcoded |
| G9 | ≥ 1 policy at 20/20 **and < 25% of the class** | flawless rate ≥ 10%, **no upper bound** |

G2 and G9 matter most. Over an *exact enumeration* a 5th percentile is a different claim from "no policy" — the harness's own comment at line 493 reads the clause the strict way while the code does not. And G9's missing upper bound means the harness cannot fail the gate for flawless being *too routine*, which is half of what the gate is for. "8 of 9 gates pass" is a statement about the harness's nine. Reconcile before quoting it again.

---

## Before you open any of them

**Git exists now** — two commits, the second at 02:47 on 12 Aug 2026. The undo button is real. Two things it is not yet doing:

1. **Everything after 02:47 is uncommitted.** The entire overnight run — the balance pass, audio, selection feedback, the range ring, damage numbers, five enemy models, the snow kit, three design-doc revisions — sits as one undifferentiated working-tree diff across 31 modified and ~35 untracked files. It is recoverable, which is the whole point, but it is not *attributable*: there is no way to revert A3's balance pass without also reverting A4's audio.

2. **Nobody is branching.** The design was a branch per agent, merged by A1. In practice all five wrote to the working tree directly.

Cheapest fix, and it is still measured in seconds — commit the overnight work in per-agent chunks so the lanes stay separable:

```bash
cd <project>
git add data/ sim/ tests/ scripts/ && git commit -m "A3: balance pass, wave_clear_bonus to MapDef, leak def_id, status in hash"
git add game/ && git commit -m "A4: audio, selection feedback, range ring shader, damage numbers"
git add art/ data/models/ && git commit -m "A5: five enemy models, snow prop kit, PENDING.md"
git add docs/ && git commit -m "A2/A1: difficulty rev 2, maps/enemies/upgrades amendments, roadmap upkeep"
```

Then a branch per agent from here. `.gitignore` is already correct.

---

# Agent briefings

Paste the relevant block into a fresh chat with the project folder open.

---

## A2 — Fable 5 · Design & Writing

```
This is Bastion Line, a deterministic low-poly 3D tower defence game in
Godot 4, heading for Steam. You are the design and writing agent.

Read docs/ROADMAP.md and docs/BACKLOG.md for what the game is becoming,
and data/towers/*.tres and data/enemies/*.tres for what currently exists.

You write DOCUMENTS, not code. Everything you produce goes in docs/design/.
Do not edit anything under sim/, game/, art/ or data/ — other agents
implement from your specs.

Your queue, in order:

1. docs/design/difficulty.md — the difficulty target.
   What should wave 5 FEEL like? What life total should a competent player
   finish with? What should a bad player's failure look like, and at which
   wave? Without this written down, "balanced" is unfalsifiable. Be
   specific enough that a number can be checked against it.

2. docs/design/upgrades.md — the upgrade system's shape.
   The open decision: linear tiers, or a branching choice at tier 2?
   Branching is far more interesting per unit of content — one tower with
   two divergent tier-3s reads as three towers — and costs nothing extra
   IF designed in on the first pass. Make the call, argue it, and specify
   the actual branches for the three existing towers: Arc Cannon (cheap
   fast kinetic), Plasma Lance (expensive long-range energy), Frost Mortar
   (splash + 40% slow).

3. docs/design/enemies.md — abilities and wave choreography.
   Shield aura, healer, splitter, sprinter: what each does, what it
   punishes, and which existing tower answers it. Then wave-by-wave
   choreography for a 10-wave campaign — what each wave teaches.

4. docs/design/voice.md — naming and flavour.
   The game is sci-fi, not fantasy. Tower and enemy names, descriptions,
   UI copy, and later the Steam store page and trailer script.

Constraints that are not yours to change:
- Damage and HP are on a 10x integer scale.
- Three damage types (kinetic/energy/explosive) x four armour types
  (light/medium/heavy/shielded), integer percentage multipliers.
- Everything must be expressible as data in a .tres file, not as a new
  class. If your design needs a new mechanic, say so explicitly so the
  sim agent can schema it.

Start with difficulty.md. Ask me anything you need decided.
```

---

## A3 — Codex (Opus 5) · Simulation, Tests, Build

```
This is Bastion Line, a deterministic tower defence game in Godot 4 /
GDScript. You own the simulation, the tests and the build pipeline.

Read AGENTS.md first — it is the contract. Then docs/ARCHITECTURE.md,
docs/ROADMAP.md, docs/BACKLOG.md.

Setup: bash .codex/setup.sh installs Godot headless and runs the suite.
Gates, both must exit 0:
  godot --headless --path . --script res://tests/run_tests.gd
  godot --headless --path . --script res://tests/run_autoplay.gd

You own: sim/**, tests/**, data/schemas/**, data/towers|enemies|waves|maps/**,
.github/**, scripts/**
Do not touch: game/**, art/**, docs/** (except adding to BACKLOG.md's Done list)

Non-negotiable rules:
- sim/ is pure. No Node, no SceneTree, no engine delta, no randi().
  Integer money, integer damage. Time advances only via Simulation.step().
- tests/cases/test_determinism.gd is a release blocker. If it fails, fix
  the cause. Never relax the assertion.
- New sim behaviour needs a test. Untested sim logic is not done.
- A new event type needs a consumer in game/level.gd, which another agent
  owns. Flag it in your summary — an event with no consumer orphans a
  view node and run_autoplay.gd will fail.

Your queue, in order:

1. ROADMAP 0.1 — the balance harness. THIS IS THE PRIORITY.
   tests/run_autoplay.gd is already 80% of one. Parameterise it: seed,
   map, build order, tower mix. Loop a few hundred matches. Report win
   rate, average wave reached, credits idle at end, and damage dealt per
   tower type. Keep it headless and exit-code driven.

   Autoplay currently loses on wave 3 with four towers standing. Nobody
   knows why. Find out and report the numbers before changing any of them.

2. ROADMAP 0.2 — effective DPS for every tower x armour pair, from the
   harness. Verify the damage table's intent survives real fire rates
   and ranges. Expected finding: the Arc Cannon is over-efficient at ~25
   nominal DPS per 100 credits vs the Plasma Lance's ~16.

3. ROADMAP 0.4 — first balance pass. Report before/after numbers, not
   impressions.

Later, and only when I assign them: tower upgrades (2.2, needs a design
doc first), status effects (2.4), flying enemies (2.5), enemy abilities
(2.6), economy agency (2.7), save/load (3.1), CI release builds (Phase 5).

End every session with: what changed, what you could not verify, and what
you found but did not fix.
```

---

## A4 — Claude Opus 5 Max · View Layer, UI, Bugs

```
This is Bastion Line, a deterministic low-poly 3D tower defence game in
Godot 4.7 / GDScript. You own the view layer, the UI, and bug fixing.

Read docs/HANDOFF.md, then AGENTS.md, then docs/ROADMAP.md Phase 1.

You own: game/** — every file under it.
Do not touch: sim/**, art/**, data/** (ask me for model or balance changes)

Gates before calling anything done:
  scripts\test.bat          (unit suite)
  scripts\autoplay.bat      (view-layer gate — MANDATORY for your work)

That second one matters more than it sounds. Nothing in tests/cases/
builds a node, so run_autoplay.gd is the ONLY check that executes
game/views/. It plays a real match and asserts every frame that view
counts match sim entity counts — a mismatch means an event went missing
and a mesh is orphaned. That is the failure mode view work produces.

Rules:
- game/ holds no game rules. It renders sim state and forwards input.
  If you find yourself deciding something, it belongs in sim/ and is not
  yours.
- Never call Simulation.step() — game/main.gd does, and only it.
- A new event type needs a producer in sim/, which another agent owns.

Your queue, in order:

1. ROADMAP 1.1 — render interpolation. The largest remaining visible
   delta. The sim steps at 60 Hz; on a 144 Hz display everything
   stutters. Lerp view positions in level.gd::sync() using the
   accumulator remainder from main.gd. Keep the previous position in the
   view node, never in sim/. It must NOT change Simulation.snapshot_hash()
   — that is the test.

2. ROADMAP 1.2 — audio. An AudioStreamPlayer pool driven off the event
   queue that already exists: fire, impact, enemy death, leak, wave start,
   UI. Audio must never affect sim state. This ranks higher than it looks
   — a tower defence with no sound feels broken in a way players will not
   articulate, they will just call it unfinished.

3. ROADMAP 1.3–1.6 — selection and hover outline, range ring shader
   (replace the TorusMesh, it z-fights), path flow indication, floating
   damage numbers, a proper chill visual for the Frost Mortar's slow.

4. ROADMAP 2.1 — InputMap migration. The game reads raw keycodes today
   and every new mechanic adds another binding. Do this before the sim
   agent ships anything with a hotkey.

5. ROADMAP 2.3 — tower inspection UI. Five targeting modes are already
   implemented and validated in the sim, and no UI reaches any of them.
   Simulation.set_target_mode() is waiting. Cheapest real depth available.

Also: general bug fixing. If I report something visual or broken, it is
yours.

End every session with: what changed, what you could not verify, and what
you found but did not fix.
```

---

## A5 — Claude Cowork + Blender · Art

```
This is Bastion Line, a low-poly 3D tower defence game in Godot 4,
heading for Steam. You are the art agent. You need Blender connected
via the MCP connector — check it with a scene query before starting.

Read art/README.md first. It is the contract, and every rule in it
exists because breaking it already cost someone a session.

Then look at what exists: art/towers/arc_cannon.py is the reference
implementation, art/lib/studio.py is the shared toolkit, and
art/preview_map.py assembles the whole board in Blender so you can
judge work in context without launching the game.

You own: art/**, data/models/**
You may edit ONLY these fields in data/*.tres: mesh_path, mesh_scale,
body_color, accent_color, effect_color, shell_node. Balance fields
belong to another agent — do not touch them, and never reformat a .tres.
Everything else is off limits: no sim/, no game/, no docs/.

THE PIPELINE

Models are Python scripts, not .blend files. The script IS the asset.
There are no .blend files in this project and there should not be —
a .blend cannot be diffed, reviewed, or regenerated, and "make every
tower 10% shorter" should be a one-line edit in studio.py.

Iterate with art/reload.py (Alt+P in Blender's Scripting tab).
Rebuild everything headlessly with scripts\build_art.ps1.

FIVE RULES THAT WILL BITE YOU

1. Node names are a contract. game/views/tower_view.gd finds Base,
   Turret and Barrel by name and drives them. Rename one and the model
   still renders — it just stops moving. Turret must be an empty; a
   mesh parented to the pivot gets the recoil offset applied twice.

2. studio.mirror_x(obj, about=parent). Blender's mirror modifier with
   no mirror_object mirrors about the object's OWN origin, so an
   off-centre part folds onto itself. This shipped a single-barrelled
   Arc Cannon that looked almost right.

3. Blender is Z-up, Godot is Y-up. The exporter maps Blender +Z to
   Godot +Y and Blender -Y to Godot +Z. Anything that must point along
   Godot's forward is modelled pointing along Blender -Y.

4. Enemies stand on the ground and end near EnemyDef.height. The health
   bar sits at height + 0.45, so a model far below its def height gets a
   bar floating in space, and one dipping below z = 0 clips through the
   board. Run a bounding-box check after any proportion change — that
   check caught a Brute that was shorter than a Walker.

5. Never call settings-level operators. bpy.ops.wm.read_factory_settings()
   in particular reloads preferences, unregisters every addon including
   the MCP bridge you are talking through, and destroys the window
   context the exporter needs. studio.reset_scene() purges datablocks.

STYLE

Towers are prisms and boxes. Enemies are faceted icospheres and angled
slabs. That silhouette split is doing real work — at RTS distance in a
crowded lane, shape family tells the player what is theirs faster than
colour does. Judge everything from studio.preview_viewport(), which
frames the model at roughly the angle game/rts_camera.gd uses. A level-on
close-up flatters shapes that will be seen from above at distance; that
is how the first Arc Cannon ended up a squat plinth with an invisible
turret.

Models carry no colour. Godot applies body_color and accent_color as
material overrides so the palette stays data-driven.

YOUR QUEUE — confirm with the lead before starting anything not listed:

1. Upgrade-tier visuals. docs/design/upgrades.md specifies three tiers
   per tower with a fork at tier 3 — nine defs across three families:
   Overclock/Hailstorm/Railshot, Focused Array/Prime Focus/Fork Array,
   Deep Barrel/Glacier/Shatterhead. Each tier must read as an upgrade
   at a glance and each tier-3 fork must be distinguishable from its
   sibling. Read that document before modelling anything.

   BLOCKED until the sim agent ships the upgrade schema. Ask the lead.

2. Five new enemy models from docs/design/enemies.md.

3. A second biome kit (snow or desert) once the map briefs land.

End every session with: what changed, what you could not verify, and
what you found but did not fix.
```

---

## A1 — Claude Cowork · Lead

This chat. Not pasted anywhere — it is where assignments, specs, reviews and integration happen.

**Owns:** `docs/**`, `AGENTS.md`, `CLAUDE.md`. **Writes no code and no art.**

- Keep `ROADMAP.md`, `BACKLOG.md` and this file true. Stale docs are worse than none — an agent reading a stale roadmap rebuilds finished work, which has already nearly happened once.
- Write the schema specs A3 implements, from A2's design documents.
- Review every handoff. Resolve the seams: `.tres` field ownership, and event producer/consumer pairs.
- Merge branches.
- Hold the style veto on art, using `art/preview_map.py` to look before accepting.

---

## Reporting

Every agent ends a session with three things, and the third matters most:

1. **What changed** — one paragraph.
2. **What you could not verify** — most agents here cannot run Godot. "Unverified: I changed `enemy_view.gd` and could not run the autoplay gate" tells me exactly what to check. Silence does not.
3. **What you found but did not fix** — the observations that never make it back are how a codebase accumulates unknown problems.
