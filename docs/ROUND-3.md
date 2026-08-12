# Round 3 — assignments

Paste one section into one chat. Each prompt is self-contained.

## Round 2 landed clean — verified, not assumed

All four agents delivered and **every cross-agent seam held**. What I checked:

- **`upgrade_ids` graph is closed.** Every id referenced by a tier resolves to a file
  that exists. `plasma_lance_t2` offers only `t3a` — A3 honoured the Fork Array
  deferral instead of half-building it.
- **`TOWER_UPGRADED` is consumed.** A4 resolved the enum *by name* (`Types.Event.get("TOWER_UPGRADED", -1)`)
  rather than hard-coding 17, because at the time it wrote the consumer A3 hadn't
  declared the member yet — so the code was inert rather than wrong, and started
  working the moment the sim landed. That is the correct answer to a parallel-session
  race and it is worth keeping as a pattern.
- **The accent hazard did not fire.** A5 warned that a pure `Body*`/`Accent*` prefix
  swap would leave all three shipped towers untinted, since none of `Base`, `Plinth`,
  `TurretHead`, `AmmoDrum`, `Sight` or `Muzzle` matches either prefix. A4 shipped
  *additive* matching — prefix **or** legacy list — and also replaced `find_child`
  with an iterator over all matches, which fixes Hailstorm's six barrels and Glacier's
  eight vanes going half-grey. Two agents in separate chats converged correctly.
- **No dangling content references.** The ten Corridor waves name only the five enemy
  defs that exist.
- **`difficulty.md` §4 is rewritten over policy classes**, with the dead 200-seed
  methodology explicitly retired in the text.

Nine tier meshes, nine tier defs, a second map with ten waves, an upgrade panel and a
tower inspection UI. Good round.

## Two things to do before starting round 3

**1. Commit. There are 130 uncommitted files.** Everything above exists only in your
working copy.

```powershell
cd "C:\Users\bessr\OneDrive\Desktop\Claude_DB\Claude_memory\Projects\Personal\TowerDefence"
git add -A
git commit -m "Round 2: tower upgrades, The Corridor, upgrade UI, nine tier meshes"
git push
```

**2. The Corridor is unreachable.** `game/main.gd:32` calls `catalog.first_map()` and
always has. A2 shipped a complete second map with ten waves and **no player can get to
it** — there is no menu, no level select, nothing that picks a map. This is now the
single biggest gap between what the project contains and what the project *is*, and it
is why A4's task this round is what it is.

---

## The pinned contract

A3 defines enemy abilities this round; A4 renders them and A5 models one of them.
Fixed by the lead so all three can work simultaneously.

```
SCHEMA    EnemyDef.ability: int          — enum, 0 = NONE. Never a subclass per ability.
          EnemyDef.ability_radius: float
          EnemyDef.ability_percent: int  — integer percent, never a float multiplier
          EnemyDef.ability_amount: int
          EnemyDef.ability_interval: int — ticks
          EnemyDef.spawn_on_death: PackedStringArray
          EnemyDef.flies: bool           — ignores the path, straight line spawn->goal
EVENTS    {"type": ENEMY_HEALED,  "enemy_id": int, "amount": int, "hp": int}
          {"type": ENEMY_SPLIT,   "enemy_id": int, "spawned": PackedInt32Array}
          {"type": AURA_APPLIED,  "enemy_id": int, "source_id": int}
ABILITY   NONE=0 · AURA=1 · HEAL_PULSE=2 · SPLIT_ON_DEATH=3
```

`ability_percent` is an integer because `docs/design/enemies.md` is explicit that the
Warden's reduction folds into the damage computation as a **second percentage in a
single division** — `base × armour% × aura% / 10000` — exactly the way splash falloff
already does. A separate division re-opens the double-truncation wound the 10× rescale
closed.

## Ownership — unchanged from round 2

| Agent | Owns | Must not touch |
| --- | --- | --- |
| A3 Codex | `sim/**`, `tests/**`, `data/schemas/**`, `data/towers/**`, `data/enemies/**` | `game/**`, `art/**`, `data/waves/**`, `data/maps/**` |
| A2 Fable | `docs/design/**`, `data/waves/**`, `data/maps/**` | `sim/**`, `game/**`, `art/**`, `data/enemies/**`, `data/towers/**` |
| A4 Opus Max | `game/**` | `sim/**`, `data/**`, `art/**` |
| A5 Art | `art/**`, `data/models/**` | all code, all `.tres` |

**`data/enemies/` moves from A2 to A3 this round** — the four remaining enemies are
ability-bearing, and their defs cannot be written until the schema fields exist. A2
keeps `data/waves/` and `data/maps/`.

---

# A3 — Codex (Opus 5) · Enemy abilities

