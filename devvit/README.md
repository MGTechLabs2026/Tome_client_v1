# Tome: Martial Arts — Reddit app

A playable martial-arts roguelike that runs **inside a Reddit post**. Readers
open the post, press **Enter the Hall**, and the full game opens in place: build
a grid-based loadout (your "Tome"), train your techniques, watch an auto-resolved
fight play out, pick your loot, and push your lineage through a three-fight run.

This repository is the **Devvit app** — the Reddit wrapper. The game itself is a
Flutter web build that also ships to itch.io; here it is embedded unchanged, with
a small Reddit server added around it for saving progress.

---

## Overview

**What it is.** "Tome: Martial Arts" is a build-and-discovery roguelike. The
skill is not fast reflexes in a fight — it is assembling and evolving your Tome
(a 3×3 grid of items and techniques), finding synergies between martial styles,
item combines, and technique evolutions, and seeing a stronger build survive
progressively harder fights. Combat is watched, not driven: the outcome is
computed, then replayed at a readable pace.

**Where it runs.** Entirely within a Reddit post, in the post's embedded webview.
The post shows a small splash in the feed ("Tome / Martial Arts — a
build-and-discovery roguelike… Enter the Hall"); pressing the button expands the
post to the full game.

**Who it is for.**

- **Reddit members** who want a short, self-contained strategy game they can play
  without leaving the feed. No install, no account beyond their normal Reddit
  login. A full run is roughly 10–20 minutes.
- **Subreddit moderators** who want to host the game in their community. Once the
  app is installed, a moderator-only menu item creates a game post, and the app
  also creates one automatically on install.

**How progress is saved.** Each Reddit user gets their own save, stored
server-side in Redis and tied to an opaque per-user key (never a username, never
personal data). Four small documents are kept: run records, the discovery codex,
settings, and training pace. Because it is stored on the server and not in the
browser, progress survives app updates. Logged-out viewers can still play, but
share a single temporary slot that is not guaranteed to persist.

**Critical operational notes.**

- **The server runs no gameplay.** It only provides identity and save/load.
  All rules — combat, training, rewards, technique evolution — run in the
  client's deterministic engine. This keeps runs reproducible and keeps the
  server simple.
- **No external network.** The embedded game talks only to this app's own
  server endpoints. It makes no third-party calls.
- **Browser storage is not trusted.** On Devvit the webview URL can change on an
  app update, wiping `localStorage`. Anything that matters (records, codex,
  settings) goes through the server path; `localStorage` is used only for
  throwaway UI state such as the last-open tab.
- **First load is heavy.** The game is a Flutter/CanvasKit bundle of roughly
  14 MB (engine + renderer). It loads once, then caches. Expect a visible load
  on first open, especially on slow connections.
- **The embedded bundle is identical to the itch.io release.** The runtime is
  selected at load time by a `?platform=devvit` marker on the game URL, which
  tells the game to use server-backed saving and Reddit identity.
- **Permissions requested:** acting as the viewing user for `SUBMIT_POST`,
  `SUBMIT_COMMENT`, and `SUBSCRIBE_TO_SUBREDDIT`, plus Redis (managed by
  Devvit). These back post creation and per-user save storage.

---

## How it works

```
Reddit post
   │  embedded webview (iframe)
   ▼
Devvit app (this repo)
   │
   ├─ splash.html   small React view shown in the feed ("Enter the Hall")
   ├─ game.html     iframe shell that loads the Flutter game bundle
   │                   from public/game/index.html?platform=devvit
   │
   └─ server (Hono)
        ├─ GET  /api/state     → every saved document for this user
        ├─ POST /api/state     → save one whitelisted document
        ├─ GET  /api/identity  → this user's opaque save key
        └─ internal menu / install-trigger endpoints (create a post)
```

The Flutter game and its rules engine gain nothing Reddit-specific. The Devvit
server is identity plus persistence only.

---

## Playing the game

1. **Open the post.** In the feed you see the splash: the title, a one-line
   description, and an **Enter the Hall** button.
2. **Enter the Hall.** The post expands and the game loads (first load is the
   slow one).
3. **Create your character.** You are assigned a physique; you choose a martial
   style. Whether your style matches your physique's tradition is a real combat
   modifier, not flavour.
4. **Build your Tome.** Place items and techniques on the 3×3 grid. Items have
   real states — locked, usable, mastered, active — and matching items can be
   **combined** into a stronger single item. Techniques can be **learned** and
   then **evolved**. Relationships stay visible even when an option is currently
   unavailable.
5. **Train.** Run a training session across five dimensions (timing, precision,
   reaction, power, combo). Results feed back into your techniques.
6. **Fight.** The fight is resolved automatically, then replayed at a readable
   pace. You watch; you do not input moves.
7. **Take loot.** You are offered real, fully identified rewards — an unlocked
   slot, an item or technique, or upgrade points. No blind boxes. Pick one.
8. **Repeat** through a three-fight run, editing your Tome between fights. At
   **Run Complete** you can start a new run.

Your records and discoveries carry across runs. Reduced-motion and text-scaling
settings are respected.

---

## Moderator tools

- **Menu item — "Create a new post":** subreddit menu, moderators only. Creates
  a fresh game post in the community.
- **On install:** the app automatically creates one game post in the subreddit
  it is installed to.

---

## Configure & deploy

This is a [Devvit](https://developers.reddit.com/) app. Deploying it is a
developer task run from a terminal.

### Prerequisites

- **Node.js 24** (see `.nvmrc` → `24.18.0`). `nvm use` if you use nvm.
- A **Reddit account** connected to Reddit's developer platform, and a **test
  subreddit** you moderate.
- The **Devvit CLI** (installed as a dependency here; `npx devvit …` works).
- To rebuild the embedded game: a checkout of the parent **`Tome_client`**
  Flutter project (this `devvit/` folder normally lives inside it) with the
  Flutter SDK installed.

### 1. Get the game bundle in place

The playable game lives in `public/game/`, which is **generated and
git-ignored**. Build and copy it:

```bash
./scripts/embed-flutter.sh
```

This runs the shared Flutter web build in the parent project and copies the
result into `public/game/` verbatim. If your Flutter checkout is elsewhere, set
`TOME_CLIENT_DIR=/path/to/Tome_client` first. Re-run this whenever the game
changes.

### 2. Install dependencies

```bash
npm install
```

### 3. Log in to Reddit

```bash
npm run login
```

### 4. Develop live on Reddit

```bash
npm run dev
```

Starts `devvit playtest` against the dev subreddit configured in `devvit.json`
(`tome_martial_arts_dev`). Edit code and see it update in a real post. Use
another Devvit-connected account to check per-user saves stay separate.

### 5. Build

```bash
npm run build
```

Compiles the splash, the game shell, and the server into `dist/`.

### 6. Deploy a new version

```bash
npm run deploy
```

Runs type-checking, linting, and unit tests, then `devvit upload`. This uploads
a new version of the app but does not publish it.

### 7. Publish for review

```bash
npm run launch
```

Runs `deploy` and then `devvit publish`, submitting the app to Reddit for
review. Approval is required before other communities can install it.

### Environment & config

- **`.env`** — `DEVVIT_ALLOW_SOURCE_UPLOAD` controls whether source is included
  in the upload. Keep real secrets out of version control.
- **`devvit.json`** — app name (`tome-martial-arts`), post entrypoints
  (`splash.html` inline, `game.html` expanded), media directory (`public/`),
  server entry, the moderator menu item, the install trigger, and the requested
  Reddit permissions. Update the menu item's `endpoint` mapping here whenever a
  new menu action is added.
- **Redis** is enabled through Devvit; there is no separate database to
  provision.

### Other useful commands

| Command              | What it does                           |
| -------------------- | -------------------------------------- |
| `npm run type-check` | TypeScript build check                 |
| `npm run lint`       | ESLint over `src/`                     |
| `npm run test`       | type-check + lint + unit tests + build |
| `npm run prettier`   | format the repo                        |

---

## Server endpoints

| Method & path                            | Purpose                                                                                                                                                                        |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `GET /api/state`                         | All saved documents for the current user, as `{ "records.v1": {…}, "codex.v1": {…}, … }`                                                                                       |
| `POST /api/state`                        | Save one document. Body: `{ key, value }`. `key` must be one of `records.v1`, `codex.v1`, `settings.v1`, `training_pace.v1`, `character.v1`. Each document is capped at 64 KB. |
| `GET /api/identity`                      | `{ key }` — the opaque per-user persistence key                                                                                                                                |
| `POST /internal/menu/post-create`        | Backs the "Create a new post" menu item                                                                                                                                        |
| `POST /internal/triggers/on-app-install` | Creates a post when the app is installed                                                                                                                                       |

Redis keys are scoped by the resolved Reddit user id (`t2_…`), or `anon` for
logged-out viewers.

---

## Project layout

```
devvit.json                 app config, entrypoints, permissions, menu, triggers
scripts/embed-flutter.sh    build + copy the Flutter game into public/game/
public/game/                the embedded Flutter web bundle (generated, git-ignored)
src/client/
  splash.tsx / splash.html  feed splash view ("Enter the Hall")
  game.html                 iframe shell that loads the game bundle
  index.css                 Tailwind entry for the splash view
src/server/
  index.ts                  Hono app: mounts /api and /internal
  routes/state.ts           /api/state, /api/identity
  routes/menu.ts            menu action → create post
  routes/triggers.ts        app-install → create post
  core/state.ts             Redis-backed per-user document store
  core/post.ts              submitCustomPost helper
  test.ts                   Vitest + in-memory Redis setup
```

---

## Testing

`npm run test` runs the full gate (types, lint, unit tests, build). Unit tests
use Vitest; `@devvit/test` provides an in-memory Redis, so `core/state.ts` is
exercised end to end. CI (`.github/workflows/ci.yaml`) runs the same gate on
pushes and PRs to `main`.

Manual checks before publishing:

- Open the post, press **Enter the Hall**, complete a full run (character
  creation → Tome → training → fight → loot → repeat → Run Complete).
- Force `/api/state` to fail — the game should still boot from an empty cache
  and keep going.
- Bump the version and re-upload — a previous run's records should still be
  there (proving they are in Redis, not `localStorage`).
- Two different Reddit accounts in the same post should have separate saves.

---

## License

BSD-3-Clause. See `LICENSE`.
