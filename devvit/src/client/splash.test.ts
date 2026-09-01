import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

let requestExpandedModeMock: ReturnType<typeof vi.fn>;

vi.mock('@devvit/web/client', () => {
  requestExpandedModeMock = vi.fn();
  return {
    context: { username: 'test-user' },
    requestExpandedMode: requestExpandedModeMock,
  };
});

beforeEach(async () => {
  vi.resetModules(); // splash.tsx renders on import — force a fresh render
  document.body.innerHTML = '<div id="root"></div>';
  await import('./splash');
  await new Promise((r) => setTimeout(r, 0)); // let React commit
});

afterEach(() => {
  requestExpandedModeMock?.mockReset();
});

describe('Splash', () => {
  it('renders the Tome / Martial Arts wordmark and greets the player', () => {
    const text = document.body.textContent ?? '';
    expect(text).toMatch(/tome/i);
    expect(text).toMatch(/martial arts/i);
    expect(text).toContain('test-user');
  });

  it('"Enter the Hall" requests expanded mode for the "game" entrypoint', () => {
    const start = Array.from(document.querySelectorAll('button')).find((b) =>
      /enter the hall/i.test(b.textContent ?? '')
    );
    expect(start).toBeTruthy();

    start!.click();

    expect(requestExpandedModeMock).toHaveBeenCalledTimes(1);
    expect(requestExpandedModeMock.mock.calls[0]?.[1]).toBe('game');
  });
});
