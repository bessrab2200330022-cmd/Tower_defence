# Difficulty target

**Owner:** A2 (design) · **Implements:** ROADMAP 0.3 · **Consumed by:** the balance harness (0.1) and the first balance pass (0.4)

This document makes "balanced" falsifiable. Every target below is a number a headless harness can check, attached to a scripted player it can simulate. When the harness disagrees with this file, one of them is wrong in a way we can now argue about — which is the entire point.

Waves 1–5 of The Crossing are the scope. §8 extends the bands to the 10-wave campaign specified in [enemies.md](./enemies.md).

---

## 1. What kind of hard this game is

Bastion Line is a **knowledge-and-composition** tower defence, not a reflex one. The damage table in `sim/damage.gd` is the curriculum; the waves are its lessons; difficulty is the price of not learning. Nothing in the design should ever demand fast hands — ROADMAP Phase 4's accessibility note ("no reliance on fast reactions") is a difficulty constraint, not just a UI one.

Three principles fall out of that:

**Failure must diagnose itself.** A player who loses should be able to say *what* beat them in one sentence — "the shielded ones walked through my bullets" — because the fix (build the answer tower) is the lesson. A loss that reads as noise teaches nothing and reviews badly.

**The wrong tool must be visibly wrong, not silently weak.** Against a shielded target, the right damage type must kill at least **3× faster** than the wrong one. Today the Arc Cannon does 45 per shot into a Shielded Scout while the Plasma Lance does 510 per shot at a slower rate — roughly a 4:1 effective-DPS gap. That gap is the game's clearest sentence; tuning must never blur it below 3:1.

**Almost-working must be the seduction.** The mono-kinetic build should nearly clear the map. "I almost had it, one Lance would have done it" converts a loss into a retry. A build that collapses at wave 3 converts it into a refund.

---

## 2. The reference players

The harness cannot simulate a human, but it can simulate a *policy*. Three scripted archetypes, cheap to implement, ordered by how much of the game they understand. All placement below means "the best-coverage pads", which the harness may find by sweep once and hard-code; the scripts are policies over *what to buy and when*, not micro.

**S1 — Naive (mono-kinetic).** Buys an Arc Cannon whenever credits ≥ 90, on the next-best uncovered pad. Never sells, never changes a target mode, starts each wave as soon as the previous one clears. This is the player who found the cheapest button and pressed it. The armour table exists to make this player lose — *late*.

**S2 — Competent (reads the tooltips).** The target audience: opens with two Arc Cannons; adds a Frost Mortar at the chokepoint after wave 1; adds a Plasma Lance before wave 3 and a second before wave 4; spends whatever remains on Arc Cannons or a third Lance during wave 5. Leaves target modes on their defaults (the Lance already ships defaulting to Strongest, which is most of the answer). No sells.

**S3 — Tuned (the ceiling).** S2's kit plus deliberate target-mode calls via `Simulation.set_target_mode()` and measured-best placement. Once upgrades exist ([upgrades.md](./upgrades.md)), S3 buys them. S3 exists to measure the skill ceiling, not to gate the release — its one hard requirement is in §4.

These are design fixtures, not suggestions to A3 about code structure. But the harness should treat the *composition and timing* above as canonical: if S2's kit cannot win, the game is too hard for its target audience by definition.

---

## 3. The target, in one table

Lives start at 20. Leak costs are 1 per enemy, 2 for the Siege Brute — these are identity, not knobs (§7).

| Wave | What it teaches | S2 lives lost (typical) | S1 lives lost (typical) |
| --- | --- | --- | --- |
| 1 · Probing Run | Placement basics | 0 | 0 |
| 2 · Pressure | Volume; a tanky unit exists | 0–1 | 0–1 |
| 3 · First Shields | **The damage table** | 0–2 | 2–4 |
| 4 · Armour Test | Heavy armour; mixed threats | 0–2 | 4–8 |
| 5 · Breakthrough | All lessons at once | 1–3 | dies here, or scrapes |

**A competent first playthrough should end at 14–18 of 20 lives.** Zero losses would mean wave 5 never bit; below 12 reads as "barely survived the tutorial map", which is a mid-campaign feeling arriving four waves early.