You are A3 on **Bastion Line**, a deterministic 3D tower defence game in Godot 4.7 /
GDScript. Read `AGENTS.md` first — it is the single source of truth for architecture,
commands and the definition of done. Then read `docs/design/enemies.md` in full.

**You own `sim/**`, `tests/**`, `data/schemas/**`, `data/towers/**` and — new this
round — `data/enemies/**`. You must not open `game/**`, `art/**`, `data/waves/**` or
`data/maps/**`.**

## Your task: make four built-but-inert enemies real

Four enemy models are modelled, exported and sitting in `data/models/enemies/` doing
nothing, because each needs a mechanic the sim doesn't have. `enemies.md` §2 specifies
all four completely — stats, radii, intervals, and an explicit integer rule per
ability. This is implementation, not invention.

The contract is fixed by the lead because A4 and A5 are building against it now:

```
SCHEMA    EnemyDef.ability: int          — enum, 0 = NONE. Never a subclass per ability.
          EnemyDef.ability_radius: float
          EnemyDef.ability_percent: int
          EnemyDef.ability_amount: int
          EnemyDef.ability_interval: int — ticks
          EnemyDef.spawn_on_death: PackedStringArray
          EnemyDef.flies: bool
EVENTS    {"type": ENEMY_HEALED,  "enemy_id": int, "amount": int, "hp": int}
          {"type": ENEMY_SPLIT,   "enemy_id": int, "spawned": PackedInt32Array}
          {"type": AURA_APPLIED,  "enemy_id": int, "source_id": int}
ABILITY   NONE=0 · AURA=1 · HEAL_PULSE=2 · SPLIT_ON_DEATH=3
```

`enemies.md` requires abilities be **composable data-selected behaviours behind an
enum — never a subclass per ability** (ROADMAP 2.6). Hold that line; it is what keeps
the fifth ability cheap.

In the order I'd take it:

1. **Warden — `AURA`.** Allies within 4.0 take 60% of computed damage. Excludes itself
   and any other aura-bearer; non-stacking, overlapping auras apply once. Fold it into
   the damage computation as a second percentage in **one** division —
   `base × armour% × aura% / 10000`. Membership evaluated per tick in fixed entity-array
   order.
2. **Mender — `HEAL_PULSE`.** Every 120 ticks, +300 HP to living non-Mender allies
   within 4.5, capped at `max_hp`. Never heals itself or another Mender.
   **Anchor each Mender's schedule on its own spawn tick** (spawn + 120, + 240, …).
   ROADMAP trap #2 is the wave director doing exactly this wrong once already — a
   schedule anchored on a tick nobody steps.
3. **Fission Crawler — `SPLIT_ON_DEATH`.** Spawns 2 × `fission_spawn` at the parent's
   exact path progress, same tick. `fission_spawn` never appears in a spawn group, so
   **`Catalog.validate()` must accept an enemy referenced only by an ability** — right
   now it would almost certainly flag it as orphaned.
4. **Skiff — `flies`.** Ignores the path: straight line spawn to goal at fixed cruise
   height. The model carries a built-in 0.42 float; the real altitude is your call and
   the health bar rides on it, so put the number somewhere A4 can read it. Towers need
   `can_target_air`; **no Frost Mortar tier may ever target air** — that hole is the
   mortar family's declared price (`upgrades.md` §6) and the Skiff is what collects it.
5. **The five defs.** `warden`, `mender`, `fission_crawler`, `fission_spawn`, `skiff`.
   Stats from `enemies.md` §2; presentation fields from `art/PENDING.md` §1, whose
   `height` values were measured off the exported `.glb` — do not adjust them to taste,
   the health bar hangs off them.

Two invariants from the design that are easy to break by accident: the Warden's 2,600
HP must stay above the 2,400 Shielded Scouts it escorts, and the Mender's 1,800 above
the 1,700 Walkers it marches with. Both exist so Strongest targeting picks the support
out of its escort. They are not coincidences.

## Definition of done

- `run_tests.gd` exits 0; `run_autoplay.gd` exits 0 with **zero `ERROR:` and zero
  `WARNING:` lines**
- `test_determinism.gd` green — and note that three of these four abilities mutate
  entity state outside the normal damage path, so `snapshot_hash()` must cover healed
  HP, aura membership and split offspring, or a replay diverges silently
- `scripts/balance.bat` run against a wave containing each new enemy

Per `enemies.md`, measure fliers as **their own column**: the Skiff's spawn-goal chord
is ~40 units against the Walker's 122-unit tour, so its per-second threat density is
far higher than 900 HP suggests.

## Report back

What you built, what the harness showed, which numbers you moved. Specifically: how
you made `Catalog.validate()` accept `fission_spawn`, what cruise altitude you chose
for the Skiff, and whether aura/heal state needed adding to `snapshot_hash()`.

