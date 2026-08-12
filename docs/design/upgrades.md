# Upgrades — three tiers, branch at the top

**Owner:** A2 (design) · **Decides:** ROADMAP 2.2's open question · **Implemented by:** A3 (schema, sim), A4 (UI), A1 (tier visuals)

---

## 1. The call

**Each tower has three tiers: base → Tier 2 (linear) → Tier 3 (a choice of two branches).** Two purchases per tower, made in place; the second purchase is a fork.

**Why branch at all.** Linear tiers leave three towers being three answers forever — more numbers, same decisions. One tower with two divergent tier-3s reads as three towers: the branch multiplies late-game identity roughly 2× per family for the cost of one extra resource file each. Nine tower end-states from three base towers is the right amount of game for a 10-wave campaign, and the marginal cost is only in the schema *if the schema is branch-shaped from day one* — which is exactly what this document exists to guarantee.

**Why the fork is at tier 3, not tier 2.** Three reasons, in order of weight:

1. **Commitment should arrive with information.** A tier-2 fork is bought around wave 3–4, before the player has seen heavy armour, fliers or auras — they would be choosing between answers to questions the game hasn't asked yet. A tier-3 fork lands around waves 6–8 of the full campaign, after every threat class has introduced itself. Late fork = informed fork.
2. **It halves the balance surface.** Branching at tier 2 means two T2s *and* two T3s per family — 12 upgrade definitions to tune against each other. Branching at tier 3 means 9. The harness will thank us.
3. **The early game stays simple on purpose.** Waves 1–5 teach placement and damage types ([difficulty.md](./difficulty.md) §1). A mid-campaign fork would inject a build-crafting decision into the middle of the curriculum. Tier 2 as a plain "more of what this tower already is" keeps the upgrade button teachable in one click.

A wrong branch is not a trap: selling refunds 70% of everything invested, so a mis-built tier-3 tower converts into most of a fresh tier-2 elsewhere. Recoverable mistakes are what make bold picks fun.

**The design language of every fork is the same:** branch **A doubles down** on the family's role; branch **B pivots** to cover a weakness. That symmetry is deliberate — after one fork, the player can predict the shape of the other two, and prediction is what makes a choice feel like strategy rather than a menu.

---

## 2. Rules of play

- Upgrades are bought **in place**, on the tower, and are exactly as available as build/sell is — same phase rules the sim already enforces, no special cases.
- An upgrade **costs credits and accrues into the tower's invested total**; selling at any tier refunds 70% of *everything* invested (the backlog already plans `credits_invested` on the tower state for this).
- **The fork is permanent.** Respec is selling. No third mechanic.
- Tiers may change any combat stat, including range and default target mode. They never change footprint: one pad, one tower, always.
- Bounties, income and enemy behaviour are untouched by upgrades — power flows one way, through the tower's own stats.

---

## 3. Pricing doctrine

A tier purchase competes with buying another base tower. Raw DPS-per-credit *declines* up-tier almost everywhere below, and that is intentional: an upgrade concentrates power on a cell that is already well-placed, adds zero new coverage, and consumes no new pad. Its compensations are concentration (the best pads are few), range (uptime is a multiplier paper DPS ignores), alpha (overkill economics against big targets), splash width, and slow depth.