**A naive playthrough should die on wave 5, not wave 3.** Waves 3 and 4 are where mono-kinetic starts bleeding — visibly, attributably, to shielded enemies specifically. Wave 5's six Shielded Scouts plus three Brutes finish the job. Dying *on the lesson wave itself* (3) means the punishment arrived in the same breath as the information, which is fair in a roguelike and hostile in a first map.

The current autoplay result — **loss on wave 3 with four towers standing** — is therefore formally out of target, and it is the first bug the balance pass should chase. See §6.

---

## 4. Harness gates

These are the acceptance criteria for ROADMAP 0.4. Run each script across **200 seeds** (placement fixed, seed varies spawn RNG only). "Win" means `GAME_WON`; lives are read at that event.

| # | Gate | Pass condition |
| --- | --- | --- |
| G1 | S2 wins | Win rate ≥ 90% |
| G2 | S2 margin | Median lives at win in **14–18**; 5th percentile ≥ 8 |
| G3 | S2 spend pressure | Median idle credits at win ≤ 200 |
| G4 | Wave 5 bites | Among S2 wins, ≥ 60% of runs lose ≥ 1 life during wave 5 |
| G5 | S1 fails late | Win rate ≤ 20%; **median terminal wave = 5** |
| G6 | S1 survives the lesson | ≥ 90% of S1 runs reach the start of wave 4; ≥ 50% reach the start of wave 5 |
| G7 | No early cliff | Any script that has placed ≥ 3 towers of *any* mix holds ≥ 15 lives at the end of wave 2 |
| G8 | Wrong-tool clarity | Effective DPS of best energy tower vs Shielded ≥ 3× best kinetic tower vs Shielded, at every tier that exists |
| G9 | Ceiling exists | Some S3 policy finishes 20/20 on ≥ 10% of seeds (flawless is achievable, and not by luck alone) |

Notes for the implementer:

- G7 is an anti-pathology assert, not a difficulty statement — it catches "the tuning fell off a cliff before the player was taught anything". It should hold trivially; if it ever fails, stop tuning and investigate.
- G9 becomes meaningful once target modes are scripted; once upgrades ship, re-baseline it with upgrade purchases allowed and raise the bar to ≥ 30% of seeds.
- Tolerances are deliberate. A gate written as "exactly 16 lives" would just be overfit to one seed; bands of this width survive a retune without being vacuous.

---

## 5. Feel targets — the shape of each fight

Numbers the harness can check are the skeleton; these are the muscles. Each has a measurable proxy so "feel" doesn't decay into vibes.

**Wave 1 is a victory lap.** Two Arc Cannons placed anywhere sensible should clear it untouched. Proxy: S2 takes 0 leaks on ≥ 95% of seeds.

**A lone drone should die to a lone, well-placed Arc Cannon before half the path.** This is the first thing a player ever watches happen. If the very first enemy out-walks the starter tower's kill, the game opens on an apology. Proxy: single-tower, single-drone scenario kills by ≤ 50% path progress.

**Wave 3's shields must sting S1 and merely graze S2.** The Shielded Scout should *survive* massed kinetic fire long enough to be watched doing it — that survival is the tutorial. Proxy: in S1 runs, ≥ 1 Shielded Scout leaks in ≥ 80% of seeds; in S2 runs, ≤ 1 leaks in ≥ 80% of seeds.

**The Brute should feel like a siege, not a wall.** Wave 4's single Brute, against S2's kit, should die in the final 40% of the path on a median seed — close enough to the goal to draw the eye, far enough that it never feels arbitrary. Proxy: median kill position of the wave-4 Brute in S2 runs falls in 60–95% path progress.

**Wave 5 must produce a near-breach.** Someone — a Brute under fire, the last Shielded Scout — should cross 70% of the path before dying in most winning runs. Proxy: max enemy progress during wave 5 ≥ 70% in ≥ 80% of S2 wins.

These proxies are diagnostics, not gates. If a retune passes §4 but flattens these, the game is legal and boring; bring the numbers back here for a design revision instead of shipping it.

---

## 6. The wave-3 anomaly — a hypothesis for the balance pass

