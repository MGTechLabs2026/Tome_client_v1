import { Hono } from 'hono';
import { z } from 'zod';

import { identityKey, loadAll, saveDoc, STATE_KEYS } from '../core/state';

/** GET  /api/state            -> every stored doc for the current player
 *  POST /api/state {key,value} -> persist one whitelisted doc            */
export const state = new Hono();

state.get('/', async (c) => {
  return c.json(await loadAll());
});

const saveBody = z.object({
  key: z.enum([...STATE_KEYS] as [string, ...string[]]),
  value: z.record(z.string(), z.unknown()),
});

state.post('/', async (c) => {
  let body: unknown;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: 'invalid JSON body' }, 400);
  }
  const parsed = saveBody.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: parsed.error.message }, 400);
  }
  try {
    await saveDoc(parsed.data.key, parsed.data.value);
    return c.json({ ok: true });
  } catch (e) {
    return c.json({ error: e instanceof Error ? e.message : String(e) }, 400);
  }
});

/** GET /api/identity -> { key } : the opaque per-player persistence key. */
export const identity = new Hono();

identity.get('/', (c) => c.json({ key: identityKey() }));
