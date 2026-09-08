You are writing a Devvit web application that will be executed on Reddit.com.

## Tech Stack

- **Frontend**: React 19, Tailwind CSS 4, Vite
- **Backend**: Node.js v24 serverless environment (Devvit), Hono
- **Communication**: plain REST (Hono routes); the game client is Flutter and
  cannot use a TypeScript RPC client
- **Testing**: Vitest

## Layout & Architecture

- `/src/server`: **Backend Code**. This runs in a secure, serverless environment.
  - `index.ts`: Main server entry point (Hono app). Mounts `/api/*` and `/internal/*`.
  - `routes/`: one Hono router per concern (`state.ts`, `menu.ts`, `triggers.ts`).
  - `core/`: business logic (`state.ts` = Redis document store, `post.ts` = post creation).
  - Access `redis`, `reddit`, and `context` here via `@devvit/web/server`.
- `/src/client`: **Frontend Code**. This is executed inside of an iFrame on reddit.com
  - To add an entrypoint, create a HTML file and add to the mapping inside of `devvit.json`
  - Entrypoints:
    - `splash.html` / `splash.tsx`: React inline view shown in the reddit.com feed. Keep it fast and keep heavy dependencies out of it.
    - `game.html`: a plain iframe shell that loads the Flutter web bundle from `public/game/` (see `scripts/embed-flutter.sh`). No React, no build deps of its own.

## Data Fetching (REST)

The server exposes plain Hono routes under `/api`. The embedded Flutter client
calls them with `fetch()`.

- `GET  /api/state` → every saved document for the current user
- `POST /api/state` → `{ key, value }`, persists one whitelisted document
- `GET  /api/identity` → `{ key }`, the opaque per-user persistence key

To add an endpoint: add a route in the relevant `src/server/routes/*.ts` (or a
new router mounted from `index.ts`), keep request/response payloads small, and
do no gameplay on the server.

## Frontend

### Rules

- Instead of `window.location` or `window.assign`, use `navigateTo` from `@devvit/web/client`

### Limitations

- `window.alert`: Use `showToast` or `showForm` from `@devvit/web/client`
- File downloads: Use clipboard API with `showToast` to confirm
- Geolocation, camera, microphone, and notifications web APIs: No alternatives
- Inline script tags inside of `html` files: Use a script tag and separate js/ts file

## Commands

- `npm run type-check`: Check typescript types
- `npm run lint`: Check the linter
- `npm run test -- my-file-name`: Run tests isolated to a file

## Code Style

- Prefer type aliases over interfaces when writing typescript
- Prefer named exports over default exports
- Never cast typescript types

## Global Rules

- You may find code that references blocks or `@devvit/public-api` while building a feature. Do NOT use this code as this project is configured to use Devvit web only.
- Whenever you add an endpoint for a new menu item action, ensure that you've added the corresponding mapping to `devvit.json` so that it is properly registered

Docs: https://developers.reddit.com/docs/llms.txt.
