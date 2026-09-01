# itch.io HTML5 deployment — Tome: Martial Arts

## Build command

```bash
scripts/package_itch.sh
```

What it does:

1. `rm -rf build/web dist/itch`
2. `scripts/build_web.sh` — the **shared** Flutter web release (the same
   `build/web/` the Devvit embed copies, so the two ship byte-identical):
   `flutter build web --release --no-web-resources-cdn --base-href /`,
   then rewrites `<base href="/">` → `<base href="">` in
   `build/web/index.html` so every asset URL resolves **relative to
   `index.html`** — itch serves the upload from an iframe at a hashed
   path, never the domain root. (Flutter's own `--base-href` must start
   *and* end with `/`, so this is a post-build edit, not a flag.)
3. validates the entrypoint, relative paths, and the itch extracted-archive
   limits.
4. zips `build/web/` → `dist/itch/tome-web.zip` with `index.html` at the
   archive root.

There is no itch-specific build flag. `PlatformCapabilities.current`
resolves the runtime in-app (itch gets plain `web`; the Devvit shell adds
`?platform=devvit`), so one bundle serves both.

To test a non-root sub-path deploy locally: `scripts/build_web.sh /tome/`.

## Artifact

```
dist/itch/tome-web.zip
```

Not committed (`dist/` is gitignored). Regenerate from a clean checkout
with the command above.

### Measured (this build)

| Metric | Value | itch limit |
|---|---|---|
| Files (extracted) | 43 | ≤ 1000 |
| Extracted size | ~41 MB | ≤ 500 MB |
| Largest file (`canvaskit/canvaskit.wasm`) | ~7 MB | ≤ 200 MB per file |
| ZIP (upload) size | ~14 MB | — |

CanvasKit is now bundled (`--no-web-resources-cdn`), not fetched from
`www.gstatic.com` — one less third-party dependency, and the same bytes
the Devvit webview needs.

### ZIP structure

```
tome-web.zip
├── index.html              <-- entry point (itch "This file will be run…")
├── flutter_bootstrap.js
├── main.dart.js
├── flutter_service_worker.js
├── manifest.json
├── favicon.png
├── version.json
├── assets/                 (fonts: Cinzel, Archivo, SplineSansMono; NOTICES)
├── canvaskit/              (WASM renderer variants — browser picks one)
└── icons/
```

## Upload settings (itch.io project page → Edit game)

- **Kind of project:** HTML
- Upload `tome-web.zip`, then check **“This file will be run in the
  browser.”**
- **Embed options:** set a fixed viewport (e.g. 960 × 640) or check
  **“Fullscreen button”** and **“Mobile friendly”** (orientation: default).
  The game is responsive to whatever box it gets.
- **Frame options:** leave “Automatically start on page load” per taste;
  the game shows its own pre-boot loading shell.

## Testing checklist

Desktop browser (Chrome, Firefox, Safari):
- loads to the title screen; pre-boot “TOME / MARTIAL ARTS” shell appears
  then clears
- New Game → character creation → **style-specific starting kit** on the
  Tome (Polearming → Cloth + Polearm, Wrestling → Chair + Mask, …)
- Training: click targets; result screen; a surprise evolution when it
  happens
- Fight → reward → next fight → hard fight → final reward → back to Tome
- New Run: character/records persist; run-local state resets
- Resize the window mid-run; refresh mid-run (records survive)

Mobile browser (iOS Safari, Android Chrome):
- same flow with **taps** instead of clicks
- training target field hit-tests correctly at small sizes
- no horizontal scroll; dialogs fit; text legible

Tab lifecycle:
- start a training wave, switch tabs for ~30 s, return — the wave is
  still live (not mass-timed-out), timing not advanced by hidden time

## Known limitations

- **First load downloads ~14 MB** (CanvasKit WASM + `main.dart.js`).
  Acceptable for itch; cached by the service worker after first visit.
- **No audio** — the seam exists (`SilentAudio`), no assets ship.
- **Persistence is per-browser-origin** (`localStorage`). Clearing site
  data / using a different browser starts a fresh lineage. This is fine
  for itch single-player MVP; a cloud/account save is future work.
- The build ships **all** CanvasKit renderer variants (Flutter default).
  Trimming to one is a size optimisation deferred to a later pass — see
  `PLATFORM_READINESS_REPORT.md` §Performance.

## What remains manual

- Creating the itch.io project and uploading the ZIP.
- (Optional) automated deploy via `butler` in a separate release workflow
  with an itch API key secret — **not** wired into PR CI.
