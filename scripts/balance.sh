#!/usr/bin/env bash
# Balance harness (ROADMAP 0.1). Plays a few hundred headless matches across
# placement policies, build orders and saving policies, and reports what the
# game currently is.
#
# NOT a CI gate - it is a measuring instrument. It exits non-zero only when the
# harness itself could not run (invalid content, failed setup, stalled match),
# which means the numbers are not trustworthy. An unbalanced game is a finding,
# not a build failure.
#
#   scripts/balance.sh
#   scripts/balance.sh --credits=320,640 --map=crossing
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
exec "${GODOT}" --headless --path "${ROOT}" --script res://tests/run_balance.gd -- "$@"
