#!/usr/bin/env bash
# Build the .godot/ import cache. Run once after a fresh clone.
# Some Godot builds exit non-zero on a first import even when it succeeded,
# so the failure is swallowed deliberately.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
"${GODOT}" --headless --path "${ROOT}" --import || true
echo "Import cache built."
