#!/usr/bin/env bash
# Build the Flutter web release. One command, no side effects beyond
# build/web. Base href defaults to "/" but the game does not assume it is
# hosted at the domain root — pass a path to test a sub-path deploy:
#
#   scripts/build_web.sh            # --base-href /
#   scripts/build_web.sh /tome/     # --base-href /tome/
#
set -euo pipefail
cd "$(dirname "$0")/.."

BASE_HREF="${1:-/}"

echo "==> flutter build web --release --base-href ${BASE_HREF}"
flutter build web --release --base-href "${BASE_HREF}"

echo "==> built build/web ($(find build/web -type f | wc -l | tr -d ' ') files, $(du -sh build/web | cut -f1))"
