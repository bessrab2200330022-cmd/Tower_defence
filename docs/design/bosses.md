# Bosses — the Line Breaker

**Owner:** A2 (design) · **Implements:** ROADMAP 3.3, sized for the campaign campaign.md shipped · **Consumers:** A3 (four enemy defs, one test), A5 (three meshes and a shard), A4 (nothing new — read §4)

---

## 1. The call — and the finding that decides it

The three candidate shapes: a scripted final wave, a single high-HP enemy, a phased entity. The brief's instinct is right that the wave-construct is cheapest — and wrong that it's a candidate at all, because we already ship it: Breakwater, Watershed and Breakup *are* scripted final exams. Calling one of them "the boss" adds a word to the game, not a thing. And the single big enemy is worse than cheap — a Brute with a bigger number is precisely what Prime Focus was built to delete; it would be a DPS check against the tower that trivialises DPS checks.

So the design wants phases. The expected cost of phases was one new sim primitive — and the finding of this document is that **the primitive already shipped.** `SPLIT_ON_DEATH` takes a `spawn_on_death: PackedStringArray` of arbitrary enemy ids — data, validated by the catalog from the def (A3 built it exactly as specced). **A split with one child at the same path position IS a phase transition.** The boss is a chain: phase 1 dies and *becomes* phase 2, phase 2 becomes phase 3, phase 3 shatters into shards. Four ordinary enemy defs wearing one silhouette lineage. The health bar refilling as the armour visibly sheds *is* the phase telegraph, and the view layer already renders all of it — a split is an `ENEMY_KILLED` plus `ENEMY_SPAWNED`, events A4 consumes today.

**The sim ask, in one line: zero new primitives — one new test** (a split child that itself splits: the chain is two links deep and nothing has ever exercised link two), plus four enemy defs A3 authors from §3's table.

One honest asterisk: each phase spawns at its own full HP, so the chain's total pool is fixed and overkill on a phase-killing blow is *discarded*. That is not a bug to fix — it is the anti-alpha texture the brief asked for (§2).

---

## 2. What it breaks that the roster cannot

Every enemy in the roster invalidates one assumption, but all of them share a deeper one: **once you've engaged a threat, you've solved it.** The right tool at first contact stays the right tool until the health bar empties. The Breaker breaks tool-commitment itself — it *walks the damage table while you fight it*:

| Phase | Armour | The player's best tool | What just happened to the last phase's answer |
| --- | --- | --- | --- |
| 1 — the Wall | **Heavy**, slow | Energy (120%) — lances chew | — |
| 2 — the Stride | **Light**, fast | Kinetic (110%) — arcs redeem | Energy drops to 80%; the lance kit that cruised phase 1 underperforms exactly when the boss doubles its speed |
| 3 — the Core | **Shielded**, slow | Energy (150%) — mandatory | Kinetic falls to 50%; switch back or watch |
| † — Shards | Light, very fast | Anything standing | The kill is not the end; the last five seconds are |

Phase 1 rewards the campaign's default late kit. Phase 2 punishes monoculture at the moment of maximum drama — a speed spike wearing the armour type your exam kit is worst against. Phase 3 demands the answer tower still be standing. The shards convert the death itself into one final leak threat, `SPLIT_ON_DEATH` used for its shipped purpose. Nothing else in the game asks the player to *re-decide* mid-entity; that is the assumption invalidated, and it is one no wave composition of stream enemies can touch.

Second break, smaller but real: **alpha stops being free.** Prime Focus's 1,770-per-shot into a Shielded core is still the right tool — but every phase boundary eats the overkill remainder of the killing blow, so the burst kit pays a tax three times where it usually pays never. Sustained mixed damage is, for the first time, the *economical* answer to a big target.

---

## 3. The spec (four defs, A3 authors)

All plain `EnemyDef`s. Same `display_name` on all three phases — the player fights one thing called Line Breaker; the bar refilling under a shrinking silhouette carries the phase story without UI work.

| Def id | HP | Armour | Speed | Bounty | Leak | Ability |
| --- | --- | --- | --- | --- | --- | --- |
| `line_breaker` (P1) | 9,000 | Heavy | 2.4 | 40 | **6** | `SplitOnDeath → ["breaker_stride"]` |
| `breaker_stride` (P2) | 6,600 | Light | 5.5 | 30 | 5 | `SplitOnDeath → ["breaker_core"]` |
| `breaker_core` (P3) | 4,800 | Shielded | 3.0 | 30 | 4 | `SplitOnDeath → ["breaker_shard", "breaker_shard"]` |
| `breaker_shard` (†) | 700 | Light | 8.5 | 5 | 2 | none |

Chain totals: 21,100 HP (+1,400 in shards), 110 bounty, and a leak ladder that makes the fiction literal — a phase-1 leak costs 6 of 20 lives because *the siege engine reached the Anchor*. Every number here is a first bid inside the usual ±25%; the orderings (armour walk H→L→S, speed spike at P2, shard sting) are the design.

