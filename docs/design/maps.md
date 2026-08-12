# Maps 2 & 3 — The Fork and The Corridor

**Owner:** A2 (design) · **Implements:** BACKLOG 4 / ROADMAP 3.2 · **Consumed by:** A3 (layouts, pathfinder, wave lists, harness), A1 (biome kits, palettes)

The Crossing taught the curriculum on friendly ground: one road, pads everywhere. These two maps each take one of those givens away. **The Fork** removes *one road* — coverage becomes a budget. **The Corridor** removes *pads everywhere* — ground becomes the currency. A map that changes nothing about the build order is scenery; each of these should visibly rewrite it, and each has a gate that fails if it doesn't (F3, C3).

Both layouts below are **verified by script**: rectangular, one S and one G, path connected, every path cell degree ≤ 2 except the fork's single fork/merge pair, the Fork's two routes exactly equal, the Corridor's pad count exactly as designed. The sketches are arguable, not final — but they are *consistent*, and any edit should re-run the same checks (§5).

---

## 1. Campaign position and ship order

**Campaign order:** Crossing → Fork → Corridor. The Fork's lesson (split coverage) is a prerequisite for the Corridor's exam (per-pad economics under scarcity — which assumes the player already knows *what* to buy and is being asked *where it goes deepest*). Lives are 20 on both — fixed identity, as on Crossing.

**Ship order is the reverse, and that is fine.** The Corridor needs **zero new sim work** — it is one path, today's pathfinder, a layout file and a wave list. The Fork is the one that costs engineering (multi-route support, §3). Build the Corridor first as campaign map 3; the Fork lands with ROADMAP 3.2 and slots in as map 2. Until menus exist the map order is dev-side anyway.

Each map gets its own 10-wave list in the Crossing grammar (one new fact per wave, exams recombine). Full spawn tables are a later choreography pass — this brief fixes each map's *shape of pressure* (§2.4, §4.4) so those tables have something to aim at.

---

## 2. Map 2 — The Fork

### 2.1 The layout

```
..........................
....#################.....
....#...............#.....
....#...............#.....
....#...............#.....
....#...............#.....
XXX.#...............#XXXX.
S####...............#####G
XXX.#...............#XXXX.
....#..####..########.....
....#..#..#..#............
....####..####............
..........................
..........................
..........................
```

26 × 15. Verified: **two routes, 38 cells each** (S→G in 37 steps, ~74 units walked), branch interiors exactly 27/27, shared head 5 cells including S, shared tail 6 including G; the fork and merge are the only degree-3 cells on the board.

Two roads with two personalities. The **north run** is one long glazed straight — maximum sightlines, a sniper's road. The **south switchback** folds three times through a crevasse field — lanes 4 units apart, where a pad inside a fold sits within 2.8 units of multiple segments: an Arc or Mortar there hits the same enemies twice as they double back. The map's two roads pose the same question the tower forks do — go long, or go dense — which is deliberate: this is the map where players cash in the tier-3 decisions they made on Crossing, one branch per road (Railshot/Focused north; Hailstorm/Deep Barrel south).

Routes are ~60% of Crossing's 122-unit lane **on purpose**: the difficulty here is split coverage, not lane length, and short roads keep slow (which buys *fractions* of a lane) valuable rather than mandatory.

### 2.2 What it asks that The Crossing does not

One new fact: **coverage is a budget.** Every credit standing on one road is absent from the other. The shared segments are deliberately too small to dodge the question: the head is under two seconds of Walker exposure, the tail four cells ending at the goal — a turtle there is not a defence, it is a coin flip with the leak counter (F4 makes this falsifiable). Examines from earlier: damage-type matching under simultaneous pressure (shields on both roads at once), slow on short lanes, and the upgrade forks.

### 2.3 Family bias — with the geometry that causes it

