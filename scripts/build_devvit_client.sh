#!/usr/bin/env bash
# Build the Flutter web client for embedding in a Reddit Devvit Web app.
#
# This produces ONLY the game client bundle. It is not a complete Devvit
# app — the Devvit project (config, server endpoints, Redis wiring) lives
# separately; see docs/devvit-integration.md. That project copies the
# contents of dist/devvit-client/ into its webroot.
#
# Differences from the itch build:
#   * --dart-define TOME_PLATFORM=devvit   (PlatformCapabilities.current
#     then reports the Devvit constraints: no durable localStorage, no
#     free outbound network, platform identity available)
#
# Base href is left as "/" here; the Devvit project's embed step
# (tome-martial-arts/scripts/embed-flutter.sh) rewrites it to "" so every
# asset resolves relative to game/index.html inside the webview.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="dist/devvit-client"

echo "==> clean"
rm -rf build/web "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

echo "==> build (Devvit profile)"
flutter build web --release \
  --base-href / \
  --dart-define=TOME_PLATFORM=devvit

cp -R build/web/. "${OUT_DIR}/"
echo "==> ${OUT_DIR}/ ($(find "${OUT_DIR}" -type f | wc -l | tr -d ' ') files, $(du -sh "${OUT_DIR}" | cut -f1))"
echo "==> next: tome-martial-arts/scripts/embed-flutter.sh copies this into"
echo "    the Devvit project. See docs/devvit-integration.md."
