#!/usr/bin/env bash
# Export a release build.
#
#   scripts/export.sh "Windows Desktop" build/BastionLine.exe
#   scripts/export.sh "Linux/X11"       build/BastionLine.x86_64
#
# Requires the matching export templates to be installed for your Godot version:
#   https://godotengine.org/download  ->  Export Templates
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
PRESET="${1:-Windows Desktop}"
OUTPUT="${2:-build/BastionLine.exe}"

mkdir -p "$(dirname "${ROOT}/${OUTPUT}")"
"${GODOT}" --headless --path "${ROOT}" --export-release "${PRESET}" "${ROOT}/${OUTPUT}"
echo "Exported ${PRESET} -> ${OUTPUT}"