---

# A2 — Fable 5 · The Crossing's full campaign, and the menu question

You are A2 on **Bastion Line**, a deterministic 3D tower defence game in Godot 4.7.
You own game design. Read `docs/design/README.md`, then your own `maps.md`,
`enemies.md` and `difficulty.md`.

**You own `docs/design/**`, `data/waves/**` and `data/maps/**`. You must not touch
`sim/**`, `game/**`, `art/**`, `data/enemies/**` or `data/towers/**`.** `data/enemies/`
has moved to A3 this round — the four remaining enemies need schema fields only A3 can
add. Your specs for them are what A3 is building from right now.

Your Corridor shipped clean: ten waves, no dangling references, and the map boots. Your
`difficulty.md` §4 rewrite over policy classes is the right instrument and it retired
the dead seed methodology in the text, which is how that should have been done.

## Your task

1. **Extend The Crossing to ten waves.** It has five; the Corridor has ten. Same
   grammar — one new fact per wave, exams recombine. You may now use the Courser, and
   you may assume Warden, Mender, Fission Crawler and Skiff exist by the time these are
   played, since A3 is building all four this session. Write waves 6–10 against the
   full roster and mark clearly in the file which waves depend on abilities landing.
2. **The upgrade system exists now** — nine tiers, three families, shipped and
   balance-passed. Your wave choreography was written before it did. `upgrades.md` §4
   says Hailstorm's honesty depends on wave choreography supplying tight packs
   ("enemies.md tightens late drone intervals specifically for this"). Check that the
   waves actually do it, and say so either way.
3. **Decide the meta question — this is the one I most want from you.** `BACKLOG.md`
   item 9 says: *"Between-run unlocks or a campaign map. Decide which before building
   either; they pull the game in different directions."* Two maps now exist and there
   is no way to reach the second. A4 is building a menu and level select this session
   and needs to know what it is a menu *for*. Write `docs/design/campaign.md`: is this
   a linear campaign, a hub, an unlock tree? Does finishing the Crossing gate the
   Corridor? Is there anything persistent between runs at all?

   Keep it small enough to ship. The honest constraint is that this is a solo project
   with agent labour, and a meta-progression system is the classic thing that eats a
   year. Argue for the smallest structure that makes two maps feel like a game rather
   than a demo with a dropdown.

4. **Courser bounty.** `enemies.md` §2 says 10; `courser.tres` shipped at 8. Both are
   in your lane and 8 may well be the tuned value — just reconcile them so the document
   and the data agree.

## Definition of done

`run_tests.gd` exits 0 — it boots every shipped map and runs the pathfinder over each,
so a malformed wave or a dangling enemy reference fails there. If a wave you wrote
references an enemy A3 hasn't landed yet, that suite will go red; keep those waves in a
separate file and say so rather than guessing at timing.

## Report back

The wave list with reasoning per wave, your campaign decision and the argument for it,
and whether the existing choreography actually delivers the packs Hailstorm needs.

---

# A4 — Opus 5 Max · Menus, and making the second map reachable

You are A4 on **Bastion Line**, a deterministic 3D tower defence game in Godot 4.7.
You own the view layer. Read `AGENTS.md`, then `docs/ARCHITECTURE.md`.

**You own `game/**` and nothing else. You must not touch `sim/**`, `data/**` or
`art/**`.**

Last round you did two things worth repeating. You resolved `TOWER_UPGRADED` by
enum *name* so your consumer was inert rather than wrong while A3 was still writing the
producer — that is the right answer to a parallel-session race. And you made accent
tinting additive instead of a pure prefix swap, which is the only reason all three
shipped towers didn't go grey. Same judgement needed this round.

## The gap

`game/main.gd:32` calls `catalog.first_map()`. There are now two maps. **Nobody can
reach the second one.** A2 shipped The Corridor with ten waves and it is unplayable —
not broken, just unreachable. That is your round.

## Scope

1. **Main menu, level select, pause menu** (`BACKLOG.md` item 8). Level select is the
   load-bearing half; the rest can be plain. A2 is writing `docs/design/campaign.md`
   this session which decides whether maps are gated, listed, or a hub — **check for
   that file before you design the flow**, and if it isn't there yet, build the
   dropdown version and leave the gating hook obvious.
2. **Settings: resolution, volume, key rebinding.** Rebinding means an `InputMap`
   layer — the game reads raw keycodes today, which is fine for a prototype and not
   fine for shipping. Do this now, while there are 12 bindings and not 40.
