# CLAUDE.md

The project rules for this repo live in **[AGENTS.md](./AGENTS.md)**. Read that file first — it is the single source of truth for architecture, commands, conventions, and the definition of done.

Keeping one canonical file avoids the classic failure where Claude and Codex are working from two subtly different sets of rules. If you need to change a rule, change it in `AGENTS.md`.

## Quick reference

```bash
godot --headless --path . --import                              # after a fresh clone
godot --headless --path . --script res://tests/run_tests.gd     # the gate — must exit 0
godot --headless --path . --script res://tests/run_autoplay.gd  # the view-layer gate
godot --headless --path . --quit-after 600                      # boot check (frames, not ticks)
godot --path .                                                  # play it
```

## The four things worth repeating

1. `sim/` is pure logic — no `Node`, no engine `delta`, no ambient RNG, integer money. `game/` renders and forwards input; it holds no rules.
2. Balance lives in `data/*.tres` and `data/maps/*.layout.txt`. Adding a tower or enemy should be a new data file, not a new class. Damage and HP are on a 10× scale so the integer armour table stays honest.
3. `tests/cases/test_determinism.gd` is a release blocker. If it fails, fix the cause rather than the assertion.
4. Nothing in `tests/cases/` builds a node, so `tests/run_autoplay.gd` is the only check that executes `game/views/`. Run it before calling view work done.
