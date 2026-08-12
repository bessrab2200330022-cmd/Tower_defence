# Enemies — abilities and wave choreography

**Owner:** A2 (design) · **Feeds:** ROADMAP 2.5 (fliers), 2.6 (abilities), and the 10-wave campaign · **Implemented by:** A3 (sim, schema, wave data), A1 (models), A4 (views)

Every ability below is written in integers over ticks, because "sometimes" cannot ship (`docs/design/README.md`). Per ROADMAP 2.6, abilities are **composable data-selected behaviours behind an enum — never a subclass per ability**. Where a design needs sim support that doesn't exist, it is flagged in place and collected in §4.

---

## 1. The existing four, and what each is for

| Enemy | Stats (as shipped) | Role in the curriculum |
| --- | --- | --- |
| Scout Drone | 600 HP · 7.0 · Light · bounty 8 · leak 1 | Volume. Teaches placement and rate-of-fire. |
| Line Walker | 1,700 HP · 4.5 · Medium · bounty 14 · leak 1 | The baseline ruler — every other enemy is measured against it. |
| Shielded Scout | 2,400 HP · 5.2 · Shielded · bounty 26 · leak 1 | **The damage table made flesh.** Kinetic bounces; the Lance answers. |
| Siege Brute | 5,200 HP · 2.8 · Heavy · bounty 34 · leak 2 | Time pressure in slow motion. Teaches sustained focus and slow. |

These four cover HP, speed and armour. What they cannot do is change *how the player must think* mid-wave — every current threat is answered by standing DPS in the right colour. The five below each break one assumption the current roster lets players keep.

---

## 2. The new roster

Stat blocks are `.tres`-ready. A design rule used twice here and worth naming: **support units carry slightly more HP than the escorts they accompany**, so the Strongest target mode naturally finds them — the counter-play is already in the sim, waiting for 2.3's UI.

### Courser — the sprinter

| | |
| --- | --- |
| Stats | **500 HP · speed 9.5 · Light · bounty 8 · leak 1** — bounty rescaled from the drafted 10 when the whole roster's bounties moved (drone 8→6, walker 14→11, scout 26→21, brute 34→27, in the credit retune); 8 keeps the drafted intent of ~1.3× the drone's rate |
| Breaks the assumption | "I have time to react." |
| Punishes | Sniper-heavy builds (a Lance's 1.1s cycle overkills 500 HP and can't keep pace with a stream); builds with no slow. |
| Answered by | Arc Cannon line fire, any Frost Mortar (a 40% slow hurts speed the most where speed is the stat), Hailstorm. |
| Sim needs | **None. Pure data.** The Courser is proof the existing schema already contains a fourth enemy archetype — it can ship the day its `.tres` and model exist. |

At 9.5 it crosses The Crossing's 122-unit path in ~13s against the Walker's 27. Twice the speed at 30% of the HP: the same DPS kills it, but only if the DPS is *standing where the Courser will be*, which is the lesson.

### Skiff — the flier (ROADMAP 2.5)

| | |
| --- | --- |
| Stats | **900 HP · speed 6.0 · Light · bounty 18 · leak 1** |
| Route | Ignores the path: straight line, spawn to goal, at fixed cruise height. |
| Breaks the assumption | "The path is where the game happens." |
| Punishes | Chokepoint-anchored builds — a perfect mortar kill-box is a thing Skiffs fly over. |
| Answered by | Arc Cannon and Plasma Lance (all tiers, both families, `can_target_air = true`). **No Frost Mortar tier targets air, ever** — that hole is the mortar family's price ([upgrades.md](./upgrades.md) §6) and this enemy is what collects it. |

Tuning note for the harness: air HP must be tuned against **chord exposure, not path exposure**. On The Crossing the spawn-goal chord is ~40 units — a Skiff is on the board for a quarter of a Walker's tour, so per-second threat density is far higher than 900 HP suggests. Measure fliers as their own column.

### Warden — the shield aura