**Favours the Lance family, structurally.** The mid-band is the map's signature real estate: a row-7 pad sits **4.5 units** from the south system (any tower reaches) and **12 units** from the north lane — base Lance range 13 covers both roads from one cell, and nothing cheaper does. But centre lances fight *thin*: at distance 12, a range-13 circle covers a 10-unit chord of the north lane (~5 cells); a dedicated north-side pad at distance 2 covers ~13 cells. Centre = flexible but shallow, dedicated = deep but committed. That tension is the map, and F5 checks it stays a tension rather than a dominant strategy.

**Favours Mortars — but only in the folds.** The south switchback is the best splash/slow geometry in the game. It is also a commitment: a fold Mortar contributes nothing to the north road, ever.

**Punishes single-choke builds and Arc sprawl.** There is no mid-map choke — the classic Crossing kill-box has no home here. And Arcs must pick a road; their range 8 reaches the mid-band's south side only, so the cheap-width strategy plays this map at half efficiency (Railshot's range 12 is the family's one mid-band ticket — priced accordingly).

**Air note:** the spawn–goal chord is **50 units, straight down the mid-line** — Skiffs fly directly over the lance band, so flak competes with lances for the premium pads. Fork Skiff waves are a capital-allocation attack, not a DPS check.

### 2.4 Route choreography — the wave-arc

Route usage is wave data (§3), which makes the fork a teaching instrument:

- **Waves 1–2:** north only, then south only. Each road introduces itself; the player builds both kits.
- **Waves 3–5:** even splits, then shields on one road while volume takes the other — the first true budget exam.
- **Waves 6–8:** feints — 80/20 splits that punish symmetric defence; Wardens leading the 80 side.
- **Waves 9–10:** simultaneous heavies both roads plus Skiffs down the mid-line. The near-breach should happen at the merge, in view of the goal.

### 2.5 Gates (F1–F8)

Method as difficulty.md §4, revision 2: quantified **over policy classes, not seeds** — the sim has no seed variance, so every percentage below is an exact count over an enumerated policy set. Reference class **S2-Fork** (a class, not one script), built on difficulty.md §2's composition rules plus this map's own axes: opening spends 75–90% of the wallet across ≥ 2 damage types with Arcs on the head pads; a Mortar in the south folds after wave 1; a mid-band Lance before the first shields and a second by wave 5; per-road Arcs from spare credits; upgrades from wave 6 (Focused mid, Deep Barrel fold); no sells. Class variation: which road gets the first spare Arc, fold-versus-road Mortar placement, and the saving policy.

| # | Gate | Pass condition |
| --- | --- | --- |
| F1 | S2-Fork wins | ≥ 85% of the class wins |
| F2 | Margin | Median lives across winning policies 10–16; no winning policy below 5 |
| F3 | **Thesis: route neglect is lethal** | The one-road-only subclass (S2 composition, all towers on one branch) loses ≥ 95% |
| F4 | Turtle cap | The subclass keeping every tower in range of only the shared head+tail loses ≥ 80% |
| F5 | Centre is viable, not dominant | The centre-lance subclass wins ≥ 85% AND gains ≤ +4 median lives over the road-split subclass |
| F6 | Near-run | Final wave: some enemy passes 70% progress in ≥ 75% of winning policies |
| F7 | Spend pressure | Median idle credits at win ≤ 30% of the start |
| F8 | S1 (mono-kinetic class) | Median terminal wave 5–7; no policy in the class survives past 8 |

Starting credits: **Crossing's tuned value** (the measured 560–960 window — difficulty.md §7). The split, not the wallet, is this map's difficulty. Starting lives 20.

### 2.6 Biome — snow (brief for A1)

**Fiction:** a braided meltwater fork around a moraine field; the north road is a glazed ice run, the south a crevasse switchback. Name canon: **The Fork** (already reserved in voice.md).

