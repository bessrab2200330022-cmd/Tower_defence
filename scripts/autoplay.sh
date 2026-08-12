#!/usr/bin/env bash
# Play a whole match headless through the real Level and Hud.
#
# The unit suite never builds a view, and smoke.sh only boots the menu-less
# game and idles - nothing starts a wave without a keypress. This is the step
# that actually executes game/views/*.gd and checks that view nodes stay in
# step with the simulation. Exit code is the gate.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
exec "${GODOT}" --headless --path "${ROOT}" --script res://tests/run_autoplay.gd
