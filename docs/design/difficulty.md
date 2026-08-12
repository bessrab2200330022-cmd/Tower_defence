# Difficulty target

**Owner:** A2 (design) · **Implements:** ROADMAP 0.3 · **Consumed by:** the balance harness (0.1) and the first balance pass (0.4)

This document makes "balanced" falsifiable. Every target below is a number a headless harness can check, attached to a policy class it can enumerate. When the harness disagrees with this file, one of them is wrong in a way we can now argue about — which is the entire point.

**Revision 2, after the harness's first light.** The instrument disagreed with the first version of this file twice, and the instrument was right both times: the gates quantified over a seed axis that turns out to have no variance (§2 and §4 are now quantified over policy classes instead), and the starting-credit band was declared around an unmeasured incumbent (§6 and §7 are rewritten from the credit sweep). The gates' spirit is unchanged; their quantifier and one band were wrong.

Waves 1–5 of The Crossing are the scope. §8 extends the bands to the 10-wave campaign specified in [enemies.md](./enemies.md).

---

## 1. What kind of hard this game is

Bastion Line is a **knowledge-and-composition** tower defence, not a reflex one. The damage table in `sim/damage.gd` is the curriculum; the waves are its lessons; difficulty is the price of not learning. Nothing in the design should ever demand fast hands — ROADMAP Phase 4's accessibility note ("no reliance on fast reactions") is a difficulty constraint, not just a UI one.

Three principles fall out of that:

**Failure must diagnose itself.** A player who loses should be able to say *what* beat them in one sentence — "the shielded ones walked through my bullets" — because the fix (build the answer tower) is the lesson. A loss that reads as noise teaches nothing and reviews badly.

**The wrong tool must be visibly wrong, not silently weak.** Against a shielded target, the right damage type must kill at least **3× faster** than the wrong one. Today the Arc Cannon does 45 per shot into a Shielded Scout while the Plasma Lance does 510 per shot at a slower rate — roughly a 4:1 effective-DPS gap. That gap is the game's clearest sentence; tuning must never blur it below 3:1.

**Almost-working must be the seduction.** The mono-kinetic build should nearly clear the map. "I almost had it, one Lance would have done it" converts a loss into a retry. A build that collapses at wave 3 converts it into a refund.

---

## 2. The reference policy classes

The harness cannot simulate a human, but it can enumerate *policies* — a policy being one complete answer to what you buy, where it goes, and when you spend. The first harness run surfaced the fact this section originally got wrong: **the sim draws no randomness at all.** The seeded RNG exists and nothing calls it, so a policy on a map produces exactly one outcome, every time; matches differing only by seed are byte-identical. There is no seed axis. Every quantity in this file is therefore quantified **over policy classes** — build order × placement policy × saving policy, which is what the harness actually sweeps. These are exact enumerations, not samples: no confidence intervals, no flaky reruns, every percentage is a count. That is a stronger kind of gate, not a weaker one.

Three classes, ordered by how much of the game they understand. Class sizes are targets, not laws — large enough that a percentage over them means something, small enough to enumerate in one harness run.

**S1 — Naive (mono-kinetic), ~20–40 policies.** Buys an Arc Cannon whenever affordable; never sells; starts each wave immediately. Varied across placement policy only (best-coverage-first from the pad sweep, nearest-to-spawn, nearest-to-goal) — this player has one idea. The armour table exists to make every policy in this class lose — *late*.

**S2 — Competent (reads the tooltips), ~60–200 policies.** The target audience, defined by composition rules rather than absolute credits (the wallet itself is a knob under retune, §7): every S2 policy opens by spending 75–90% of the wallet across at least two damage types, fields the third family no later than the first shielded wave, and has two Plasma Lances standing by wave 4. Varied across opening composition within those rules, placement (best and second-best pads), and saving policy (spend-all vs one-tower reserve). Target modes stay on defaults — the Lance ships on Strongest, which is most of the answer. If most of this class cannot win, the game is too hard for its audience by definition.

