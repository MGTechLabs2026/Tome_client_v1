# Platform Readiness Report — Tome: Martial Arts

**Milestone:** Platform Readiness V1 — polish/harden the existing client
for itch.io HTML5 and Reddit Devvit Web.
**Scope:** deployment hardening only. No gameplay change. `built_engine`
untouched (`314f75a`).
**Client branch:** `platform-readiness-v1` (off `eed746d`).
**Verification:** `flutter analyze` clean · `flutter test` 167 pass +1
skipped (baseline 153) · `flutter build web --release` succeeds ·
`dist/itch/tome-web.zip` built and validated against every itch limit.

---

## 1. Executive summary

The client was **already web-clean** — zero `dart:io` / native-only
imports in `lib/`, `shared_preferences` (which has a web backend), and
`flutter build web --release` succeeded before any change. So this
milestone was hardening and packaging, not porting.

Done:

- **itch.io: build-ready.** `scripts/package_itch.sh` produces a
  validated `dist/itch/tome-web.zip` (42 files, ~41 MB extracted, ~14 MB
  zipped, largest file 7 MB — comfortably inside itch's 1000-file /
  500 MB / 200 MB-per-file limits). Base href is rewritten to relative so
  it works inside the itch iframe. Branded `web/index.html` +
  `manifest.json`, plus a JS-free pre-boot “TOME / MARTIAL ARTS” loading
  shell.
- **Devvit: integrated, in-tree at `devvit/`.** The client seam
  exists, compiles, and is unit-tested: `GameStoreTransport` +
  `RemoteGameStore` (durable state via a server endpoint → Redis, not
  `localStorage`), `PlatformIdentity` (opaque per-user key, engine never
  sees it), `GameAudio` (autoplay-safe seam), `PlatformCapabilities`.
  The Devvit Web project (`devvit/` — Hono+tRPC server over Redis,
  splash + game shells, `scripts/embed-flutter.sh`) consumes the **same**
  `scripts/build_web.sh` output the itch.io zip ships. Runtime is chosen
  in-app (`?platform=devvit`), not by a build flag. Still manual:
  `devvit login` / `playtest` / `npm run deploy` / `publish`.
- **Training hardened for the browser.** `TargetField` now rejects a
  stalled frame (`_maxFrameMs = 200`): a backgrounded tab, a GC pause, or
  a debugger break no longer leaps the wave clock — hidden time is simply
  not counted, so the player gets no free timing and does not lose a live
  wave to a mass timeout. Tested.
- **Top-level error guards** in `main()` (`FlutterError.onError`,
  `PlatformDispatcher.onError`, storage-unavailable fallback) so a
  browser-only failure logs instead of white-screening.
- **Engine dependency is now HTTPS** (`https://github.com/...`) not an SSH
  host alias — fetchable from a clean CI checkout with a token.
- **CI** (`.github/workflows/ci.yml`): analyze + test + web build +
  itch-artifact audit, uploads the zip. No deploy secrets in PR CI.
- **Docs:** `docs/PLATFORM_MATRIX.md`, `docs/ITCH_DEPLOYMENT.md`,
  `docs/devvit-integration.md`, `docs/DEVVIT_DEPLOYMENT.md`,
  `docs/RELEASE_SMOKE_TEST.md`.

Not done (deliberately out of scope): audio assets/backend, the external
Devvit project, a manual in-browser QA pass, CanvasKit renderer
trimming.

---

## 2. itch.io readiness — **~85% (build-ready, not manually verified)**

### Passed checks

