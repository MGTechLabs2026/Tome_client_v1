# Devvit deployment — Tome: Martial Arts

Architecture and client contracts: **`devvit-integration.md`**. This file
is the ops checklist. The Devvit Web project now lives **in this repo** at
`devvit/` (Devvit config, Hono/tRPC server, Redis wiring, the splash +
game shells).

## Build & embed the client bundle

```bash
devvit/scripts/embed-flutter.sh
```

It runs the **shared** `scripts/build_web.sh` (the same `build/web/` the
itch.io zip is made from — `flutter build web --release
--no-web-resources-cdn --base-href /`, then `<base href>` rewritten to
`""`) and copies it verbatim into `devvit/public/game/` (gitignored,
regenerated). `vite build` then lifts `public/` into `dist/client/`.

There is **no** Devvit-specific build flag. The runtime is chosen in-app:
`devvit/src/client/game.html` loads `game/index.html?platform=devvit`, and
`PlatformCapabilities.current` reads that (or a `*.devvit.net` host) to
report server-backed persistence, platform identity, no external network.

## The Devvit project — `devvit/`

Devvit CLI project (Web template). It provides:

1. **`devvit.yaml` / config** — app name, permissions (Redis).
2. **Server** (`src/server/`) — endpoints backed by Redis:
   - `GET  /api/state`   → `{ "records.v1": {…}, "codex.v1": {…}, … }`  (feeds `GameStoreTransport.loadAll`)
   - `POST /api/state`   → `{ key, value }`, writes one Redis hash field  (feeds `GameStoreTransport.save`)
   - `GET  /api/identity` → `{ key: "<stable opaque user id>" }`  (feeds `PlatformIdentity.persistenceKey`)
   Redis keys are scoped by the resolved user id. Keep responses small.
3. **Client webroot** — `devvit/public/game/` (the shared `build/web/`
   bundle from `embed-flutter.sh`), served behind `game.html`. The Dart
   `DevvitGameStoreTransport` + `DevvitIdentity` (`lib/core/platform/
   devvit_backend.dart`) `fetch()` the endpoints above and are wired into
   `RemoteGameStore` at startup in `lib/main.dart`.
4. **No gameplay on the server.** It is identity + persistence +
   platform integration only (Task 33).

## Environment requirements

- Devvit CLI + a Reddit developer account, a test subreddit.
- Redis enabled for the app (Devvit-managed).
- `devvit playtest <subreddit>` for iteration; `devvit upload` +
  `devvit publish` for release.

### Devvit MCP server (Claude Code assist)

`.mcp.json` in this repo registers Reddit's official Devvit MCP server
(`@devvit/mcp`, telemetry off) so Claude Code can pull current Devvit
docs / API guidance while the `Tome_devvit` project is built. Approve it
on the next Claude Code start (project-scoped MCP servers require
consent). It provides documentation/tooling only — it does not deploy.

The version is **pinned** (`@devvit/mcp@0.0.27`) — `npx` still fetches
from the registry, but a pin means an upgrade is a deliberate, reviewed
edit, not silent code execution on every launch. Bump it the same way
the `build_engine` ref is bumped: change the version, verify, commit.

## Known platform constraints (design around these)

| Constraint | Consequence for Tome |
|---|---|
| `localStorage` can vanish on app update | lineage state MUST use the server/Redis path; `localStorage` only for throwaway UI state |
| Webview cannot make arbitrary external requests | the client talks only to the Devvit server endpoint; no third-party calls in core gameplay |
| Bounded request/response size + execution time | compact ids + small docs only; `loadAll` once at startup; debounce `save` |
| Webview is embedded, not fullscreen | layout is responsive to the available box; no `viewport == display` assumptions |
| Stricter startup/perf budget than a desktop app | first load is ~14 MB (CanvasKit + `main.dart.js`); measure before optimising — see `PLATFORM_READINESS_REPORT.md` §Performance |
| Player identity is Reddit-scoped | `PlatformIdentity` returns an opaque key; `built_engine` never sees Reddit/username/subreddit/post id |

## Testing (once the Devvit project exists)

- `devvit playtest`: game loads in the post; New Game → kit → Tome →
  train → fight → reward → Tome → New Run.
- Kill the server / return an error from `/api/state`: game still boots
  from an empty cache, writes retry, no crash (`RemoteGameStore`
  swallows failures — covered by `game_store_test.dart`).
- Update the app (bump version, re-upload): saved lineage is still there
  (proves it's in Redis, not `localStorage`).
- Two different Reddit users in the same post get separate lineages.

## What remains manual / external

Everything under "The external `Tome_devvit` project" above. This repo's
job for this milestone is done: the contracts exist, compile, and are
unit-tested; the client build profile is scripted.
