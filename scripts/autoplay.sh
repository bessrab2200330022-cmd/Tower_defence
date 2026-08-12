#!/usr/bin/env bash
# Play a whole match headless through the real Level and Hud.
#
# The unit suite never builds a view, and smoke.sh only boots the menu-less
# game and idles - nothing starts a wave without a keypress. This is the step
# that actually executes game/views/*.gd and checks that view nodes stay in
# step with the simulation.
#
# The exit code is not the whole gate. AGENTS.md 5.2 requires no `ERROR:` lines
# either, and the runner cannot enforce that itself: engine errors are printed
# by Godot, not raised into GDScript, so a run can report PASS and exit 0 while
# emitting dozens of them. It did exactly that for a while - 48 per match from a
# look_at() on a zero-length vector - and CI stayed green throughout, because
# only smoke.sh grepped and smoke.sh never fires a projectile.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"

OUTPUT="$("${GODOT}" --headless --path "${ROOT}" --script res://tests/run_autoplay.gd 2>&1)"
STATUS=$?

echo "${OUTPUT}"

if echo "${OUTPUT}" | grep -Eq "(SCRIPT ERROR|ERROR:|Parse Error)"; then
  echo ""
  echo "FAIL: the autoplay run reported engine errors."
  exit 1
fi

if [ "${STATUS}" -ne 0 ]; then
  echo ""
  echo "FAIL: godot exited with status ${STATUS}."
  exit "${STATUS}"
fi

echo ""
echo "PASS: autoplay completed with no engine errors."