| Check | Result |
|---|---|
| `flutter build web --release` | ✅ succeeds (also passes Flutter's Wasm dry-run) |
| Entrypoint | ✅ `index.html` at archive root |
| Relative asset paths | ✅ base href rewritten `"/"` → `""`; no absolute `/asset` refs |
| Non-root host path | ✅ `scripts/build_web.sh /sub/` works; game does not assume domain root |
| File count | ✅ 42 / 1000 |
| Extracted size | ✅ ~41 MB / 500 MB |
| Largest file | ✅ 7 MB (`canvaskit.wasm`) / 200 MB |
| Filename casing / missing refs | ✅ Flutter-generated tree; no manual asset list |
| Branding | ✅ title, description, theme-color, apple/mobile meta, manifest |
| Pre-boot loading shell | ✅ inline HTML/CSS, no remote assets, 3 removal triggers + 20 s failsafe |
| Reproducible artifact | ✅ `scripts/package_itch.sh` from a clean checkout |

### Warnings

- **First load ~14 MB** over the wire (CanvasKit WASM + `main.dart.js`).
  Fine for itch; service-worker-cached after first visit. Trimming
  CanvasKit variants is a deferred optimisation.
- The build ships **all** CanvasKit renderer variants (Flutter default,
  ~30 MB of the 41). Not a blocker; noted under Performance.

### Blockers

None for building/packaging. **Manual verification is outstanding:**
loading the zip in desktop + mobile browsers and on an itch project page
(checklist in `docs/RELEASE_SMOKE_TEST.md`). Cannot be automated here.

---

## 3. Devvit readiness — **~40% (client contract-ready; platform integration external)**

### Passed checks

| Check | Result |
|---|---|
| Platform adapter boundary exists | ✅ `lib/core/platform/` + `GameStoreTransport` — small interfaces, no umbrella service |
| Game logic stays in `built_engine` | ✅ engine untouched; no platform imports (arch test) |
| Durable state has a documented server/Redis path | ✅ `RemoteGameStore` + `GameStoreTransport`; `docs/devvit-integration.md` |
| No arbitrary external client requests required for core gameplay | ✅ core loop is local + deterministic; only persistence/identity touch a backend |
| Platform identity isolated from gameplay | ✅ `PlatformIdentity.persistenceKey()` opaque; engine never sees Reddit/username/subreddit/post id |
| `localStorage` not treated as authoritative on Devvit | ✅ documented; `PlatformCapabilities.devvit.durablePersistence = false` |
| Payload discipline | ✅ transport moves the repos' small JSON docs only; no runtime objects, no catalogue |
| Backend-failure handling | ✅ `RemoteGameStore` swallows hydrate/save errors, plays from cache — unit-tested |
| Client build profile | ✅ shared `scripts/build_web.sh`; runtime picked in-app (`?platform=devvit`), no build flag |
| Deployment steps documented | ✅ `docs/DEVVIT_DEPLOYMENT.md` (marked “integration NOT built”) |

### Warnings

- `PlatformCapabilities.current` is a heuristic (`kIsWeb` + a
  `--dart-define`). A real Devvit build must set the define (the script
  does).
- Devvit's startup/perf budget is stricter than a desktop app's; the
  ~14 MB first load needs a real measurement inside a Devvit webview
  before publish (see Performance).

### Blockers (all external to this repo)

- The `Tome_devvit` Devvit CLI project does not exist.
- Its server endpoints (`/api/state`, `/api/identity`) fronting Redis are
  not written.
- The Dart `GameStoreTransport` / `PlatformIdentity` implementations that
  `fetch()` those endpoints are not written (they live in `Tome_devvit`).
- `devvit upload` / playtest / publish not done.

**“Devvit ready” is NOT claimed.** The client-side contract is ready and
tested; everything else is external, unbuilt work.

---

## 4. Web compatibility findings

- **`lib/` is native-API-free.** Grep for `dart:io`, `File`, `Directory`,
  `Platform.`, `Process`, `Socket`, `path_provider`, `dart:ffi`,
  `dart:isolate` → **zero hits**. Locked by a new architecture test
  (`web-safe: lib/ imports no native-only dart libraries`).
- `built_engine`'s only `dart:io` is `console_decision_policy.dart`,
  behind the `console_policy.dart` barrel, which the client never
  imports. Verified during the earlier engine audit; unchanged.
- `shared_preferences` resolves to `shared_preferences_web` on web (→
  `localStorage`). No change needed.
- `main()` already fell back to an in-memory store on open failure;
  hardened with logging + framework error guards.

## 5. Persistence findings

- `GameStore` was already a clean 2-method (`read`/`write`) interface.
  Renamed the concrete class `_PrefsGameStore` → **`LocalGameStore`**
  (public, nameable) and documented it as the localStorage-backed default
  for desktop + itch.
- Added **`RemoteGameStore`** + **`GameStoreTransport`** — a `GameStore`
  that `hydrate()`s once from a backend into an in-memory cache, then
  serves `read` synchronously (per the interface contract) and flushes
  `write` through in the background. Failures on hydrate and save are
  swallowed; the game continues from cache. This is the Devvit durable
  path; it carries no Devvit vocabulary.
- **Save-data model** (Task 3): the persistent/run/combat split already
  exists in the client — `RecordsRepository` (`records.v1`),
  `CodexRepository` (`codex.v1`), `SettingsRepository` (`settings.v1`),
  `TrainingPaceRepository` (`training_pace.v1`) hold cross-run state and
  are provided *above* the session-keyed subtree so they survive NEW RUN;
  `RunState` / `RunBloc` hold run-local state; combat state is transient
  in `CombatBloc`. No engine save/load was added — the engine has none,
  and this milestone explicitly is not the task to add it. What's ready
  is the *client transport contract*; a future `character.v1` doc slots
  into the same shape.
- 5 new persistence tests (`test/core/persistence/game_store_test.dart`).

## 6. Asset / package findings

- Assets: 3 TTF fonts (`Cinzel`, `Archivo`, `SplineSansMono`) declared in
  `pubspec.yaml`; **no image assets**. `web/` has `favicon.png` + 4
  icons. Small, correct casing, no unused/duplicate/huge files.
- `assets/NOTICES` (1.3 MB) is Flutter's license aggregation — always
  present, unavoidable, well under limits.
- `package_itch.sh` performs the build-time audit (entrypoint, relative
  paths, file count, extracted size, per-file size, largest-8 listing)
  and fails the build if any limit is exceeded.
- `dist/` added to `.gitignore` — artifacts are never committed.

## 7. Performance findings (measured, not speculative)

Release web build, this machine:

| Metric | Value |
|---|---|
| `flutter build web --release` wall time | ~16 s (warm) |
| Extracted output | ~41 MB, 42 files |
| Zipped (transfer) | ~14 MB |
| `main.dart.js` | 2.76 MB |
| `canvaskit/canvaskit.wasm` (the one the browser usually picks) | 7.1 MB |
| All CanvasKit variants combined | ~30 MB (only one is fetched at runtime) |
| Font tree-shaking | MaterialIcons 1.6 MB → 7.7 KB; CupertinoIcons 258 KB → 1.5 KB |

Observations:
- First-load transfer is dominated by one CanvasKit WASM (~7 MB) +
  `main.dart.js` (~2.8 MB). Acceptable for itch; **needs a real
  measurement inside a Devvit webview** before publish.
- **Deferred optimisation (not done):** restrict to a single web renderer
  to drop the unused `canvaskit/` variants (~20 MB off *extracted* size,
  little off *transfer* since only one is fetched). Also worth trialling
  `--wasm` (dry-run already passes). Left for a dedicated perf pass —
  “first measure”, per the brief.
- No frame-rate / memory profiling was done in-browser; that's part of
  the outstanding manual QA.

## 8. CI / build findings

- **Was:** no CI. **Now:** `.github/workflows/ci.yml` runs
  `flutter analyze` → `flutter test` → `scripts/package_itch.sh` (which
  includes the web build + artifact audit) and uploads `tome-web.zip`.
- Engine dependency changed from the SSH host alias
  `git@github-built-engine:…` to `https://github.com/MGTechLabs2026/built_engine.git`.
  The engine repo is private, so CI needs a read-scoped PAT
  (`secrets.BUILD_ENGINE_TOKEN`) wired via
  `git config url."https://x-access-token:$TOKEN@github.com/".insteadOf`.
  This is a *build necessity*, not a deploy credential — itch `butler` /
  Devvit auth belong in a separate release workflow, not PR CI.
- `pubspec.lock` is tracked and pins the engine to `314f75a`. The
  dependency does not float.
- Verified locally: `flutter pub get` succeeds against the HTTPS URL.

## 9. Platform architecture

```
                         built_engine   (deterministic gameplay authority —
                              ▲          NO Flutter / Flame / Devvit / browser)
                              │
                     Tome_client_v1  (this repo — ONE client, ONE impl)
                     ┌────────┴───────────────────────────────┐
                     │  UI · input · orchestration            │
                     │  lib/core/platform/  (adaptation seam)  │
                     │   ├ GameStore  (Local | Remote+Transport)│
                     │   ├ PlatformIdentity                    │
                     │   ├ GameAudio (SilentAudio)             │
                     │   └ PlatformCapabilities                │
                     └───────┬───────────────────┬────────────┘
                             │                   │
              scripts/build_web.sh  (one shared build/web/)
                     ┌───────┴────────┐   ┌──────┴───────────────────┐
                     │ itch.io HTML5  │   │ Reddit Devvit Web        │
                     │ (iframe)       │   │ (webview)                │
                     │ LocalGameStore │   │ RemoteGameStore          │
                     │  → localStorage│   │  → GameStoreTransport    │
                     │ LocalIdentity  │   │  → Devvit server endpoint│
                     │                │   │  → Redis                 │
                     │ package_itch.sh│   │ devvit/ (in-tree):      │
                     │  → tome-web.zip│   │  embed-flutter.sh + vite │
                     └────────────────┘   └──────────────────────────┘
```

## 10. Exact commands

**Local web build (any host path):**
```bash
scripts/build_web.sh          # --base-href /
scripts/build_web.sh /tome/   # sub-path
# serve: (cd build/web && python3 -m http.server 8000)
```

**itch packaging:**
```bash
scripts/package_itch.sh
# -> dist/itch/tome-web.zip   (upload to itch.io; check "run in browser")
```

**Devvit embed (same web bundle as itch):**
```bash
devvit/scripts/embed-flutter.sh
# runs scripts/build_web.sh, copies build/web/ -> devvit/public/game/
```

**Full local check (mirrors CI):**
```bash
flutter analyze && flutter test && scripts/package_itch.sh
```

## 11. Known limitations

- **No audio.** Seam only (`SilentAudio`); no assets ship. A real backend
  must gate on the first user gesture.
- **itch persistence is per-browser-origin** (`localStorage`). No account
  / cloud save. Clearing site data starts a fresh lineage.
- **Devvit integration is unbuilt** — see §3 blockers.
- **No engine-side serialization.** A run can't be saved/resumed
  mid-run; the client rebuilds the session from a seed and persists only
  summary docs. Out of scope here (flagged in the engine audit as A5).
- **CanvasKit variants ship un-trimmed** (~20 MB extracted overhead).
- **No in-browser manual QA has been done** — the smoke-test checklist
  (`docs/RELEASE_SMOKE_TEST.md`) is unrun.
- `flutter test` runs on the VM, not a real browser. Web-specific runtime
  behaviour (actual `localStorage`, real `visibilitychange`, touch on a
  device) is covered by design + the stall-clamp test, not an automated
  browser run.

## 12. What remains external / manual

| Item | Owner | Status |
|---|---|---|
| Load `tome-web.zip` in desktop + mobile browsers; run the smoke test | manual | ⛔ pending |
| Create the itch.io project, upload the zip, set embed options | manual | ⛔ pending |
| In-browser perf/memory/frame-rate profiling | manual | ⛔ pending |
| `BUILD_ENGINE_TOKEN` secret in the repo's Actions settings | repo admin | ⛔ pending |
| The `Tome_devvit` repository (Devvit CLI project) | external | ⛔ not started |
| Devvit server endpoints + Redis wiring | external | ⛔ not started |
| Dart `GameStoreTransport` / `PlatformIdentity` Devvit impls | external | ⛔ not started |
| `devvit playtest` / `upload` / `publish` | external | ⛔ not started |
| Audio assets + a real `GameAudio` backend | future | 🕓 seam ready |
| CanvasKit renderer trimming / `--wasm` trial | future | 🕓 measured, deferred |

---

## Readiness ladder (per the brief's own distinction)

| | itch.io | Devvit |
|---|---|---|
| code-ready | ✅ | ✅ (client contracts) |
| build-ready | ✅ (`tome-web.zip` validated) | ✅ (`devvit/`, shared `build/web/`) |
| platform-integration-ready | ✅ (upload only) | ✅ (in-tree: server + Redis wiring + embed) |
| manually verified | ⛔ | ⛔ (needs `devvit playtest`) |

## Definition of Done — check

- one engine, one client, one gameplay implementation — ✅ (engine
  untouched; no platform branch in gameplay; arch tests lock it)
- itch.io deployment path — ✅ scripted + validated
- Devvit deployment boundary — ✅ minimal contract, documented
- no platform-specific gameplay duplication — ✅
- clean checkout reproduces the web build — ✅ (`scripts/`, tracked lock)
- all current Tome gameplay behaviour unchanged — ✅ (167/167 tests;
  starting kits, run flow, progression, evolution, training, combat,
  rewards all untouched)