| | |
| --- | --- |
| Stats | **2,600 HP · speed 4.0 · Shielded · bounty 40 · leak 1** |
| Ability | `AURA`: living allies within **4.0** take **60%** of computed damage (a 40% reduction). Applies to every ally in radius except itself and any other aura-bearer. Non-stacking: overlapping auras apply once. |
| Breaks the assumption | "Damage is fungible — shoot whatever is in range." |
| Punishes | Spray-and-pray; splash-first builds that shear the herd and leave the shepherd. |
| Answered by | Killing the Warden first: Strongest targeting finds it (2,600 sits above its Shielded Scout escorts at 2,400 — invariant, keep it above whatever it escorts), and Prime Focus two-shots the escorts once it's down. Energy damage generally — the Warden itself is Shielded. |

**Integer rule for A3:** fold the aura into the damage computation as a second percentage in a *single* division — `base × armour% × aura% / 10000` — exactly the way splash falloff already folds in. Applying it as a separate division re-opens the double-truncation wound the 10× rescale closed. Aura membership is evaluated per tick in fixed entity-array order.

### Mender — the healer

| | |
| --- | --- |
| Stats | **1,800 HP · speed 4.5 · Medium · bounty 36 · leak 1** |
| Ability | `HEAL_PULSE`: every **120 ticks**, restore **300 HP** to every living non-Mender ally within **4.5**, capped at each target's `max_hp`. The Mender never heals itself or another Mender — no mutual-tank loops, no infinite pairs. |
| Breaks the assumption | "Chip damage accumulates." |
| Punishes | Wide low-rate damage (base mortars, unfocused fire) — 150 HP/s of regional healing simply erases it. |
| Answered by | Alpha that outruns the pulse (Railshot, Prime Focus), or killing the Mender first — at 1,800 it sits above the 1,700 Walkers it marches with, so Strongest picks it out. That 100 HP gap is a tuning invariant, not a coincidence. |

**Determinism note:** anchor each Mender's pulse schedule on **its own spawn tick** (spawn tick + 120, + 240, …). The wave director has already been bitten once by a schedule anchored on a tick nobody steps — ROADMAP's trap #2. Emit an `ENEMY_HEALED` event carrying id, amount and resulting HP; the view needs it for the pulse ring, and a healed enemy whose health bar doesn't move reads as a bug.

### Fission Crawler — the splitter

| | |
| --- | --- |
| Parent | **2,200 HP · speed 4.2 · Medium · bounty 12 · leak 2** |
| On death | `SPLIT_ON_DEATH`: spawns **2 × Fission Spawn** at the parent's exact path progress, same tick. |
| Fission Spawn | **450 HP · speed 6.5 · Light · bounty 4 · leak 1.** Never appears in a spawn group; exists only as split offspring. A normal enemy def otherwise — the catalog cross-reference check must accept an enemy referenced by an ability rather than a wave. |
| Breaks the assumption | "A kill is progress." |
| Punishes | Killing late: a Crawler dying at 80% releases two 6.5-speed children with a fifth of the path left. Also punishes overkill alpha — Prime Focus spends 1,000 on a 2,200 body and still faces the children. |
| Answered by | Front-loaded damage (kill Crawlers early, children walk the whole path into your guns), splash at the death zone, Glacier near the goal as insurance. |

Leak arithmetic is deliberately neutral: a leaked parent costs 2, a parent killed at the goal-mouth costs its children's 2 — no perverse incentive to *let* it leak; killing early is the only profit. Family bounty totals 20.

**Determinism note (ROADMAP names this the real risk):** children spawn at the parent's exact path position in the same tick its death is processed, with sequentially assigned ids in fixed order; event order is `ENEMY_KILLED` (parent) then two `ENEMY_SPAWNED`. Spawning mid-path must go through the same movement bookkeeping as spawn-point entry — this needs its own test, and the test is a release gate for the Crawler.

---

## 3. The counter-matrix

One row per threat, one honest answer per row — if a row's answer is ever "nothing", that's a design bug to bring back here.

