#!/usr/bin/env bash
# Run the headless test suite. Exit code is the gate.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
exec "${GODOT}" --headless --path "${ROOT}" --script res://tests/run_tests.gd
