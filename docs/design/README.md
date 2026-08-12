# docs/design/

Design documents. **Prose, not code.**

Owned by the design agent (A2 in `../WORKSTREAMS.md`). Everything here is a specification that the simulation agent or the view agent implements — nothing in this folder is executable and nothing in it should reference a file path or a function name unless it is describing an existing one.

## Contents

All four founding documents are written and accepted.

| File | What it decides | Status |
| --- | --- | --- |
| `difficulty.md` | Nine falsifiable harness gates (G1–G9) over three scripted player archetypes; what's fixed identity vs what's a tunable knob; a hypothesis for the wave-3 loss. **The target the balance harness measures against.** | Accepted |
| `upgrades.md` | Three tiers, linear at tier 2, **branch at tier 3**. Full stat tables and effective-DPS matrices for all nine upgrade defs. | Accepted |
| `enemies.md` | Five new enemies in deterministic integers, spawn tables for waves 6–10, counter-matrix. | Accepted |
| `voice.md` | Premise, naming rules, canon strings for every def, UI copy, draft Steam page. | Accepted |

**Accepted means the design is settled, not that the numbers are right.** Everything numerical in `difficulty.md` and `upgrades.md` is paper arithmetic pending the balance harness — uptime assumptions especially. The gates exist precisely so the harness can falsify them.

Two mechanics still need confirmation from the simulation before their designs are implementable: whether **hitscan + splash** works together (Hailstorm; a fallback is specified) and how **slow stacking** resolves (Glacier; specified as strongest-wins, non-stacking).

## Constraints a design here must respect

These are architectural, not preferences. A design that breaks one of them cannot be implemented as written.

- **Damage and HP are on a 10× integer scale.** No floats anywhere in the economy or the damage path.
- **Three damage types × four armour types**, with integer percentage multipliers. See `sim/damage.gd`.
- **Everything must be expressible as data** in a `.tres` file. If a design needs a genuinely new mechanic, say so explicitly rather than assuming it can be bolted on — the simulation agent needs to schema it first.
- **Determinism is non-negotiable.** Anything involving randomness must be expressible as integer probability over tick counts, driven by the seeded RNG. "Occasionally", "sometimes" and "randomly" need to become numbers before they can ship.

## Why this folder is separate from the code

Design decisions and their reasoning outlive any particular implementation. When someone asks in four months why the Frost Mortar slows by exactly 40%, the answer should be a paragraph in `difficulty.md`, not an archaeology exercise in the `.tres` history.