**S3 — Tuned (the ceiling), ~20–60 policies.** The best S2 members plus deliberate target-mode calls via `Simulation.set_target_mode()`, measured-best placement, and — once they exist — upgrades ([upgrades.md](./upgrades.md)). S3 measures the skill ceiling; its one hard requirement is G9.

The class definitions are design fixtures; the harness owns the concrete enumeration. One standing instruction, from the lead: if the dead seed axis ever tempts anyone to fix it by drawing randomness in the sim — no. Determinism is the architecture's foundation and every verification tool leans on it, including the harness that found this. The fix was the quantifier. If a future mechanic legitimately needs randomness (none is currently designed), it draws from the seeded RNG and seeds become a *second* axis alongside policies, never a replacement for them.

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

These are the acceptance criteria for ROADMAP 0.4, quantified over the §2 policy classes. (The 200-seed methodology that stood here previously measured an axis with no variance on it — see §2 and §6.) "Win" means `GAME_WON`; lives are read at that event.

| # | Gate | Pass condition |
| --- | --- | --- |
| G1 | S2 wins | ≥ 90% of S2-class policies win |
| G2 | S2 margin | Median lives-at-win across winning S2 policies in **14–18**; no winning S2 policy finishes below 8 |
| G3 | S2 spend pressure | Median idle credits at win, over winning S2 policies, ≤ 30% of the tuned starting credits |
| G4 | Wave 5 bites | ≥ 60% of the policies that win lose ≥ 1 life during wave 5 |
| G5 | S1 fails late | ≤ 20% of S1-class policies win; **median terminal wave across the class = 5** |
| G6 | S1 survives the lesson | ≥ 90% of S1-class policies reach the start of wave 4; ≥ 50% reach the start of wave 5 |
| G7 | No early cliff | Every policy of *any* class that has placed ≥ 3 towers holds ≥ 15 lives at the end of wave 2 |
| G8 | Wrong-tool clarity | Effective DPS of best energy tower vs Shielded ≥ 3× best kinetic tower vs Shielded, at every tier that exists |
| G9 | Ceiling exists | At least one S3-class policy finishes 20/20 — and fewer than 25% of the class does (flawless exists, and is not routine) |

Notes for the implementer:

- G3 is expressed as a percentage of starting credits because the wallet is being rescaled (§7); at a 640-credit start it reproduces the old absolute target almost exactly.
- G7 is an anti-pathology assert, not a difficulty statement — it catches "the tuning fell off a cliff before the player was taught anything". It should hold trivially; if it ever fails, stop tuning and investigate.
- G9 becomes meaningful once target-mode calls are in the S3 enumeration; once upgrades ship, re-run it with upgrade purchases in the class — the existence half must still hold, and the < 25% rarity cap keeps flawless a feat rather than a routine.
- Tolerances are deliberate. A gate written as "exactly 16 lives" would be overfit to one policy; bands of this width survive a retune without being vacuous. Since outcomes are exact per policy, a failing gate names the exact policies that broke it — use that.

---

## 5. Feel targets — the shape of each fight

Numbers the harness can check are the skeleton; these are the muscles. Each has a measurable proxy so "feel" doesn't decay into vibes.

**Wave 1 is a victory lap.** Any S2-class opening should clear it untouched. Proxy: ≥ 95% of S2-class policies take 0 leaks on wave 1.

**A lone drone must lose to a lone, well-placed Arc Cannon — and today it does not.** This is the first thing a player ever watches happen, and the harness measured it failing: one full pass through one Arc's range circle delivers **five shots, 495 damage, against 600 HP**. The drone walks out. The unit that matters here is *shots per transit* — small, quantised, sensitive to entry timing — not sustained DPS (§6 owns that lesson). The anchor stands as design intent, now with a concrete bar: one transit must total ≥ 600 vs Light. The clean route is damage 90 → 110 (five shots → 605), which sits inside §7's ±25% tower band — a balance-pass item, not a design change. Rate alone is the wrong lever: even a sixth shot at 99 totals 594, still short, and the cycle needed to add shots collides with Overclock's slot ([upgrades.md](./upgrades.md) rescales tier 2 in proportion if the base moves). Proxy: single-tower, single-drone scenario — dead on or before completing one transit of the first well-placed pad's circle.

