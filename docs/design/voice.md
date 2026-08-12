# Voice — naming, flavour, copy

**Owner:** A2 (design) · **Feeds:** every `display_name`/`description` field, the HUD's strings, and eventually the Steam page (`docs/STEAM.md`) · **Status:** canon for everything that exists; Steam section is a draft until Phase 5.

Sci-fi, not fantasy. This file is the single source of truth for names and player-facing text — when a `.tres` string and this file disagree, one of them is wrong and it's probably the `.tres`.

---

## 1. The premise, in five sentences

A shattered world. Its last islands hang in the sky on old gravity **anchors**, and the **Bastion Line** — an automated defence grid — is what keeps them theirs. **The Reclamation** has arrived: a mindless orbital salvage swarm that strips dead worlds for stock, and has decided this one qualifies. It makes landfall at the edge of the island and walks, patiently, toward the anchor. You are the Line's operator; the machines are yours; hold.

That's the whole fiction, and it is deliberately thin — this is a game about a damage table, and the premise's job is to make the damage table *diegetic*: machines against machines, bloodless, legible, honest. It also names everything we need: the spawn marker is **Landfall**, the goal is **the Anchor**, lives are **Integrity**, and the enemy is a tide, not a villain.

**Tone:** clean, technical, a little dry, with room for wonder at the vistas and menace in the tide. Field-manual, not grimdark; wry, never jokey. The narrator is the Line's own maintenance text, addressing the player as **Operator** when it addresses anyone at all.

---

## 2. Naming rules

- **Towers:** two words, mechanism + form — *Arc Cannon, Plasma Lance, Frost Mortar*. Already canon; keep.
- **Upgrade tiers:** one strong word or a tight compound — *Overclock, Glacier, Railshot*. Never roman numerals; the UI shows tier, the name shows identity.
- **Enemies:** plain field-manual nouns, as if catalogued by the Line itself — *Line Walker, Siege Brute, Mender*. Designations, not names.
- **Waves:** operational one-worders (or near) — *Pressure, Skyfall, Breakwater*.
- **Maps:** "The" + a terrain fact — *The Crossing*; future: *The Corridor*, *The Fork*.
- No Greek-letter soup, no Latin binomials, no apostrophe names, no acronyms the player must learn. Everything pronounceable on a first read.
- **Descriptions are two sentences maximum:** what it does mechanically, then one flavour clause. The shipped Shielded Scout line — "*Energy shielding shrugs off bullets and shrapnel. Punish it with the Plasma Lance.*" — is the house style: the description *is* the tutorial.

**Words we don't use:** magic, spell, hero, mana, gold, XP, castle, minion, monster. Not "units" — *machines*. The enemy collectively is *the tide*, *the salvage*, or *the Reclamation*.

---

## 3. Canon — towers

Base-tier names and descriptions are shipped and stay as written. Tier names below are canon for [upgrades.md](./upgrades.md); accent identity is guidance for A1's tier visuals and the existing colour fields.

| Def | Name | Description (canon string) |
| --- | --- | --- |
| arc_cannon | Arc Cannon | *(shipped text stands)* |
| arc_cannon_t2 | **Overclock** | Twin feed lines double the cycle rate. Everything the cannon was, twice as often. |
| arc_cannon_t3a | **Hailstorm** | Rotary flak that bursts on impact. Packs get shredded; a lone target barely notices the upgrade. |
| arc_cannon_t3b | **Railshot** | One long rail, one heavy slug, a longer reach. Still kinetic — shields still don't care. |
| plasma_lance | Plasma Lance | *(shipped text stands)* |
| plasma_lance_t2 | **Focused Array** | Recollimated emitters drive the beam harder and further. Three shots drop a shielded scout. |
| plasma_lance_t3a | **Prime Focus** | The whole array behind a single emitter. One target at a time stops existing. |
| plasma_lance_t3b | **Fork Array** | The beam splits on contact, arcing to two nearby machines at half charge. Built for shielded columns. |
| frost_mortar | Frost Mortar | *(shipped text stands)* |
| frost_mortar_t2 | **Deep Barrel** | A longer barrel, a heavier shell. Wider frost, longer chill. |
| frost_mortar_t3a | **Glacier** | Saturation frost. Inside the blast the tide moves at a crawl — your lances do the rest. |
| frost_mortar_t3b | **Shatterhead** | Fragmenting shells trade most of the chill for raw blast. Drone packs simply end. |

