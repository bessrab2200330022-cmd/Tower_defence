#!/usr/bin/env bash
# Codex sandbox bootstrap: install Godot headless and warm the import cache.
#
# Point your Codex environment's "setup script" at this file. It is idempotent,
# so re-running it on a warm container is cheap.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7}"
GODOT_RELEASE="${GODOT_RELEASE:-stable}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
ARCHIVE="Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.x86_64.zip"
URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/${ARCHIVE}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v godot >/dev/null 2>&1; then
  echo "godot already present: $(godot --version 2>/dev/null | head -n1)"
else
  echo "Installing Godot ${GODOT_VERSION}-${GODOT_RELEASE}..."
  # Godot headless still links against X/GL libraries on Linux.
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y --no-install-recommends \
      unzip ca-certificates curl \
      libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1 libasound2 \
      >/dev/null
  fi

  TMP_DIR="$(mktemp -d)"
  curl -fsSL -o "${TMP_DIR}/${ARCHIVE}" "${URL}"
  unzip -q -o "${TMP_DIR}/${ARCHIVE}" -d "${TMP_DIR}"
  install -m 0755 "${TMP_DIR}/Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.x86_64" "${INSTALL_DIR}/godot"
  rm -rf "${TMP_DIR}"
  echo "Installed: $(godot --version 2>/dev/null | head -n1)"
fi

echo "Warming the import cache..."
# The first import always reports a non-zero exit on some Godot builds even when
# it succeeds, so this step is intentionally non-fatal.
godot --headless --path "${REPO_ROOT}" --import >/dev/null 2>&1 || true

echo "Running the test suite to verify the environment..."
godot --headless --path "${REPO_ROOT}" --script res://tests/run_tests.gd

echo "Setup complete."
