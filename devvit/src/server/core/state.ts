import { context, redis } from '@devvit/web/server';

/**
 * Per-player persistent game state, in Redis.
 *
 * The Flutter client (built_engine game) keeps its cross-run state as a
 * handful of small versioned JSON documents — the same ones it stores in
 * `localStorage` on desktop / itch. On Devvit `localStorage` is not
 * durable (the webview URL changes on app update), so those documents
 * live here instead, one Redis hash per player.
 *
 * Contract consumed by the client: `GameStoreTransport` in
 * Tome_client/lib/core/persistence/game_store.dart
 *   GET  /api/state            -> { "<key>": <doc>, ... }
 *   POST /api/state {key,value} -> { ok: true }
 *   GET  /api/identity          -> { key: "<opaque player id>" }
 *
 * No gameplay runs here. This is persistence + identity only.
 */

/** The client repositories' own versioned keys — whitelisted so a bad
 *  request can't spray arbitrary fields, and the payload stays bounded. */
export const STATE_KEYS = [
  'records.v1',
  'codex.v1',
  'settings.v1',
  'training_pace.v1',
  'character.v1', // reserved for a future engine-state document
] as const;
export type StateKey = (typeof STATE_KEYS)[number];

const MAX_DOC_BYTES = 64 * 1024; // one document; the real docs are ~<1 KB

/** `context.userId` is a stable Reddit id (`t2_…`), never the username.
 *  A logged-out viewer shares an ephemeral `anon` slot. */
function playerId(): string {
  return context.userId ?? 'anon';
}

function hashKey(): string {
  return `state:${playerId()}`;
}

/** Every stored document for the current player. One Redis round-trip. */
export async function loadAll(): Promise<Record<string, unknown>> {
  const raw = await redis.hGetAll(hashKey());
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(raw ?? {})) {
    if (!v) continue;
    try {
      out[k] = JSON.parse(v);
    } catch {
      // skip a corrupt field rather than fail the whole load
    }
  }
  return out;
}

/** Persist one whitelisted document for the current player. */
export async function saveDoc(key: string, value: unknown): Promise<void> {
  if (!(STATE_KEYS as readonly string[]).includes(key)) {
    throw new Error(`unknown state key: ${key}`);
  }
  const json = JSON.stringify(value ?? {});
  if (json.length > MAX_DOC_BYTES) {
    throw new Error(`state doc "${key}" too large (${json.length} > ${MAX_DOC_BYTES} bytes)`);
  }
  await redis.hSet(hashKey(), { [key]: json });
}

/** The opaque persistence key handed to the client's `PlatformIdentity`.
 *  The game engine never sees this — it scopes storage only. */
export function identityKey(): string {
  return playerId();
}