**Wave 3's shields must sting S1 and merely graze S2.** The Shielded Scout should *survive* massed kinetic fire long enough to be watched doing it — that survival is the tutorial. Proxy: ≥ 1 Shielded Scout leaks in ≥ 80% of S1-class policies; ≤ 1 leaks in ≥ 80% of S2-class policies.

**The Brute should feel like a siege, not a wall.** Wave 4's single Brute, against an S2-class kit, should die in the final 40% of the path — close enough to the goal to draw the eye, far enough that it never feels arbitrary. Proxy: median kill position of the wave-4 Brute across winning S2 policies falls in 60–95% path progress.

**Wave 5 must produce a near-breach.** Someone — a Brute under fire, the last Shielded Scout — should cross 70% of the path before dying in most winning runs. Proxy: max enemy progress during wave 5 ≥ 70% in ≥ 80% of winning S2 policies.

**The Frost Mortar must matter in its own currency — time.** The harness measured 128 damage per full pass against a Shielded Scout; that is the damage table's worst cell working as designed, not a defect (see [upgrades.md](./upgrades.md) §6 for the family audit it triggered). But the mortar's actual product — the slow — is invisible to a damage-per-tower report, so it will *always* score as decoration until the report grows the right column. Directive: the harness should report, per tower, **added exposure-seconds** — extra time enemies spent inside other towers' range beyond what their unslowed transit would have given. Floor: S2-class policies containing a Mortar must not underperform mortar-less, same-spend members of the class on median lives. If that floor fails, the thing to tune is the base tower (its 90-tick interval quantises to two shells per drone-speed transit, and whether the second lands is entry-timing luck), never the damage — a mortar that kills things is a different tower.

These proxies are diagnostics, not gates. If a retune passes §4 but flattens these, the game is legal and boring; bring the numbers back here for a design revision instead of shipping it.

---

## 6. What the harness actually found — and the assumption this file got wrong

The hypothesis that stood here guessed at a wave-3 problem: script pathologies, walker HP, coverage gaps. The first real harness run — 120 matches across every placement, build-order and saving policy — superseded all of it. **Retracted.** The data:

**The shipped economy cannot win at all.** At 320 starting credits, 0% of policies win; the best of them dies on wave 4. The credit sweep reads 0 / 15 / 40 / 65 / 93 / 98 percent of all policies winning at 320 / 480 / 560 / 640 / 800 / 960. Two facts fall out: the entire playable difficulty range lives in a 1.7× window (560–960), and the shipped value sits *below its floor*. There was never a tower-mix problem to find — 320 credits buys three Arc Cannons into a wave of eight drones, and no placement of three of anything holds this geometry. §7 is corrected accordingly.

**The paper analysis was optimistic in a specific, reusable way.** The old §6 multiplied nominal DPS by an uptime scalar (~50%) and treated the product as deliverable damage. The harness measured the true unit: **shots per transit.** A drone crosses one Arc Cannon's range circle in roughly 2.2 seconds; the measured budget is five shots — 495 damage against a 600 HP target, which is why one cannon cannot solo the cheapest enemy in the game (§5 now carries this as a failing anchor with its fix). Sustained DPS is a fiction at these speeds. What a tower delivers is a small, integer shot budget per enemy pass — sensitive to entry timing, shared across simultaneous targets, and it moves in steps, not slopes: a rate change that doesn't add a shot to the transit changes almost nothing, and one that does is a cliff. **Balance in shots-per-transit, not DPS-times-uptime.** Every early estimate in this file used the fiction; treat surviving prose that says "sustained" with suspicion until the balance pass re-derives it.

Why the wave-3 story looked plausible and wasn't: with three towers standing, waves 1–2 are *almost* holdable, so the deaths bunch on whatever wave the accumulated leakage crosses 20 — the terminal wave read as the problem wave. The problem was upstream the whole time: the wallet stood up half the defence this geometry needs before wave 1's eighth drone lands.

---

## 7. Fixed points vs knobs

The balance pass may move anything in the right column, within the listed range, provided every gate in §4 still passes. The left column is identity — changing it is a design revision, not a tune, and comes back through this document.

