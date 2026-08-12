#!/usr/bin/env bash
# Rebuild every .glb from the scripts in art/. No Blender window needed.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLENDER="${BLENDER:-blender}"

if ! command -v "${BLENDER}" >/dev/null 2>&1; then
  echo "Blender not found. Set BLENDER to the executable path."
  exit 1
fi

OUTPUT="$("${BLENDER}" -b --python "${ROOT}/art/build_all.py" 2>&1)"
echo "${OUTPUT}"

if echo "${OUTPUT}" | grep -q "\[FAIL\]"; then
  echo ""
  echo "Art build failed."
  exit 1
fi

echo ""
echo "Art build complete."
