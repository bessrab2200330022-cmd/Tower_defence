# Campaign structure — the meta decision

**Owner:** A2 (design) · **Decides:** BACKLOG item 9 · **Blocks:** A4's menu and level select (this session) · **Touches:** nothing in `sim/**`, by construction

BACKLOG 9 asks: between-run unlocks, or a campaign map? Two maps exist and nothing connects them. This file is the decision, sized to the honest constraint: a solo project with agent labour, where meta-progression is the classic thing that eats a year and returns a spreadsheet.

---

## 1. The call

**A linear campaign of ordered maps, gated by completion, with one thin per-map record. Nothing else persists.**

Concretely: The Crossing is slot 1 and always playable. Each later map unlocks when the previous one has been **completed at least once** (any lives — a 1-life scrape counts). A completed map stays freely replayable forever, and the thing you replay *for* is your own record: the profile stores, per map, `completed`, `best_lives`, and — once the flawless achievement exists — `flawless`. Three fields, one file, done.

No meta currency. No between-run unlocks of towers or tiers. No difficulty selector at launch. No hub. Every run of every map starts from the same kit the balance harness knows about, and ends leaving nothing behind but a record and, later, a replay.

---

## 2. Why not the other three

**Between-run unlocks are structurally poisonous here, not just expensive.** Three separate kills, any one of which would suffice:

- **They break the replay format before it ships.** ROADMAP 3.1/3.4's entire elegance is that a run *is* `seed + map id + command log` — a few hundred bytes, replayable, and a leaderboard score that can be **verified server-side**, which almost no game in the genre can claim. Meta state adds a third input to every run that lives outside the log. Either the save format grows an unlock-state header that must be validated against progression rules (congratulations, we now maintain an anti-cheat), or replays silently desync. The deterministic architecture is the project's one unfair advantage; meta unlocks tax it first.
- **They invalidate the instrument.** Every gate in difficulty.md §4 is calibrated against a fixed toolkit. With unlocks, "is wave 6 fair?" has no answer — fair *at which unlock state?* The harness would have to sweep policies × unlock states, and every content addition would multiply the matrix. We just spent two rounds making balance measurable; this un-measures it.
- **They are the year-eater the brief names.** Unlock trees demand enough content to gate (we have three towers — gating any of them makes the taught curriculum unteachable, since waves 1–5 *are* lessons about specific towers), plus economy design, plus UI, plus save migration. All of it is work that makes the game *longer to build* and none of it makes wave 8 more interesting.

**A hub is UI cosplay at this scale.** Hubs earn their keep at a dozen-plus nodes with meaningful choice of order. We will ship with three maps whose difficulty is deliberately sequenced (the Corridor assumes upgrade fluency the Crossing teaches). A free-choice hub either lies about that sequencing or reimplements gating and calls it geography.

**An unlock tree needs a tree.** Three nodes is a line. Call it one.

**Difficulty modes** are the one genuinely tempting cut — and they are a *post-ship lever*, not a launch feature: each mode multiplies the gate table, and the harness should earn one difficulty first. One line in the profile schema (`version`) keeps the door open.

---

## 3. What persists, exactly

A single config file in user space (the conventional `user://` location; exact serialisation is A4's choice — `ConfigFile` is fine):

| Field | Type | Written when |
| --- | --- | --- |
| `version` | int (1) | first write |
| `<map_id>/completed` | bool | on `GAME_WON` |
| `<map_id>/best_lives` | int | on `GAME_WON`, if higher than stored |

Rules that keep this clean: the profile is written by the **view layer on drained events** (`GAME_WON` already carries what's needed) — `sim/` never reads or writes it, it is not an input to any simulation, and it never appears in a replay. Losing the file loses records, never content-corrupts. That is the whole persistence system, and it should stay embarrassing to look at.

`flawless` (won at 20/20) joins as a third per-map bool when the achievement pass lands — it is readable from the same event, so adding it later costs one line.

---

## 4. The unlock rule, precisely

```
playable(map[0]) = always
playable(map[i]) = profile[map[i-1]].completed        for i > 0
```

Campaign order is data the menu owns: today `["crossing", "the_corridor"]`. **When The Fork ships it inserts at slot 2** (`["crossing", "fork", "the_corridor"]`), and one retrofit rule keeps old profiles honest: *a map is also playable if any later map in the order is completed.* A player who beat the Corridor before the Fork existed keeps everything and gains a new unlocked map — insertion never locks anyone out of anything they had.

Completion gating (not lives-threshold gating) is deliberate: difficulty.md G5 wants weak play to *lose on wave 5 of map 1*, so completion is already a real bar. A lives threshold on top would double-charge the same skill test and turn the record chase into a gate grind.

---

## 5. What the menu is (for A4)

Title screen → **one level-select screen**: campaign maps as cards in campaign order.

- Unlocked card: map name, small board silhouette, `Best: 17/20` badge (blank until first win), Play.
- Locked card: darkened silhouette, no name tease needed (there are three maps, mystery is not the product), one line: **"Hold The Crossing first."** — the string pattern is `Hold <previous map name> first.` and lives with the other canon strings in voice.md's orbit.
- A **Continue** button on the title screen jumps straight to the furthest unlocked, uncompleted map — the one-click path for the common case.
- Wave count and last-cleared-wave are *not* stored or shown at launch; the record is lives-at-win, one number, legible at a glance.

Nothing here needs sim work, new events, or schema changes. The event the profile writer needs already exists.

---

## 6. Future hooks (one line each, none built now)

- **Endless mode (3.4):** unlocks *per map* on that map's completion; its verifiable-leaderboard story is exactly why §2 protects the replay format.
- **Difficulty modes:** post-ship; profile `version` bump plus per-mode records; gates re-derived per mode by the harness, or not shipped.
- **The Fork:** slots in at 2 via §4's insertion rule; no profile migration needed.
- **Achievements (STEAM.md):** all counters over drained events; `flawless` lands alongside.

---

## 7. Decisions a human can veto

1. **Any-lives completion gating** (vs a lives threshold for unlock). Veto raises the §4 rule to `best_lives ≥ N`; expect it to feel like the same exam taken twice.
2. **No difficulty selector at launch.** Veto costs a gate-table multiplication per mode, priced in difficulty.md terms before A3 commits to it.
3. **Records are lives-only.** Veto to add per-map fastest-clear ticks — cheap to store (the sim counts ticks deterministically), one more column of UI, and a genuine speedrun axis; I left it out to keep the launch record legible, not because it's hard.
