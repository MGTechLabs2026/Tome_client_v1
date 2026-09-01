#!/usr/bin/env bash
# The one Flutter web release build. BOTH deploy targets consume this
# same build/web/ output, so they ship byte-identical:
#
#   scripts/package_itch.sh        zips build/web/  -> dist/itch/tome-web.zip
#   devvit/scripts/embed-flutter.sh  copies build/web/ -> devvit/public/game/
#
# There is no per-platform build flag. The runtime is chosen in-app by
# PlatformCapabilities.current (a ?platform=devvit query param that the
# Devvit shell adds, or a *.devvit.net host), so one bundle serves the
# itch.io tab and the Reddit webview alike.
#
#   scripts/build_web.sh            # --base-href / , then rewritten to ""
#   scripts/build_web.sh /tome/     # literal --base-href /tome/ (sub-path test)
#
set -euo pipefail
cd "$(dirname "$0")/.."

BASE_HREF="${1:-/}"

# --no-web-resources-cdn bundles CanvasKit + engine resources into the
# build instead of fetching them from www.gstatic.com at runtime. Devvit's
# webview CSP blocks every external origin (a CDN-loading build hangs on
# the shell); on itch it just removes a third-party dependency. Either
# way, one build that works everywhere.
echo "==> flutter build web --release --no-web-resources-cdn --base-href ${BASE_HREF}"
flutter build web --release --no-web-resources-cdn --base-href "${BASE_HREF}"

if [ "${BASE_HREF}" = "/" ]; then
  # Every target serves the bundle from a sub-path (itch iframe hash path,
  # Devvit webview path), never the domain root — resolve assets relative
  # to index.html. Flutter's --base-href must itself start and end with
  # "/", so this is a post-build edit, not a flag.
  sed -i.bak 's#<base href="/">#<base href="">#' build/web/index.html
  rm -f build/web/index.html.bak
  echo "==> rewrote <base href> to \"\" (assets resolve relative to index.html)"
fi

echo "==> built build/web ($(find build/web -type f | wc -l | tr -d ' ') files, $(du -sh build/web | cut -f1))"
