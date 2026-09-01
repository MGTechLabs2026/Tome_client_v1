import { expect } from 'vitest';

import { test } from '../test';
import { identityKey, loadAll, saveDoc } from './state';

test('loadAll is empty for a fresh player', async () => {
  expect(await loadAll()).toEqual({});
});

test('saveDoc + loadAll round-trip a whitelisted document', async () => {
  await saveDoc('records.v1', { furthestRun: 3, runsCleared: 1 });
  await saveDoc('codex.v1', { items: ['knife'], techniques: [] });

  expect(await loadAll()).toEqual({
    'records.v1': { furthestRun: 3, runsCleared: 1 },
    'codex.v1': { items: ['knife'], techniques: [] },
  });
});

test('saveDoc overwrites a document in place', async () => {
  await saveDoc('training_pace.v1', { pace: 1.0 });
  await saveDoc('training_pace.v1', { pace: 0.82 });
  expect(await loadAll()).toEqual({ 'training_pace.v1': { pace: 0.82 } });
});

test('saveDoc rejects a key outside the whitelist', async () => {
  await expect(saveDoc('evil.v1', { hax: true })).rejects.toThrow(
    /unknown state key/
  );
});

test('saveDoc rejects an oversized document', async () => {
  const big = { blob: 'x'.repeat(70 * 1024) };
  await expect(saveDoc('records.v1', big)).rejects.toThrow(/too large/);
});

test('identityKey is a stable non-empty string', () => {
  const a = identityKey();
  const b = identityKey();
  expect(a).toBe(b);
  expect(a.length).toBeGreaterThan(0);
});
