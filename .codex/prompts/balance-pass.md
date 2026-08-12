# Prompt: balance pass

Tune the numbers so the difficulty curve matches this target:

- Wave 1: survivable with **one** tower, but it must cost a life or two if the player builds nothing.
- Waves 2–3: comfortable with **three or four** towers if placed sensibly.
- Wave 4: punishes a player who has built only kinetic towers.
- Wave 5: requires a mixed loadout and a deliberate slow. Should feel close.
- A perfect run ends with roughly 40–60% of starting credits unspent, so upgrades have somewhere to go later.

## Method

Do **not** balance by intuition. This sim is deterministic and headless — measure it.

1. Write a throwaway script under `tests/` (or extend `tests/cases/test_content.gd`) that runs full matches with a fixed build order and reports lives lost, credits at the end, and ticks per wave.
2. Iterate on `data/towers/*.tres`, `data/enemies/*.tres` and `data/waves/*.tres` only. **Do not touch `sim/`** — if the numbers cannot express the curve you want, that is a finding to report, not a licence to change the rules.
3. Keep the changes legible: state the before/after for each number you moved and why.

## Constraints

- The damage-type × armour-type table in `sim/damage.gd` is the primary lever for making tower variety matter. Prefer adjusting archetype stats over flattening that table.
- Every tower must have a situation where it is the correct purchase. If you cannot name one, the tower is redundant — say so.
- Currency is integer credits. Bounties and costs stay whole numbers.

## Done when

- The test suite exits 0, including the pacing smoke tests
- You have posted the measured numbers (lives lost and credits per wave, before and after) in the PR description
- `test_determinism.gd` still passes — a balance pass should never touch determinism