**Escorts are wave data, not boss features** — this is where the shipped abilities compose for free, and why the one-ability-per-enemy rule survives untouched: the boss chain spends its one ability slot on the chain itself, and the wave supplies the rest. Wardens marching with P1 shelter it under their existing aura (a boss is just an ally inside 4.0). Menders trailing it heal it with their existing pulse — two menders is 300 HP/s of regional repair that makes kill-order matter for the whole fight. No new interaction code exists anywhere in this paragraph; that is the enum-not-subclass rule paying out.

---

## 4. What each agent needs

**A3:** the four defs above; the two-link chain test (`split child with SPLIT_ON_DEATH splits again, at the parent's position, deterministically`); nothing else. No new enum value, no new event, no schema change. The catalog already validates `spawn_on_death` ids from the def.

**A4:** nothing. Phases arrive as kill+spawn events the views already consume. The one optional nicety — a brief spawn-scale-in on P2/P3 so the swap reads as transformation rather than pop — is the same polish the Crawler's split already wants, shared work not new work.

**A5 — the silhouette brief.** One lineage, three stages of undress, and a fourth fragment:

- **P1 `line_breaker` — height 1.95, radius 0.9.** The tallest thing that has ever been on the board — this deliberately overrules the "Brute is visibly the tallest" taste rule, and amends it to *"the Brute is the tallest ordinary thing."* A broad armoured siege-crab: plates over everything, a faint glow leaking from the seams. Slow stance, low forward rake.
- **P2 `breaker_stride` — height 1.30, radius 0.7.** The same body with the plates *gone*: exposed frame, the core now clearly visible and bright, raked hard forward like the Courser. It must read at RTS zoom as "that same thing, faster and angrier".
- **P3 `breaker_core` — height 0.95, radius 0.5.** The naked core on failing legs: small, dim shell, intense emissive heart. The most shootable-looking thing in the game — the design wants the player to *feel* the kill window.
- **† `breaker_shard` — height 0.45, radius 0.3.** A burning fragment of the core with the Courser's dust-trail energy. Two of them, sprinting.
- Per-phase meshes ride each def's own `mesh_path` — the def swap gives the mesh swap for free. Core emissive intensifies P1 → P3 (same channel the bloom threshold already respects); plates stay matte. No `shell_node`, no translucency. Heights are yours to measure off the exports as always — the *ordering* (1.95 > Brute's 1.56; each phase strictly shorter; shard smallest) is the contract.

---

## 5. Where it enters the game, and the gates

**Debut: the Corridor's Watershed (wave 10), as the finale movement** — the campaign's last map, last wave, per campaign.md's shape. The insertion is a one-file edit shipped atomically with the defs: in `corridor_10`, the current courser finale (10 @ 14t, delay 1240) becomes the herald line (6 @ 14t), followed by `line_breaker` count 1 at delay 1450 with two Menders trailing (delays 1500, 1560). Wave income rises ~+150 (boss chain 110 + menders 72 − four coursers 32); wave HP rises ~22k — re-check C-gates at that point, expect C2's band to hold but its floor to bite. The Fork's Breakup and the Crossing's Breakwater stay boss-free — one Breaker, at the end, is an event; three is a unit type.

**Gates (policy-quantified, joining the C-table when the insertion lands):**

| # | Gate | Pass condition |
| --- | --- | --- |
| B1 | The chain dies | ≥ 85% of winning S2-Corridor policies kill through all three phases before the goal |
| B2 | The Stride threatens | In ≥ 50% of winning policies, phase 2 crosses 70% path progress — the sprint must be a moment, not a stat line |
| B3 | The table is walked | Policies fielding both kinetic and energy at boss spawn out-win mono-energy policies by ≥ 15 percentage points |
| B4 | Instrumentation | The harness reports per-phase damage dealt, each transition's path position, and the kill-position distribution — a boss the harness cannot see per-phase is a boss that ships broken |

---

## 6. Voice (canon in voice.md alongside this)

**Line Breaker** — the deliberate sibling of Line Walker: the baseline enemy walks the line; the boss exists to break it. Phases share the name. Shards are **Breaker Shard**. Descriptions ride the defs as always: the Breaker's is *"The Reclamation's siegework. It sheds what you break and comes back faster — switch with it, or watch it walk."*

---

## 7. Decisions a human can veto

1. **One boss, one appearance** (Corridor finale only). Veto by giving Breakup a second appearance; the price is that "the Breaker" becomes "a breaker", and the silhouette rule in §4 loses its exclamation mark.
2. **Full-HP phases (overkill discarded at boundaries).** This is the shipped split semantics and the anti-alpha texture is deliberate. Veto — carrying overkill across phases — needs the one real primitive this design otherwise avoids; I'd argue against paying it.
3. **Leak 6/5/4/2×2.** The ladder reads "a leaked boss ends a clean run's flawless, and nearly ends a scraping one". Veto softer numbers if B1 shows the chain leaking often at tuned difficulty — but fix the difficulty first, the drama second.
