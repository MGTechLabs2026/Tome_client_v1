# Release smoke test — Tome: Martial Arts (web)

Run against `dist/itch/tome-web.zip` served locally
(`cd build/web && python3 -m http.server 8000`, or unzip and open via any
static server) and, before publishing, on the real itch.io page.

## Core loop

- [ ] Launch — pre-boot “TOME / MARTIAL ARTS” shell shows, then clears to the title screen
- [ ] Title screen renders (wordmark, menu, version)
- [ ] **New Game** → character creation
- [ ] Pick each style once; the **starting kit** is style-specific on the Tome:
      Polearming → Cloth + Polearm · Wrestling → Chair + Mask ·
      Fencing → Rapier + Cloth · Shaolin → Staff + Cloth ·
      Tai Chi → Fan + Towel · Kunlun → Knife + Cloth
- [ ] Tome screen: grid, tray, component detail sheet
- [ ] **Training** → active target-strike → result screen
- [ ] Technique **evolution** surfaces when it happens (surprise beat)
- [ ] Back to Tome (no Tome phase was inserted between fights)
- [ ] **Fight** → auto-resolves → **Reward** (Upgrade Point / Wider Board / New Component)
- [ ] Next fight → … → **Hard Fight** (final bout of the run) → **Final Reward**
- [ ] Return to Tome
- [ ] **New Run**: character, physique, style, items, mastery, technique
      lineage and records **persist**; run-local state (fight index) resets
- [ ] Run progression cadence unchanged: 2+1 hard (runs 1–10), 4+1 (11–20),
      6+1 (21–30), 8+1 (31+)

## Web / platform

- [ ] **Desktop browser** (Chrome, Firefox, Safari): full loop with mouse
- [ ] **Mobile browser** (iOS Safari, Android Chrome): full loop with **taps**
- [ ] Training target field hit-tests correctly at phone width; no double-resolve on a fast double-tap
- [ ] **Resize** the window mid-run — layout stays correct, no clipping
- [ ] **Refresh** mid-run — records/codex survive; a fresh run starts cleanly
- [ ] **Tab switch** during a training wave for ~30 s, return — wave still live, timing not advanced by hidden time
- [ ] **Fullscreen** toggle (itch button) — layout re-flows
- [ ] **Storage blocked** (private window / site data disabled): game still boots and plays; saves silently no-op (check console for the “persistence unavailable” line, no crash)
- [ ] Console has no uncaught exceptions across a full loop

## Devvit (once the Tome_devvit project exists — not this milestone)

- [ ] Loads in a Reddit post via `devvit playtest`
- [ ] Lineage round-trips through the server (survives an app version bump)
- [ ] Two Reddit users in one post → separate lineages
- [ ] Server error on `/api/state` → game boots from empty cache, no crash