Wave 3 is 9 Walkers (1,700 HP, medium) and 3 Shielded Scouts. Against it, a naive four-Arc-Cannon kit has, on paper, roughly 900 sustained DPS against the Walkers and half that against the Scouts — enough to kill the Walkers with coverage to spare, and to lose at most 3 lives to leaking Scouts. Losing *the game* there means the run arrived at wave 3 already ~17 lives down, or coverage is far below what the paper numbers assume.

So the first questions for the harness are distributional, not tuning: **where were the lives actually lost in the current autoplay run, per wave and per enemy type?** Plausible culprits, in order of suspicion: the naive script builds too slowly out of the 320 starting credits (leaking wave 1–2 drones it should trivially hold), placement covers one lane of the serpentine instead of the crossings, or Walker HP at 1,700 outclasses wave-2-era income more than intended. Measure first; the fix should fall out of the numbers.

---

## 7. Fixed points vs knobs

The balance pass may move anything in the right column, within the listed range, provided every gate in §4 still passes. The left column is identity — changing it is a design revision, not a tune, and comes back through this document.

| Fixed (identity) | Tunable (knobs) |
| --- | --- |
| 20 starting lives on The Crossing | Starting credits: 320 ± 60 |
| Leak costs 1 / Brute 2 | All tower damage, cost, fire interval, range: ± 25%, preserving §4 G8 and the orderings in upgrades.md |
| Damage-table *orderings* (each row's best and worst armour, and the ≥ 3:1 shielded clarity) | Damage-table cell values otherwise: ± 15 points |
| The 10× integer damage/HP scale | Enemy HP, speed, bounty: ± 25% |
| Teaching order of waves 1–5 (swarm → volume → shields → heavy → exam) | Spawn counts, intervals, delays within each wave |
| Three towers = three answers (swarm / single-target-armour / control) | Which pad is "best" — placement is the player's problem, not the tuner's |

One warning from the codebase's own history: the damage table already lost 5–11% of its effect to integer truncation once, before the 10× rescale. Any knob-turn that drops per-shot damage into low double digits re-opens that wound. Keep per-shot damage ≥ 40 at all tiers.

---

## 8. Extending to ten waves

The 10-wave campaign ([enemies.md](./enemies.md) §5) keeps The Crossing's bands for waves 1–5 and continues the same grammar: each new wave introduces exactly one new fact, then the exam waves recombine facts already taught.

- **S2 end-state at wave 10: 8–14 of 20 lives.** The full campaign should cost a competent player roughly twice what the first five waves did — waves 6–10 introduce fliers and ability enemies, and adaptation lag is the intended cost.
- **Waves 6–9 each cost S2 0–3 lives; wave 10 costs 2–4.** No single wave after 5 may cost more than 6 on a median seed — a 7+ spike is a cliff, and cliffs are what §4 G7 exists to catch early.
- **S1 must not survive past wave 8** even on lucky seeds. By then three separate lessons (shields, air, auras) have each gone unanswered; the sum should be lethal with certainty.
- Flawless (20/20) over ten waves should be an achievement-grade feat — the Steam notes already sketch "clear a map without losing a life", and it should demand upgrades, target-mode play and probably a restart or two. Target: reachable by S3-with-upgrades on ~5% of seeds, no more.

Income across ten waves totals roughly 3,300 credits including start (see enemies.md §6), which is deliberately about 10% short of a fully-maxed six-tower kit — spend pressure never disappears. Idle-credit target at a wave-10 win: ≤ 300.

---

## 9. Decisions made here that a human can veto

1. **The naive player loses map 1** (on wave 5). The alternative — everyone clears map 1, difficulty starts on map 2 — is defensible and common; I chose against it because this game's identity *is* the matchup table, and a table you can ignore on the first map stays ignored. Veto by relaxing G5 to "win rate ≤ 60%, median lives at win ≤ 6".
2. **Competent ends bruised (14–18), not clean.** If the first map should instead feel like a safe on-ramp, widen G2 to 16–20 and expect wave 5 to stop producing near-breaches.
3. **Flawless is rare even for S3** (G9 at 10%, later 30% with upgrades). If flawless is meant to be the *standard* expert outcome rather than a feat, raise both.