3. **Ability VFX.** A3 is adding three events this session against a contract fixed by
   the lead. Consume them the same way you consumed `TOWER_UPGRADED` — by name, so
   your code is inert if A3 lands after you:

   ```
   {"type": ENEMY_HEALED, "enemy_id": int, "amount": int, "hp": int}
   {"type": ENEMY_SPLIT,  "enemy_id": int, "spawned": PackedInt32Array}
   {"type": AURA_APPLIED, "enemy_id": int, "source_id": int}
   ```

   A Mender pulse needs a visible ring or the healed enemy's bar jumping backwards
   reads as a bug — `enemies.md` says exactly this. The Warden's aura needs a
   persistent radius indicator, or "shoot the shepherd" is a lesson the game never
   teaches. `ENEMY_SPLIT` creates two enemies, so unlike `TOWER_UPGRADED` the
   view-count assert *will* catch a missing consumer — that one is safe.
4. **The Skiff flies.** A3 is choosing a cruise altitude and putting it where you can
   read it. A flier's view must sit at that height and its health bar above that, not
   on the ground plane.

If the session fills, items 1 and 2 are the ones that matter. Ability VFX can slip a
round; an unreachable map cannot.

## Definition of done

`run_autoplay.gd` exits 0 with **zero `ERROR:` and zero `WARNING:` lines**. Nothing in
`tests/cases/` builds a node, so autoplay is still the only check in the project that
executes your code at all. If you add a menu scene that autoplay doesn't traverse, say
so — that is a real coverage gap and I would rather know about it than not.

## Report back

What the menu flow is, whether `campaign.md` had arrived from A2 in time to shape it,
which ability events you wired versus left speculative, and any new code path autoplay
does not reach.

---

# A5 — Claude + Blender MCP · The desert, and the Fission Spawn

You are A5 on **Bastion Line**. You own the art pipeline. Read `art/README.md` — it is
the contract.

**You own `art/**` and `data/models/**`. You must not open any `.tres` file.** Record
anything you need from one in `art/PENDING.md` as a one-line edit for the lead.

Your last round was the best kind of art delivery: nine tier meshes, and a `PENDING.md`
§3 that predicted a cross-agent break before it happened. You worked out that a pure
prefix swap would leave all three shipped towers untinted, recommended additive
matching, and named your nodes to survive *either* decision. A4 shipped exactly your
recommendation, and also fixed the `find_child` first-match-only problem you flagged —
so Hailstorm's six barrels and Glacier's eight vanes will all tint. **Both of your
open worries are closed.** Nothing to do there.

## Your task

1. **The desert biome kit for The Corridor.** `docs/design/maps.md` §4.6 is your brief.
   The Corridor shipped this round and currently dresses itself from the hardcoded
   grassland prop list, which will look wrong the moment anyone plays it. Build the kit
   the same way you built the snow set.
2. **Fission Spawn.** `enemies.md` §2 defines it (450 HP, speed 6.5, Light) and A3 is
   writing its def this session, so it needs a model. Your own `PENDING.md` notes
   `fission_crawler.py` is factored into a `build_segment()` function precisely so the
   child can be one segment of its parent — collect on that. It must read as
   *obviously* a piece of its parent at RTS distance, since that is the entire
   readability of the split mechanic.
3. **The prop-table problem is still open and still blocking both biomes.**
   `board.gd::_scatter_props()` hardcodes seven grassland `.glb` paths. Your eight snow
   props and `crystal.glb` are built and scattered by nobody, and the desert set will
   land in the same limbo. The durable fix is a prop list on `MapDef` — an A3 schema
   change plus an A4 consumer. **Write the ask in `PENDING.md` as a concrete proposal**
   — field name, shape, and the weights for all three biomes — so it can be handed to
   A3 as a ready task rather than a discussion.

## Definition of done

Every script exports, a full pipeline regression, `art/PENDING.md` updated. Verify by
parsing the exported glTF node hierarchy, not by trusting the export log — that habit
is what caught the Brute being shorter than the Walker and the Walker's def being
wrong.

## Report back

Measured bounding boxes, whether the Fission Spawn reads as its parent's segment at RTS
distance, and the prop-table proposal.

---

## Deliberately not in this round

- **Fork Array** (Plasma Lance 3B). Still deferred; the model exists, the def does not.
  It needs multi-target selection and it can ride with a later targeting pass.
- **The Fork map.** Needs multi-route pathfinding (`maps.md` §3). It is the natural A3
  round after abilities.
- **Steam anything.** `docs/STEAM.md` is written and correct; nothing in it is
  actionable until the game is worth wishlisting.

## Lead tasks

- Commit and push. 130 files.
- Branch-per-agent workflow into `AGENTS.md`. Round 2 proved the agents converge on a
  pinned contract; what they don't have is a way to *not* overwrite each other's files
  when two sessions run against one working copy.
- Apply `art/PENDING.md` §1 presentation fields if A3 doesn't pick them up with the
  ability defs.
