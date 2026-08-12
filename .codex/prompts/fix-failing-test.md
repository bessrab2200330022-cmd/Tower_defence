# Prompt: fix a failing test

The suite is red. Reproduce, diagnose, fix.

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

Failing suite/test: `<paste the failure line, e.g. test_simulation::test_tower_kills_enemy_and_pays_bounty - expected 435, got 425>`

## Method

1. **Reproduce first.** Run the suite and confirm you see the same failure. If you cannot reproduce it, say so rather than guessing at a fix.
2. **Narrow it.** The sim is deterministic, so a failure is exactly reproducible. Add temporary `print()` calls or a scratch test that steps tick by tick and dumps `Simulation.snapshot_hash()` until state diverges from expectation.
3. **Fix the cause, not the assertion.** Only change a test when you can articulate why the old expectation was wrong. "The test is now inconvenient" is not a reason.
4. **Check the blast radius.** A bug in `sim/` usually means a missing test somewhere else too. Add the test that would have caught it earlier.

## Special case: `test_determinism.gd`

If this is the failing suite, treat it as a release blocker. The usual causes, in order of likelihood:

- Something in `sim/` started reading engine state (`Time`, `Engine.get_frames_drawn()`, `randi()`).
- A `Dictionary` is being iterated where insertion order changed between runs.
- An entity array is mutated during iteration, changing processing order.
- Floating-point accumulation replaced an integer counter.

Never relax the assertion or reduce the tick count to make it pass.

## Done when

- The suite exits 0
- `godot --headless --path . --quit-after 600` prints no errors
- The PR description names the root cause in one sentence