| Fixed (identity) | Tunable (knobs) |
| --- | --- |
| 20 starting lives on The Crossing | Starting credits: within the **measured 560–960 window**, landed where G1 and G5 hold simultaneously (the sweep says both plausibly do in its lower-middle; the top of the window, at 98% all-policy wins, almost certainly fails G5) |
| Leak costs 1 / Brute 2 | All tower damage, cost, fire interval, range: ± 25%, preserving §4 G8 and the orderings in upgrades.md |
| Damage-table *orderings* (each row's best and worst armour, and the ≥ 3:1 shielded clarity) | Damage-table cell values otherwise: ± 15 points |
| The 10× integer damage/HP scale | Enemy HP, speed, bounty: ± 25% |
| Teaching order of waves 1–5 (swarm → volume → shields → heavy → exam) | Spawn counts, intervals, delays within each wave |
| Three towers = three answers (swarm / single-target-armour / control) | Which pad is "best" — placement is the player's problem, not the tuner's |

The starting-credits row corrects a mis-declaration, and the mistake is worth keeping on record. The first version of this table declared 320 ± 60 — a band anchored to the shipped value, which no measurement had ever touched. The harness then showed the entire playable range sits outside it; A1 granted the sim agent a one-time exception to cross the band, and this revision regularises that exception. The rule going forward: **a knob's band is anchored to a measurement, or it is marked provisional.** By that rule, the ±25% bands elsewhere in this table are provisional until the balance pass first touches them — declared in good faith, not yet earned.

One warning from the codebase's own history: the damage table already lost 5–11% of its effect to integer truncation once, before the 10× rescale. Any knob-turn that drops per-shot damage into low double digits re-opens that wound. Keep per-shot damage ≥ 40 at all tiers.

---

## 8. Extending to ten waves

The 10-wave campaign ([enemies.md](./enemies.md) §5) keeps The Crossing's bands for waves 1–5 and continues the same grammar: each new wave introduces exactly one new fact, then the exam waves recombine facts already taught.

- **S2 end-state at wave 10: 8–14 of 20 lives.** The full campaign should cost a competent player roughly twice what the first five waves did — waves 6–10 introduce fliers and ability enemies, and adaptation lag is the intended cost.
- **Waves 6–9 each cost S2 0–3 lives; wave 10 costs 2–4.** No single wave after 5 may cost the median S2-class policy more than 6 — a 7+ spike is a cliff, and cliffs are what §4 G7 exists to catch early.
- **No S1-class policy survives past wave 8.** By then three separate lessons (shields, air, auras) have each gone unanswered; the sum should be lethal with certainty.
- Flawless (20/20) over ten waves should be an achievement-grade feat — the Steam notes already sketch "clear a map without losing a life", and it should demand upgrades, target-mode play and probably a restart or two. Target: achieved by ~5% of S3-class policies, no more.

Ten-wave income is bounty schedule plus the tuned start, and the start just moved (§7). The standing rule is the ratio, not any absolute: **total campaign income lands ~10% short of a fully-forked six-tower kit plus a real run's extra base towers** — spend pressure never disappears. The wave 6–10 bounty schedule in enemies.md §7 was drafted against the old wallet; re-check it against this rule once the start value lands. Idle-credit target at a wave-10 win: ≤ 30% of the tuned start.

---

## 9. Decisions made here that a human can veto

*(Status: all three reviewed and upheld by A1. Kept for the record — they remain the load-bearing assumptions behind G2, G5 and G9.)*

1. **The naive player loses map 1** (on wave 5). The alternative — everyone clears map 1, difficulty starts on map 2 — is defensible and common; I chose against it because this game's identity *is* the matchup table, and a table you can ignore on the first map stays ignored. Veto by relaxing G5 to "win rate ≤ 60%, median lives at win ≤ 6".
2. **Competent ends bruised (14–18), not clean.** If the first map should instead feel like a safe on-ramp, widen G2 to 16–20 and expect wave 5 to stop producing near-breaches.
3. **Flawless is rare even for S3** (G9 at 10%, later 30% with upgrades). If flawless is meant to be the *standard* expert outcome rather than a feat, raise both.
