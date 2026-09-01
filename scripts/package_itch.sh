#!/usr/bin/env bash
# Reproducible itch.io HTML5 release artifact.
#
#   1. scripts/build_web.sh  — the shared Flutter web release (same
#      build/web/ the Devvit embed uses; <base href> already rewritten
#      to "" so assets resolve relative to index.html — itch runs the
#      upload in an iframe from a hashed path, never the domain root)
#   2. validate: entrypoint present, no absolute /asset paths, and the
#      itch extracted-archive limits (<=1000 files, <=500 MB total,
#      <=200 MB per file)
#   3. zip -> dist/itch/tome-web.zip  (index.html at the archive root)
#
# The artifact is NOT committed (dist/ is gitignored).
set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="dist/itch"
ZIP="${OUT_DIR}/tome-web.zip"
SRC="build/web"

# itch.io extracted-archive limits.
MAX_FILES=1000
MAX_TOTAL_BYTES=$((500 * 1024 * 1024))
MAX_FILE_BYTES=$((200 * 1024 * 1024))

echo "==> clean"
rm -rf "${SRC}" "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

echo "==> build (shared web release)"
scripts/build_web.sh

fail=0
note() { echo "    - $1"; }
bad()  { echo " !! $1"; fail=1; }

echo "==> validate"

[ -f "${SRC}/index.html" ] && note "index.html present" || bad "index.html missing"

if grep -Eq '(src|href)="/[a-zA-Z]' "${SRC}/index.html"; then
  bad "index.html has an absolute /... path (breaks inside the itch iframe)"
else
  note "index.html uses relative paths"
fi

FILE_COUNT=$(find "${SRC}" -type f | wc -l | tr -d ' ')
if [ "${FILE_COUNT}" -gt "${MAX_FILES}" ]; then
  bad "file count ${FILE_COUNT} > ${MAX_FILES}"
else
  note "file count ${FILE_COUNT} / ${MAX_FILES}"
fi

# du -k is portable (macOS + GNU); convert KiB -> bytes.
TOTAL_BYTES=$(( $(du -sk "${SRC}" | cut -f1) * 1024 ))
if [ "${TOTAL_BYTES}" -gt "${MAX_TOTAL_BYTES}" ]; then
  bad "extracted size $((TOTAL_BYTES / 1024 / 1024)) MB > 500 MB"
else
  note "extracted size $((TOTAL_BYTES / 1024 / 1024)) MB / 500 MB"
fi

# -exec ... \;  runs wc once per file — no aggregate "total" line.
LARGEST_BYTES=$(find "${SRC}" -type f -exec wc -c {} \; | sort -rn | head -1 | awk '{print $1}')
if [ "${LARGEST_BYTES:-0}" -gt "${MAX_FILE_BYTES}" ]; then
  bad "largest file $((LARGEST_BYTES / 1024 / 1024)) MB > 200 MB"
else
  note "largest file $((LARGEST_BYTES / 1024 / 1024)) MB / 200 MB"
fi

echo "==> largest 8 files"
find "${SRC}" -type f -exec wc -c {} \; \
  | sort -rn | head -8 \
  | awk '{printf "    %8.1f KB  %s\n", $1/1024, $2}'

if [ "${fail}" -ne 0 ]; then
  echo "==> FAILED — not packaging"
  exit 1
fi

echo "==> zip"
( cd "${SRC}" && zip -qr -X "../../${ZIP}" . )
echo "==> ${ZIP} ($(du -h "${ZIP}" | cut -f1)) — ready to upload to itch.io"
