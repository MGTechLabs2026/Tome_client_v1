#!/usr/bin/env bash
# Put the Flutter game bundle into this Devvit app's media dir.
#
#   Tome_client/scripts/build_web.sh   ->  Tome_client/build/web/
#        (the SAME release the itch.io package zips — one shared build)
#   copied verbatim  ->  devvit/public/game/
#   vite build then copies  public/  ->  dist/client/game/
#   Devvit serves  dist/client/game.html  (iframe shell)  -> game/index.html
#
# The web bundle is byte-identical to the itch.io upload. The Devvit
# runtime is selected in-app: game.html loads game/index.html?platform=devvit
# (PlatformCapabilities.current reads that, or the *.devvit.net host).
#
# public/game/ is generated — gitignored, rebuilt by this script.
set -euo pipefail
cd "$(dirname "$0")/.."                 # -> Tome_client/devvit

CLIENT="${TOME_CLIENT_DIR:-..}"         # -> Tome_client (parent)
DEST="public/game"

if [ ! -x "${CLIENT}/scripts/build_web.sh" ]; then
  echo "!! ${CLIENT}/scripts/build_web.sh not found (set TOME_CLIENT_DIR)"; exit 1
fi

echo "==> build shared Flutter web release"
( cd "${CLIENT}" && scripts/build_web.sh )

echo "==> copy build/web -> ${DEST}"
rm -rf "${DEST}"
mkdir -p "${DEST}"
cp -R "${CLIENT}/build/web/." "${DEST}/"

echo "==> ${DEST}/ ($(find "${DEST}" -type f | wc -l | tr -d ' ') files, $(du -sh "${DEST}" | cut -f1))"
echo "==> now: vite build  (or the running \`npm run dev\` picks it up)"