Accent identity (for `accent_color`/`effect_color`, A1's call on exact values): Arc family stays warm brass; Hailstorm sparks white, Railshot burns orange. Lance family stays cold violet; Prime Focus goes near-white, Fork Array splits cyan. Mortar family stays glacial blue; Glacier deepens toward ultramarine, Shatterhead pales toward steel.

---

## 4. Canon — enemies

Existing four: shipped text stands. New six ([enemies.md](./enemies.md) stat blocks):

| Def | Name | Description (canon string) |
| --- | --- | --- |
| courser | **Courser** | Runs the line at twice a walker's pace. The trick is guns where it will be, not where it was. |
| skiff | **Skiff** | Skips the path and flies the straight line to the Anchor. Mortars can't reach it — keep flak or beams on the sky. |
| warden | **Warden** | Projects a dampening field over everything marching near it. Kill the shepherd, then the herd. |
| mender | **Mender** | A repair swarm in a hull, undoing your damage every other second. Focus it first, or fight the same walkers twice. |
| fission_crawler | **Fission Crawler** | Comes apart on death into two sprinting spawn. Kill it early and the children walk your whole gauntlet; kill it late and they don't have to. |
| fission_spawn | **Fission Spawn** | Half a crawler, twice the hurry. |

---

## 5. Canon — waves and maps

| Wave | Name | | Wave | Name |
| --- | --- | --- | --- | --- |
| 1 | Probing Run | | 6 | **Skyfall** |
| 2 | Pressure | | 7 | **Stampede** |
| 3 | First Shields | | 8 | **Phalanx** |
| 4 | Armour Test | | 9 | **Fission** |
| 5 | Breakthrough | | 10 | **Breakwater** |

Waves 1–5 are shipped and stand. *Breakthrough* (5) and *Breakwater* (10) are a deliberate echo — the mid-term and the final. Map: **The Crossing** (shipped). Reserved for the backlog's next two maps: **The Corridor** (the long single lane), **The Fork** (the split route).

**The Corridor's own ten waves** (shipped with the map) take their names from the dead river that cut the canyon — dry-country words, operational like the Crossing's:

| Wave | Name | | Wave | Name |
| --- | --- | --- | --- | --- |
| 1 | Dry Run | | 6 | Static |
| 2 | Silt | | 7 | Undertow |
| 3 | Glare | | 8 | Bedrock |
| 4 | **Flash Flood** | | 9 | Scree |
| 5 | Grindstone | | 10 | **Watershed** |

*Flash Flood* is the Courser's debut, and the name is the tutorial: the one thing that still moves fast through a slot canyon. *Watershed* is the finale — the decisive point, in a canyon a river made.

---

## 6. UI copy

Mechanic names in docs stay *lives* and *credits*; what the player reads is below. Strings live in `.tres` fields and the HUD until the localisation pass (backlog 11) extracts them.

| Where | Canon string |
| --- | --- |
| Lives readout | **Integrity** (icon: shield; "Integrity 17/20") |
| Currency readout | **Credits** |
| Build phase banner | **Prepare the Line** |
| Combat phase banner | **Wave N — hold.** |
| Start-wave button | **Start Wave** (flavour tooltip: "The tide won't wait forever. But it will wait.") |
| Sell button | **Sell** ("Refunds 70% of everything invested.") |
| Upgrade button | **Upgrade** — at the fork: **Choose the pattern** with both options previewed |
| Target modes | First / Last / Closest / Strongest / Weakest *(shipped enum labels stand)* |
| Leak toast | **Breach — Integrity −N** |
| Wave cleared | **Wave held.** |
| Victory screen | **The Line holds.** — subline: "Landfall is quiet. The Anchor is yours, Operator." |
| Defeat screen | **The Line is breached.** — subline: "The Anchor is lost. Rebuild, and hold longer." |

Damage types read **Kinetic / Energy / Explosive**; armour reads **Light / Medium / Heavy / Shielded** — the schema's own labels, which are already correct. Tooltips always show both words, never colour alone (the colourblind constraint in ROADMAP Phase 4 applies to text too).

---

## 7. Steam page — DRAFT (Phase 5)

Everything here is draft until the store page is real; nothing below may promise a feature that isn't merged.

**Short description (store capsule, ~290 chars):**

> The last islands of a shattered world hang from failing anchors, and the salvage tide is climbing. Build the Bastion Line: three towers, nine ways to grow them, one honest damage table. A deterministic tower defence where every loss has a reason and every run can be replayed.

**About This Game (skeleton):**

*Hold the Line.* — the fantasy paragraph: sky islands, the Reclamation makes landfall, the Anchor must stand.

*Every number is honest.* — the systems paragraph: integer damage, a readable type chart, no hidden rolls; the same seed and the same choices produce the same battle, every time. (When endless mode and replays ship, this paragraph gains: shareable replays a few hundred bytes long, and leaderboards that can be *verified*, not trusted.)

*Nine towers from three.* — the content paragraph: every tower forks; wardens, menders and crawlers that change the kill order, skiffs that ignore the ground; ten-wave campaigns where every wave teaches one thing and the exams recombine them.

**Tags:** Tower Defense, Strategy, Sci-fi, Low Poly, Singleplayer, Indie, Replayable, Tactical.

**Capsule art direction:** one island in silhouette against the void, waterfalls off the edge, a single beam firing up-frame at an unseen tide. The title reads at thumbnail size or the capsule fails — test at 231×87 first, not last.

**Trailer beat sheet (30s):**

| Time | Beat |
| --- | --- |
| 0–3s | Slow orbit of the island. Waterfalls, cloud deck. One tower, alone. Quiet. |
| 3–8s | Build clicks — pads fill, the first wave walks Landfall, arc fire opens up. |
| 8–16s | Escalation cuts on the beat: shields shrugging bullets → a Lance answering; Hailstorm into a drone flood; a Skiff sailing over a kill-box. |
| 16–24s | Wave 10. Glacier field crawling with the tide, near-breach at the Anchor, Integrity ticking. |
| 24–29s | Cut to silence. The last Brute falls — or the screen holds one frame before it would. Title card: **BASTION LINE**. |
| 29–30s | *Hold the Line. Wishlist now.* |

---

## 8. Localisation notes (for backlog 11, written now so the strings survive it)

Canon strings above are built to translate: short declaratives, no idioms, no puns that die outside English ("twice the hurry" is the riskiest line in this file — an acceptable casualty, flag it for translators). Proper nouns — Bastion Line, the Reclamation, tier names, enemy designations — translate at the translator's discretion except **Bastion Line** itself, which is the brand and stays. Keep every string's mechanical clause literal: "slows by 40%" must survive translation exactly, because the description is the tutorial.
