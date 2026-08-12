#!/usr/bin/env bash
# Boot the real game headless and fail on any engine error.
# Catches the class of bug unit tests miss: bad scene wiring, null nodes,
# resources that load in isolation but not together.
#
# FRAMES, not simulation ticks: --quit-after counts main-loop iterations,
# and headless runs unthrottled, so 600 frames is only ~180 ticks of game
# time. Nothing starts a wave here either - see autoplay.sh for a run that
# actually plays the game.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
FRAMES="${FRAMES:-${TICKS:-600}}"

OUTPUT="$("${GODOT}" --headless --path "${ROOT}" --quit-after "${FRAMES}" 2>&1)"
STATUS=$?

echo "${OUTPUT}"

if echo "${OUTPUT}" | grep -Eq "(SCRIPT ERROR|ERROR:|Parse Error)"; then
  echo ""
  echo "FAIL: the headless run reported engine errors."
  exit 1
fi

if [ "${STATUS}" -ne 0 ]; then
  echo ""
  echo "FAIL: godot exited with status ${STATUS}."
  exit "${STATUS}"
fi

echo ""
echo "PASS: clean headless run over ${FRAMES} frames."
