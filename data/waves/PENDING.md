# PENDING — staged wave and map content

A2 owns `data/waves/**` and `data/maps/**`. Files suffixed `.tres.pending` are
invisible to the catalog (it loads only `*.tres`), so the suite stays green
while their dependencies land. The convention mirrors `art/PENDING.md`.
Two staged sets live here.

---

## 1. Crossing waves 6–10 — **now unblocked**

`wave_06..10.tres.pending` extend The Crossing to ten waves
(`docs/design/enemies.md` §5). They were staged against enemy defs that did
not exist; **as of 12 Aug all nine roster defs are landed**, so the checklist
below is executable today by whoever wants the campaign at full length:

1. Rename all five files: strip `.pending`.
2. Append to `data/maps/crossing.tres` `wave_ids`, in order:
   `"wave_06" … "wave_10"`. All five at once — a partial append fails
   validation by design.
3. Run the suite. Then run the harness against difficulty.md §8's bands —
   the waves are verified to *load and spawn exactly* (stub-def runs, spawn
   counts 31/38/16/25/48), **not** to be fair; abilities have never met these
   compositions.

**Income-assumption drift, flagged:** these waves' totals were computed at
enemies.md §2's rescaled bounties (skiff 14 / warden 31 / mender 28 /
crawler 9 / spawn 3). A3 landed the pre-rescale draft values
(18 / 40 / 36 / 12 / 4) — the doc and the data disagree, the same drift the
Courser had, in the other direction. At landed values the four newcomers pay
~1.3× their intended rate relative to the rescaled roster; waves 6–10 income
runs ~90 credits rich. One of the two should move — A3's call with the
harness; difficulty.md §8's spend-pressure rule is the referee.

**Standing proposal:** `wave_05.tres` drone interval 19 → 17 (Hailstorm pack
spacing, 2.22u → 1.98u). Belongs to the next balance pass.

---

## 2. The Fork — map and ten waves, staged for multi-route pathfinding

`data/maps/fork.tres.pending`, `data/maps/fork.layout.txt` (plain file —
inert until the map def loads it), and `fork_01..fork_10.tres.pending`.

**Layout, verified 12 Aug (maps.md §5 checks):** 26×15, exactly two routes of
**38 cells each** (branch interiors 27/27 — equal length is load-bearing:
unequal routes send every enemy down one road under BFS-shortest), one fork
(7,4), one merge (7,20), shared head 5 cells / tail 6. Also verified in-engine:
the map **boots and plays under today's single-route pathfinder** (the
tie-break walks one 38-cell route), and all ten waves loaded, cross-referenced
and spawned exact counts (13/21/19/34/18/25/25/23/20/58 leak-lives undefended).

**Blocked by (maps.md §3, A3's lane):** route enumeration with stable ids,
`route_hint` on SpawnGroup, and the route-count declaration on MapDef.

**`route_hint` is already written into the staged files** — verified harmless:
Godot silently drops unknown properties on load, so the hinted files load
clean under today's schema and the hints become live when the field lands.
That silence cuts both ways, so the activation checklist ends with a positive
assertion. Semantics assumed (maps.md §3 item 2): −1/absent = alternate per
spawn (even→route 0, odd→1); 0/1 = forced. Skiff groups are never hinted —
fliers ignore roads. Hinted groups per wave: fork_01 2/2 · 02 3/3 · 03 2/3 ·
04 0/2 (pure alternation — spacing tuned for it: 24 drones @7t = per-road
14t, 1.63u Hailstorm packs on both roads) · 05 2/4 · 06 2/3 · 07 3/4 ·
08 4/4 (the 80/20 feint) · 09 4/5 · 10 6/9.

**Activation checklist (after A3's route support lands):**

1. Confirm the landed field is named `route_hint` with the semantics above —
   if it landed under another name, sed the eleven staged files *first*
   (unknown properties are dropped silently; nothing will error, the waves
   will just all-alternate).
2. Strip `.pending` from `fork.tres` and all ten `fork_*` waves.
3. Run the suite; then assert on one hinted group that the loaded resource
   reports its hint (a one-line check in A3's route tests covers everyone).
4. Point the harness at maps.md §2.5's F-gates.

**Income assumptions:** landed bounties (18/40/36/12/4 for the newcomers).
Fork campaign total ≈ 3,558 incl. start (+40 conditional from crawler
spawns) — lands ~3,470 if the §1 bounty question resolves toward the doc.
Shapes are the design; totals are the harness's to move.