- **Palette** (the map resource's own colour fields): ground (0.85, 0.88, 0.92), path (0.55, 0.63, 0.72), blocked (0.42, 0.47, 0.55). The path must sit ~0.3 luminance below ground so pale-blue frost tints and the Glacier field read against it — frost-on-snow is this biome's one real readability risk; test the chill tint and the Warden film against these values before calling the kit done.
- **Kit:** snow-dust variants of the three existing pines; ice-shard recolour of the crystal prop; two new snowdrift mounds (trivial geometry); frost-cracked boulder recolours. The mid-band and fold pads are premium build ground — keep scatter off the open field so props never lie about buildability.
- **Lighting notes:** colder, lower sun; raised ambient/SSIL energy (snow bounces); faint cool fog. Beams and muzzle flashes are emissive and already clear the 1.05 bloom threshold — the risk is decals and tints, not effects.

---

## 3. What the Fork needs from A3

The design requirement, in one line: **both routes see traffic, deterministically, under wave-data control.** The rest is proposal — the pathfinder is yours.

1. **Route enumeration with stable ids.** Route 0 = the path BFS already finds under the existing fixed neighbour order — the tie-break must be a *documented consequence* of that order, not an accident that a refactor can flip. Route 1 = the alternative (e.g. re-run with route 0's branch-exclusive cells masked). This map guarantees exactly two.
2. **Route assignment on the spawn group** — a `route_hint` int: −1 (default) alternates per spawn within the group (even index → route 0, odd → 1); 0 or 1 forces a road. Deterministic by construction, pure data, and it makes §2.4 choreography possible. Alternation-by-index beats RNG here: no seed interaction, trivially testable.
3. **A route-count declaration on the map def** (default 1), validated at content-check time — so an innocent layout edit that opens a shortcut or a third route fails CI instead of silently breaking every wave's choreography.
4. **Tests:** route enumeration is deterministic (same layout → same routes, same ids, same cell sequences); spawn alternation is deterministic; and the determinism suite runs at least one fork-map match end to end.
5. **Equal length is load-bearing.** If the routes differ, BFS-shortest sends *everyone* down one road and the map dies. The layout checks in §5 exist to protect exactly this property — please run them on any edit.

Optional, for A4 later: the spawn event could carry the route id for debug overlays and an eventual wave-preview UI. Not required for ship.

---

## 4. Map 3 — The Corridor

### 4.1 The layout

```
XXXXXXXXXXXXXXXXXXXXXXXX
S######################X
XXXXX..XXXXX.XXXXXXXXX#X
XXXXXXXXXXXXXXXXXXXXXX#X
XXXXXXXXXXXXXXXXXXXXX.#X
XXXXXXXXXXXXXXXXXXXX..#X
XXXXXXXXXXXXXXXXXXXXXX#X
XXXXXXXXXXXXXXXXXXXXXX#X
XXXXXXXXXX.XXXXXXXXXXX#X
X######################X
X#XXXXXXXXXXXXX..XXXXXXX
X#XXXXXXXXXXXXXXXXXXXXXX
X#..XXXXXXXXXXXXXXXXXXXX
X#X.XXXXXXXXXXXXXXXXXXXX
X#XXXXXXXXXXXXXXXXXXXXXX
X#XXXXXXXXXXXXXXXXXXXXXX
X#XXXXXXXXXXXX..XXXXXXXX
X######################G
XXXXXXXXXXXXXXXXXXXXXXXX
```

24 × 19. Verified: **one route, 82 cells (~164 units — a third longer than Crossing), zero forks, and exactly 14 buildable cells** in 360 cells of canyon wall. One dead river, cut through mesa, walked end to end.

The 14 pads are the whole game: three pocket pairs and three singles carved into the walls along the arms, plus two three-pad **bend terraces** tucked inside the switchbacks — the only places where one pad ring sees two lanes at Arc range (6–8 units to both). Everything else is rock.

### 4.2 What it asks that the others do not

One new fact: **ground is the currency.** On Crossing the answer to pressure is another tower; here there is nowhere to put it. Per-pad output — not per-credit output — becomes the binding constraint, which makes this map the upgrade system's exam: the fork decisions bought casually on earlier maps get priced honestly here. Examines: tier-3 choices, slow (a 164-unit lane is Glacier's best market in the game), air (§4.3), and the Crawler's kill-early lesson at its sharpest — a splitter dying mid-arm releases children with 80 units to walk and, if you triaged wrong, no pad in reach.

### 4.3 Family bias — with the geometry that causes it

**The map's signature number is 14.** Every single-side pocket sits exactly **14 units** from the *far* arm — Focused Array's range 14 touches it at the rim, fragile and cell-dependent; **Prime Focus (16) owns it comfortably.** Cross-arm coverage — one pocket serving two passes of the canyon — is literally gated behind the tier-3 ladder. The geometry was built to the upgrade table, not the other way round; C5 checks the unlock actually pays.

**Favours tall money generally.** With 14 pads, all-base-Arc caps the board at 1,260 credits of DPS standing; the same pads carry a fully-forked kit north of 4,400. Glacier is the other tall star: one pad buying three seconds of 60% slow, reapplied, over a lane this long is worth more here than anywhere.

**Punishes width — and pure Mortar.** Cheapness is worthless when pads bind instead of credits (C3 is the thesis gate). And the air lane is brutal to control builds: the spawn–goal chord is **56 units against 164 on the ground** — Skiffs cut the canyon to a third, mortars cannot answer, so at least two scarce pads must hold flak. On the map that most favours Mortar-family control, the sky is the tax.

**The terraces keep Arcs honest.** Six pads of genuine dual-lane Arc ground — width's last oasis. Enough to matter, not enough to solve the map.

### 4.4 Shape of pressure — the wave-arc

Early waves gentle (income while the player learns pocket triage); mid-campaign Coursers exploit the long lane's *time* (a leaked pocket costs seconds nothing can buy back); a mid-arm Crawler wave teaches triage under splitter pressure; Skiff waves land whenever the player has just spent deep on ground DPS; finale: a Brute column under Mender support down the full canyon, with a Skiff flight over the top — depth against the floor, coverage against the sky, from 14 cells.

### 4.5 Gates (C1–C8)

Method as difficulty.md §4, revision 2 — policy classes, exact counts. Reference class **S2-Corridor**: Arc + Lance on the east terrace; Mortar at the arm-2 south pocket; Lance at the arm-2 north pocket upgraded Focused → Prime by mid-campaign (the cross-arm play); Glacier on the west terrace; one flak Arc per terrace by the first Skiff wave; upgrades preferred over new towers throughout (uses 7–9 of 14 pads). Class variation: pocket triage order, which terrace anchors first, and the saving policy.

| # | Gate | Pass condition |
| --- | --- | --- |
| C1 | S2-Corridor wins | ≥ 85% of the class wins |
| C2 | Margin | Median lives across winning policies 8–14; no winning policy below 4 |
| C3 | **Thesis: width cannot win** | The base-towers-only subclass (fills all 14 pads, never upgrades) loses ≥ 90% |
| C4 | Terraces matter | The subclass leaving both terraces empty loses ≥ 70% |
| C5 | The 14-unit unlock pays | The Prime-Focus-at-pocket subclass gains ≥ +2 median lives over same-spend members without it |
| C6 | Spend pressure | Median idle credits at win ≤ 30% of the start |
| C7 | S1 (mono-kinetic class) | Median terminal wave ≤ 6 |
| C8 | Near-run | Final wave: some enemy passes 70% progress in ≥ 75% of winning policies |

Starting credits: **Crossing's tuned value** — 640 as shipped, plus the wave-clear bonus of 12 the retune introduced; both inherited verbatim. The first draft opened the Corridor 60 richer so a Lance-first turn one was affordable at a 320 wallet; the measured window (560–960) makes that opening affordable everywhere, so the differentiator is dead — and on this map the wallet was never the binding constraint anyway. Fourteen pads are. Starting lives 20.

**Shipped note — the map id is `the_corridor`, not `corridor`.** The catalog's `first_map()` sorts map ids and everything downstream (the boot map, and the opening-map smoke test with its hardcoded Crossing build cells) treats the alphabetically-first map as map 1 — and `corridor` sorts before `crossing`. The id is the one in-lane fix, and it happens to scale: `crossing < fork < the_corridor` is exactly campaign order. The durable fix is A3's — an explicit opening-map designation (or the smoke test loading `crossing` by id), after which the id can normalise.

### 4.6 Biome — desert (brief for A1)

**Fiction:** a dead river's slot canyon through mesa country; the pads are ledges the canyon walls left behind. Name canon: **The Corridor** (reserved in voice.md).

- **Palette:** ground (0.78, 0.60, 0.38) — the ledges; path (0.58, 0.42, 0.30) — the river bed; blocked (0.46, 0.30, 0.22) — the walls.
- **Height is the kit's real job.** Blocked cells are four-fifths of this board — every non-path cell but the 14 pads — and they must read as *walls*, not floor — otherwise the corridor reads as a plain with a brown road. No board-code change needed: scatter tall props on X. One genuinely new model — a mesa spire, 2–3 blocks tall — plus large-rock recolours stacked near the lane edges sells the cut. Keep spires a cell back from the path so silhouettes never occlude enemies at the default camera pitch.
- **Kit:** mesa spire (new), three rock recolours, dry-brush recolour of the bush, sparse bleached-pine recolours on the rim. Heat haze is a lighting note, not an asset.
- **Lighting notes:** high warm key, deep AO down the cut, dusty haze. The map must read at the MEDIUM quality step — don't lean on SDFGI for the canyon shadow. Readability: warm muzzle flashes against warm sand rely on emissive contrast (fine); the Scout Drone's orange body against the river-bed brown is the one collision to check at RTS zoom — if it mushes, darken the path colour first, not the drone. Frost and Glacier effects on desert rock are maximum-contrast — happily, on exactly the map where the Mortar family's tier-3s matter most.

---

## 5. Layout acceptance checks (both maps, any future edit)

These take minutes to script against the ASCII and they protect load-bearing properties. They belong wherever A3 finds natural — the content test already boots every shipped map, and these are the same spirit:

1. Rectangular; exactly one S, one G (the existing map validation already covers this).
2. Every path cell has degree ≤ 2, **except** on a fork map: exactly one fork and one merge of degree 3.
3. Fork maps: shortest-route count and per-route lengths match the map's declaration — the Fork ships equal at 38/38, and unequal is a broken map, not a variant.
4. The Corridor: buildable count is **exactly 14**. The scarcity is the design; a well-meaning "just one more pad" edit should have to say so out loud, here.

---

## 6. Decisions made here that a human can veto

1. **Equal-length routes on the Fork** (38/38), with route choice as wave data via `route_hint`. The alternative — asymmetric lengths with slow-enemies-take-the-short-road choreography — is subtler but couples route design to every enemy's speed forever. Veto reshapes §3.
2. **`route_hint` defaults to alternate** (−1), so a hint-less wave file exercises both roads. Alternative default (route 0) makes old wave files single-road by surprise on a fork map.
3. **Snow = Fork, desert = Corridor.** Swappable; the readability arguments (frost legibility, canyon height) travel with the swap and are written above.
4. **The Corridor's pad count is 14.** This is the scarcity dial: 12 is brutal, 16 is soft. Change it in the layout *and* in check §5.4 together.
5. **Both maps inherit Crossing's tuned starting credits.** The first draft gave the Corridor +60; the measured economy (560–960 window) made that differentiator meaningless, so it was dropped in revision. Veto by giving either map its own value — but per difficulty.md §7's post-harness rule, anchor it to a credit sweep *on that map*, not to a hunch.
