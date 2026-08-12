# Codex kit

Everything Codex needs to work on this repo without a human in the loop.

## Environment setup

Point your Codex environment's **setup script** at:

```
bash .codex/setup.sh
```

It installs Godot headless (version pinned by `GODOT_VERSION`, default 4.7) (plus the X/GL shared libraries the headless binary still links against), warms the import cache, and runs the test suite so the container fails fast if the environment is wrong.

If your sandbox has no network access at task time, the setup script runs during the *setup* phase where downloads are allowed — that is the right place for it.

## Task prompts

`.codex/prompts/` holds ready-made prompts for the jobs that come up repeatedly. Paste one in and fill the blanks.

| Prompt | Use it for |
| --- | --- |
| `new-tower.md` | Adding a tower archetype |
| `new-enemy.md` | Adding an enemy archetype |
| `new-map.md` | Adding a map |
| `balance-pass.md` | Tuning numbers against a target difficulty curve |
| `fix-failing-test.md` | Handing over a red suite |
| `feature.md` | Anything larger — the generic template |

## The one instruction that matters

Codex reads `AGENTS.md` at the repo root automatically. Everything in it applies. The short version:

* `sim/` stays pure — no `Node`, no engine `delta`, no ambient RNG, integer money.
* Balance lives in `data/`, not in `.gd` files.
* A change is done when `godot --headless --path . --script res://tests/run_tests.gd` exits 0 **and** the new behaviour has a test.