| Threat | Best answer | Second answer | Trap answer |
| --- | --- | --- | --- |
| Drone / Courser flood | Hailstorm, Arc line | Shatterhead, any slow | Prime Focus (overkill per shot) |
| Walker column | Any sustained DPS | — | — |
| Shielded Scout stream | Focused Array / Fork Array | base Lance | anything kinetic (G8's 3:1 floor) |
| Siege Brute | Prime Focus + Glacier | Focused Array + any slow | Shatterhead (60% vs Heavy) |
| Skiff | Arc family (flak) | Lance family | any Mortar (cannot fire) |
| Warden pack | Strongest-mode Lance on the Warden | Railshot alpha | splash into the aura |
| Mender column | Kill Mender first (Strongest) | Railshot / Prime alpha | wide chip damage |
| Fission Crawler | Kill early + splash at death | Glacier at the goal | late-path sniper alpha |

---

## 4. Consolidated schema asks (A3)

1. **Ability enum + parameters on the enemy def** — `NONE / AURA / HEAL_PULSE / SPLIT_ON_DEATH`, with integer fields sufficient for: radius ×10 (integer world-units-times-ten, or a float if A3 prefers — design only needs one decimal), percent, period ticks, amount, child id, child count. One enemy, one ability, for now — composition can wait until a design actually needs two.
2. **Aura hook in damage application** — single-division fold (§2 Warden).
3. **`ENEMY_HEALED` event** — producer sim, consumer view: the WORKSTREAMS event-pair seam; flag it in the shipping session's summary.
4. **Mid-path spawn support** — for split children, with its own determinism test (§2 Crawler).
5. **`can_target_air` on tower defs + the air lane** — ROADMAP 2.5's own list. Arc and Lance families true, Mortar family false, all tiers.
6. **Slow-stacking rule** — strongest-wins, non-stacking (shared with upgrades.md §6; lands with 2.4's status stack).

Nothing else in this file needs new sim behaviour. The Courser needs literally nothing.

---

## 5. The ten-wave campaign

Waves 1–5 are the shipped data, restated for the arc; retunes to them belong to the balance pass, not this file. Waves 6–10 are new, designed against a **post-upgrade (2.2) kit** — do not ship them to players before upgrades exist. Lives bands are the [difficulty.md](./difficulty.md) §8 targets for the S2 player.

**The grammar:** each wave introduces exactly one new fact; exam waves (5, 8, 10) recombine facts already taught. The player should never meet two new ideas in the same wave.

| # | Name | Composition (enemy · count · start delay · interval, ticks) | Teaches | S2 lives |
| --- | --- | --- | --- | --- |
| 1 | Probing Run | drone·8·0·45 | Placement | 0 |
| 2 | Pressure | drone·12·0·30 → walker·3·240·75 | Volume; tank exists | 0–1 |
| 3 | First Shields | walker·9·0·50 → shielded_scout·3·300·90 | **The damage table** | 0–2 |
| 4 | Armour Test | shielded_scout·7·0·55 → walker·8·120·45 → brute·1·420·60 | Heavy armour | 0–2 |
| 5 | Breakthrough | drone·16·0·22 → shielded_scout·6·180·60 → brute·3·300·150 | First exam | 1–3 |
| 6 | **Skyfall** | drone·10·0·24 → walker·4·240·60 → **skiff·5·420·90** | The air lane | 0–2 |
| 7 | **Stampede** | courser·6·0·30 → drone·14·240·**12** → courser·6·480·18 → walker·3·600·60 | Speed; slow's value | 0–3 |
| 8 | **Phalanx** | walker·6·0·50 → warden·1·300·1 + shielded_scout·4·330·55 → warden·1·600·1 + shielded_scout·4·630·55 | Kill the source | 0–3 |
| 9 | **Fission** | crawler·6·0·90 → walker·6·180·50 + mender·1·210·1 + mender·1·390·1 → skiff·2·520·120 | Overkill economics | 0–3 |
| 10 | **Breakwater** | drone·16·0·12 + courser·8·120·18 → brute·4·420·180 + mender·1·480·1 → warden·2·900·60 + shielded_scout·6·930·45 → brute·2·1400·30 | Final exam | 2–4 |

Choreography intent, wave by wave:

- **6 · Skyfall.** Ground pressure first, so the guns are busy — then the first Skiff sails *over* the mortar chokepoint untouched. The wave is scripted so the player watches it happen with time to add flak before the next four. One new fact: the sky exists.
- **7 · Stampede.** The 12-tick drone pack is deliberately Hailstorm's showcase and the harness's clump fixture ([upgrades.md](./upgrades.md) §4 depends on packs this tight existing). Coursers bracket it so pure-sniper kits feel the wind. No new damage types — this wave is about *time*.
- **8 · Phalanx.** Two shield walls, each led by a Warden marching 30 ticks ahead of its escorts. Massed fire into the pack visibly underperforms until the Warden pops — the aura's collapse (shell shatter, see §6) is the reward image. Strongest targeting solves the wave almost by itself; 2.3's UI earns its keep here.
- **9 · Fission.** Crawlers spaced wide at the front so early kills are *possible* and late kills are *punished*, Menders buried in the Walker column erasing chip damage, two Skiffs late as a discipline check. The kill-order wave.
- **10 · Breakwater.** Four movements: flood (Hailstorm's exam), siege (focus-fire under healing — Prime Focus's exam), shield wall (the Phalanx repeat, harder), and a final near-simultaneous Brute pair through whatever remains. Wave 5's name was Breakthrough; wave 10 answers it. The last enemy of the campaign should die — or not — in the final third of the path on a median run.

**Proposed retune of waves 1–5:** none. The wave-3 anomaly (difficulty.md §6) looks like script/coverage behaviour, not wave data; measure before touching the tables above.

---

## 6. Readability notes (A1, A4)

ROADMAP Phase 4 already warns the palette leans on colour alone. Every new enemy therefore gets a **shape-and-motion identity** first, colour second:

- **Courser** — lowest silhouette in the game, forward-raked, visible dust/thrust trail. Speed must read from the model standing still.
- **Skiff** — altitude *is* the identity; nothing else flies. Gentle bob on the cruise (view-side only, never sim position).
- **Warden** — a rotating projector mast, and the aura drawn as a faint translucent film over *protected escorts* (the Shielded Scout's `shell_node` pattern generalises). The film vanishing when the Warden dies is the tutorial.
- **Mender** — a visible pulse ring on each heal (driven by `ENEMY_HEALED`), plus a brief glow on healed targets. No ring, no comprehension.
- **Fission Crawler** — segmented body with a visible seam; the death split should read as the body *coming apart into the two children*, not two spawns popping in.

---

## 7. Economy across ten waves

| Source | Credits |
| --- | --- |
| Starting credits | **Crossing's tuned value** — the harness measured the playable window at 560–960; see difficulty.md §7 |
| Waves 1–5 bounties (shipped data) | 64 + 138 + 204 + 328 + 386 = 1,120 |
| Wave 6 | 226 |
| Wave 7 | 274 |
| Wave 8 | 372 |
| Wave 9 (incl. 48 from Fission Spawns) | 312 |
| Wave 10 | 684 |
| **Campaign total** | **2,988 bounty + the tuned start** |

The bounty numbers above are **pre-rescale opening bids**: they were drafted when the start was 320, and the harness has since moved the start into the 560–960 window. The design rule they were built to serve is the thing that survives: **total campaign income lands ~10% short of a fully-forked six-tower kit (~2,840 at current [upgrades.md](./upgrades.md) prices) plus a real run's extra base towers, and waves 6–10 income funds roughly two tier-3 completions — the fork decisions land in exactly that window.** Once the balance pass fixes the start (and possibly the cost ladder with it, upgrades.md §9), re-derive the wave 6–10 bounties against that rule; expect them to move down if the start lands high. Idle-credit target at a wave-10 win: ≤ 30% of the tuned start, per difficulty.md §8.

---

## 8. Ship order

| Enemy | Blocked by | Note |
| --- | --- | --- |
| Courser | nothing | **Shipped** — def, model and the Corridor's wave list, verified through the full suite plus an end-to-end spawn-count run. |
| Skiff | 2.5 (air lane, `can_target_air`) | ROADMAP calls flying "the most conspicuous absence" — this is its spec. |
| Warden | 2.4/2.6 (aura hook) | First ability enemy; the enum lands with it. |
| Mender | 2.6 (`HEAL_PULSE`, `ENEMY_HEALED`) | Second — reuses the enum, adds the event-pair seam. |
| Fission Crawler | 2.6 + mid-path spawn | **Last, on purpose** — it carries the determinism risk, and by then the ability plumbing is proven. |

Waves 6–10 enter the map's wave list only when every enemy they reference exists — the catalog's cross-reference check enforces this for free.
