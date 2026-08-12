# Prompt: implement a feature

Implement **`<FEATURE>`**.

Goal: `<one or two sentences — what should the player be able to do afterwards that they can't now?>`

Backlog reference: `<docs/BACKLOG.md item, if there is one>`

## Method

1. **Read `AGENTS.md` first.** The sim/view split is the constraint that everything else hangs off.
2. **Decide which layer this belongs in before writing code.**
   - Changes what happens in the game → `sim/`, and it needs tests.
   - Changes only what the player sees or clicks → `game/`.
   - Changes numbers → `data/`, no code at all.
   - If it spans layers, the sim part goes first and gets tested before the view part exists.
3. **Design the data shape before the logic.** If the feature introduces new content (upgrade tiers, abilities, modifiers), extend the schema in `data/schemas/` so future additions are data files rather than code.
4. **Write the test as you go**, not afterwards. The sim is deterministic and headless, so a test is usually faster than launching the game to check.
5. **Keep the diff focused.** Do not reformat, rename or "tidy" files the feature does not touch.

## Constraints

- `sim/` may not import from `game/`.
- `Simulation.step()` is called from `game/main.gd` and nowhere else.
- No new addons or dependencies without a justification in `docs/ARCHITECTURE.md`.
- Public functions are statically typed.

## Done when

- `godot --headless --path . --script res://tests/run_tests.gd` exits 0
- `godot --headless --path . --quit-after 600` prints no `ERROR:` or `SCRIPT ERROR:` lines
- New `sim/` behaviour has a test in `tests/cases/`
- `AGENTS.md` and `docs/` reflect any rule, command or layout change
- `docs/BACKLOG.md` is updated — item moved to done, or split into what's left
