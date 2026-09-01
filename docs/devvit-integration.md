# Devvit Web integration — architecture & client contracts

This is the **boundary design**. The Flutter Web output is *not*
automatically a Devvit app; a separate Devvit project supplies the
config, the server endpoints and the Redis wiring. This document defines
exactly what that project has to implement and what stays in this client.

Ops steps live in `DEVVIT_DEPLOYMENT.md`.

## Architecture

```
Reddit post
   │
   ▼
Devvit Web app  ─────────────────────────────────────────────┐
   │  webview (iframe)                                        │
   ▼                                                          │
Flutter Web client  (this repo — the SAME build/web/ that    │
 ships to itch.io, embedded by devvit/scripts/embed-flutter) │
   │                                                          │
   ├─ gameplay ──────────► built_engine   (deterministic,     │
   │                       platform-free — UNCHANGED)         │
   │                                                          │
   ├─ persistence ───────► GameStoreTransport ────────────────┤ Devvit server
   │                        (loadAll / save)                  │   endpoint
   │                                                          │     │
   └─ identity ──────────► PlatformIdentity ──────────────────┘     ▼
                            (persistenceKey)                      Redis
```

- **`built_engine` gains nothing.** No Devvit, Reddit, browser, or
  itch vocabulary enters the engine. Combat, training, evolution, reward
  and progression are the same code paths as desktop.
- **The Devvit server does no gameplay.** It provides identity,
  persistence (Redis), platform integration, and optionally telemetry.
  It never runs combat / training / reward / evolution logic — those must
  stay reproducible locally.

## Client contracts the Devvit project implements

All three already exist in this repo; the Devvit project provides the
implementations and passes them in at startup.

### 1. `GameStoreTransport` — `lib/core/persistence/game_store.dart`

```dart
abstract interface class GameStoreTransport {
  Future<Map<String, Map<String, Object?>>> loadAll();
  Future<void> save(String key, Map<String, Object?> value);
}
```

The Devvit implementation calls the Devvit **server endpoint** (the only
network the webview may reach), which reads/writes Redis keyed by the
player id. Used via `RemoteGameStore(transport)..hydrate()` — `hydrate()`
is awaited once at startup, then `read` is synchronous from cache and
`write` flushes through in the background. Hydrate / save failures are
swallowed; the game continues from cache.

Document keys are the repositories' own: `records.v1`, `codex.v1`,
`settings.v1`, `training_pace.v1` (+ future `character.v1` etc.).

### 2. `PlatformIdentity` — `lib/core/platform/platform_identity.dart`

```dart
abstract interface class PlatformIdentity {
  Future<String> persistenceKey();
}
```

The Devvit implementation returns a **stable, opaque** per-user key
resolved server-side (never a username, never PII). The repositories
scope their storage keys by it; nothing else changes. `built_engine`
never sees it.

### 3. `GameAudio` — `lib/core/platform/game_audio.dart`

Optional. `SilentAudio` is the default (no assets ship). A real backend
must not play anything before the first user gesture (`unlock()`).

## Payload discipline (Task 16)

- Send **compact ids + the repositories' small docs** — never runtime
  objects, never the content catalogue, never full game histories.
- Devvit Web has bounded request/response sizes and execution time.
  `loadAll` is one call at startup; `save` is per-document and should be
  debounced/coalesced by the transport if the server has a write budget.
- The client never serialises implementation classes — every doc is a
  plain `Map<String, Object?>` of JSON scalars/lists.

## localStorage warning (Task 15)

On Devvit, `localStorage` can be lost on app update (the iframe URL
changes). It may back only throwaway UI state (last tab, a collapsed
panel). **Character / lineage / mastery / run state must use the server
path above.**

## Where this lives

- The Devvit project is in-tree at **`devvit/`** (Devvit config,
  `src/server/` Hono+tRPC endpoints over Redis, `src/client/` splash +
  game shells, `scripts/embed-flutter.sh`).
- The Dart implementations of the contracts are
  `lib/core/platform/devvit_backend.dart` (`DevvitGameStoreTransport`,
  `DevvitIdentity`), wired into `RemoteGameStore` in `lib/main.dart`.
- Still manual: `devvit login`, `devvit playtest`, `npm run deploy`
  (`devvit upload`), `devvit publish` — see `DEVVIT_DEPLOYMENT.md`.
- Contracts are unit-tested here (`test/core/persistence/game_store_test.dart`,
  `test/core/platform/platform_test.dart`) and in `devvit/` (`vitest`).