The one deliberate exception: **Arc Cannon T2 marginal efficiency equals its base efficiency** (+225 DPS for 90 credits — exactly a second cannon's output in the same footprint). The cheapest tower's first upgrade is the tutorial for the upgrade system itself, and it should never feel like a tax.

The judge of all of this is the harness's damage-dealt-per-tower-per-credit report (ROADMAP 0.1/0.2), not the nominal numbers. Every number below is an opening bid, tunable ± 25% — but the **invariants** listed per family are the design, and a tune that breaks one comes back to this document.

---

## 4. Arc Cannon family — "the pressure line"

Cheap, fast, kinetic. The family answer to *volume*. Its shield blindness (50%) is the game's first lesson and survives at every tier — no Arc branch may ever become a shield answer.

| Tier | Name | Cost (Σ invested) | Damage | Interval | Range | Splash | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Arc Cannon | 90 (90) | 90 kinetic | 24t | 8.0 | — | as shipped |
| 2 | **Overclock** | +90 (180) | 120 | 16t | 8.0 | — | a second cannon in the same footprint |
| 3A | **Hailstorm** | +140 (320) | 70 | 10t | 8.0 | 2.0 | flak; the swarm terminal |
| 3B | **Railshot** | +140 (320) | 480 | 60t | 12.0 | — | the elite-hunter pivot; default target mode Strongest |

Effective single-target DPS (damage × 60/interval × armour %):

| Tier | vs Light | vs Medium | vs Heavy | vs Shielded |
| --- | --- | --- | --- | --- |
| Base | 248 | 225 | 158 | 113 |
| Overclock | 495 | 450 | 315 | 225 |
| Hailstorm | 462 | 420 | 294 | 210 |
| Railshot | 528 | 480 | 336 | 240 |

**Hailstorm is a single-target *downgrade* from Overclock (420 < 450), on purpose.** Its damage lives in the 2.0 splash: against a pair it roughly doubles, against a tight pack it is the best per-credit killer in the game. The choice is honest only if single-target play punishes it. Wave choreography supplies the packs (enemies.md tightens late drone intervals specifically for this).

**Railshot trades rate for reach and alpha.** Range 12 on this map is close to double the uptime of range 8, and 480-per-shot drops a Line Walker in four hits. It still needs *two* shots per Scout Drone (528 into 600 HP) — deliberately short of a one-shot, so it never moonlights as a swarm gun. Against Shielded it remains the worst tier-3 in the game (240 effective) — that is invariant, not accident.

**Family invariants:** Hailstorm single-target DPS ≤ Overclock's. Railshot effective DPS vs Shielded < every Plasma Lance tier vs Shielded. Arc stays the cheapest family at every tier.

*Implementation flag for A3:* Hailstorm is **hitscan with a splash radius** — verify the sim applies splash on hitscan hits (the Frost Mortar exercises only the projectile path today). If it doesn't and the fix is not trivial, ship Hailstorm as a fast projectile (speed 60) instead; the feel difference at range 8 is negligible.

---

## 5. Plasma Lance family — "the answer"

Expensive, long-range, energy. The family answer to *armour and shields*. Ships defaulting to Strongest targeting, which stays the family default at every tier.

| Tier | Name | Cost (Σ invested) | Damage | Interval | Range | Notes |
| --- | --- | --- | --- | --- | --- | 
| 1 | Plasma Lance | 190 (190) | 340 energy | 66t | 13.0 | as shipped |
| 2 | **Focused Array** | +170 (360) | 560 | 60t | 14.0 | three-shots a Shielded Scout |
| 3A | **Prime Focus** | +260 (620) | 1000 | 90t | 16.0 | the executioner; alpha 1000 |
| 3B | **Fork Array** | +260 (620) | 480 | 66t | 14.0 | beam forks to 2 extra targets — see flag |

Effective single-target DPS:

| Tier | vs Light | vs Medium | vs Heavy | vs Shielded |
| --- | --- | --- | --- | --- |
| Base | 247 | 309 | 371 | 464 |
| Focused Array | 448 | 560 | 672 | 840 |
| Prime Focus | 533 | 667 | 800 | 1000 |
| Fork Array (primary only) | 349 | 436 | 524 | 655 |

**Prime Focus is one target, maximally dead.** 1500 per shot into Shielded (two-shots a Scout), 1200 into Heavy (five shots per Brute, six seconds). Its tax is overkill: 800-per-shot into a 600 HP drone wastes a quarter of every trigger pull, making it the worst per-credit tower in the game against swarms. Pick it for Brutes, Wardens and the bosses ROADMAP 3.3 promises.

**Fork Array spreads the same wattage.** Each shot hits its primary for 480 and forks to up to two further enemies within 4.0 of the primary for 240 each (percentages fold in as usual). Against three-packs its aggregate base output is ~873/s — the sustained-pressure pick for shielded *streams* rather than shielded *units*. Against a lone target it is strictly worse than Focused Array; that is the price of the fork, and invariant.

**Family invariants:** Lance is the best family vs Shielded at every tier, by ≥ 1.5× the next family (this is difficulty.md G8 wearing its upgrade hat). Prime Focus per-shot alpha ≥ 2× any other single hit in the game. Fork Array never out-damages Prime Focus on a lone target.

*Implementation flag for A3 — new mechanic:* the fork needs sim support: after the primary hit, select up to 2 additional targets within 4.0 of the primary — nearest first, ties broken by lower enemy id, never re-selecting the primary — and apply the half-damage hit in the same tick. It also needs its own view treatment (a beam that visibly forks), which is an event-shape question for the A3/A4 seam. **Do not block 2.2 on this.** If fork support isn't ready when upgrades ship, the Lance launches with Prime Focus as a lone tier-3 (temporarily linear) and Fork Array arrives with the 2.6-era targeting work — better a late branch than a throwaway stat-variant we replace and re-balance twice.

---

## 6. Frost Mortar family — "the choke"

Splash and slow, explosive, projectile. The family answer to *time*: it doesn't kill the wave, it sells the wave to your other towers at a discount. Mortars never target air (enemies.md fliers) at any tier — that hole is the family's price, and invariant.

| Tier | Name | Cost (Σ invested) | Damage | Interval | Range | Splash | Slow | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Frost Mortar | 150 (150) | 160 explosive | 90t | 11.0 | 3.0 | 40% / 120t | as shipped |
| 2 | **Deep Barrel** | +130 (280) | 220 | 80t | 11.0 | 3.6 | 40% / 150t | wider, longer, harder |
| 3A | **Glacier** | +200 (480) | 220 | 80t | 12.0 | 4.5 | **60% / 180t** | the control terminal |
| 3B | **Shatterhead** | +200 (480) | 420 | 70t | 11.0 | 3.4 | 20% / 60t | the damage pivot |

Effective centre-hit DPS:

| Tier | vs Light | vs Medium | vs Heavy | vs Shielded |
| --- | --- | --- | --- | --- |
| Base | 139 | 96 | 64 | 43 |
| Deep Barrel | 215 | 149 | 99 | 66 |
| Glacier | 215 | 149 | 99 | 66 |
| Shatterhead | 468 | 324 | 216 | 144 |

**Glacier buys time in bulk.** 60% slow for three seconds, in a 4.5 splash, reapplied every 1.33s — inside its footprint the wave moves at 40% speed, close to standing still under sustained bombardment. Its damage is unchanged from Deep Barrel: you are buying seconds, not hit points, and the seconds are spent by your Lances. It is the single strongest force-multiplier in the game and the invariant is exactly that: **no other source of slow may exceed Glacier's.**

**Shatterhead converts control into killing.** 546 centre-hit into Light (a drone pack simply ends), at the cost of most of the slow. Pick it when your kill power is the bottleneck; pick Glacier when your kill power is fine and *arriving late* is the problem. Its single-target DPS stays below every Lance tier — the mortar never becomes a sniper.

**Family invariants:** Glacier has the deepest slow in the game. Shatterhead single-target effective DPS < every Lance tier's vs the same armour. No mortar tier targets air.

*Implementation flags for A3:* (1) Slow stacking needs a rule the sim currently doesn't have to state — **strongest-wins, non-stacking**: an incoming slow overwrites only if its percent is ≥ the active one, refreshing duration; two Glaciers must not multiply to 84%. Confirm when 2.4 generalises status effects; until then the hardcoded slow fields make it moot. (2) Glacier's 60% sits inside the schema's existing 0–90 slow range — no schema change needed for it.

---

## 7. What A3 needs to schema

Everything above is expressible in the current TowerDef fields — damage, interval, range, splash, slow, target mode — plus the following, which is the ask list for 2.2:

1. **`upgrade_ids` on the tower definition** (the backlog's own suggestion): an array of def ids purchasable from this def. One entry = linear step (tier 1 → 2), two entries = the fork (tier 2 → 3A/3B). Each tier is its own `.tres` carrying full stats — an upgraded tower simply *is* its new def. No deltas, no inheritance.
2. **`credits_invested` on tower state**, accruing base + upgrades, refunded at 70% on sell.
3. **A `try_upgrade` command** on the same command surface as build/sell, so it lands in the replay log for free (this matters for 3.1 save/load).
4. **A `TOWER_UPGRADED` event.** This is a WORKSTREAMS seam: producer in sim (A3), consumer in the view layer (A4) — an unconsumed upgrade event means a tier-2 tower still wearing its tier-1 mesh, which autoplay's view-count assert will *not* catch since no node is created or destroyed. Flag it loudly in whichever session ships first.
5. **Fork targeting** (Lance 3B only, deferrable — see §5 flag).
6. **Hitscan splash verification** (Arc 3A only — see §4 flag).

Suggested id scheme, since each tier is a def: `arc_cannon`, `arc_cannon_t2`, `arc_cannon_t3a`, `arc_cannon_t3b`, and likewise for `plasma_lance` and `frost_mortar`. Nine new `.tres` files total.

---

## 8. What A1 and A4 need

**A1 (tier visuals):** a tower's tier must read at RTS-camera distance without UI: tier 2 = the same silhouette, visibly bulkier (wider barrel, added greeble mass); tier 3 = a distinct silhouette per branch (Hailstorm: multi-barrel rotary; Railshot: one long rail; Prime Focus: single large emitter; Fork Array: split emitter prongs; Glacier: broad squat mortar with vanes; Shatterhead: reinforced heavy barrel). Branch accent colours are named in [voice.md](./voice.md); the existing `accent_color`/`effect_color` fields carry them, so this is data plus models, no view code.

**A4 (UI):** the upgrade panel shows one button at tiers 1–2 and a two-option choice at the fork, each option previewing the stat diff before purchase (the fields to diff are exactly the columns of the tables above). Sell button shows the refund computed from invested credits. Nothing else — target-mode UI is its own backlog item (2.3).

---

## 9. Tuning protocol

The harness tunes; the invariants hold. Concretely: A3 may move any number in this file ± 25% chasing difficulty.md's gates, without asking. Anything that would cross a family invariant, change the fork tier, add a tier, or touch the 70% refund is a design change — one message to A2, cheap to answer, and the reasoning lands back in this file so the next reader knows why the number moved. The Done-list rule applies here too: when 2.2 ships, record *what the harness actually showed*, not just that it shipped.
