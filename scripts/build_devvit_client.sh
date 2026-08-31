#!/usr/bin/env bash
# Build the Flutter web client for embedding in a Reddit Devvit Web app.
#
# This produces ONLY the game client bundle. It is not a complete Devvit
# app — the Devvit project (config, server endpoints, Redis wiring) lives
# separately; see docs/devvit-integration.md. That project copies the
# contents of dist/devvit-client/ into its webroot.
#
# Differences from the itch build:
#   * --base-href ./            (Devvit serves the webview from a path)
#   * --dart-define TOME_PLATFORM=devvit   (PlatformCapabilities.current
#     then reports the Devvit constraints: no durable localStorage, no
#     free outbound network, platform identity available)
#
set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="dist/devvit-client"

echo "==> clean"
rm -rf build/web "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

echo "==> build (Devvit profile)"
flutter build web --release \
  --base-href ./ \
  --dart-define=TOME_PLATFORM=devvit

cp -R build/web/. "${OUT_DIR}/"
echo "==> ${OUT_DIR}/ ($(find "${OUT_DIR}" -type f | wc -l | tr -d ' ') files, $(du -sh "${OUT_DIR}" | cut -f1))"
echo "==> next: copy into the Devvit project webroot; wire GameStoreTransport"
echo "    to the Devvit server endpoint. See docs/devvit-integration.md."
