# Combat & training sound effects — design

**Date:** 2026-09-09
**Status:** design — pending review
**Repo:** `Tome_client` (Flutter), on `build_engine` `b43b414`
**Touches:** `lib/core/platform/game_audio.dart` (seam), a new `audioplayers`
backend, `lib/core/models/combat_log_entry_view.dart`,
`lib/core/engine/combat_adapter.dart`, the combat + training feature areas,
`lib/core/persistence/settings_repository.dart`,
`lib/features/title/settings_screen.dart`, `pubspec.yaml`, a new
`tools/gen_sfx.py` + `assets/audio/`.

---

## 1. Why this exists

The client ships a deliberately-stubbed audio seam — `GameAudio` /
`SoundCue` / `SilentAudio` in `lib/core/platform/game_audio.dart`, exported
through `lib/core/platform/platform.dart`. It has **no real backend, no
audio dependency, no assets, and zero call sites**. Its docstring names a
"Task 11" that never landed.

This design fills it in: a real playback backend, a synthesized SFX asset
set, and call sites in the combat log replay and the training
target-strike minigame, plus a persisted volume/mute control in Settings.

Non-goals: music/ambient loops, positional audio, haptics, per-cue volume
mixing, an audio settings screen beyond one toggle + one slider, sound on
any screen outside combat/training and their prep/result screens.

## 2. Scope

### 2.1 In scope

- Add `audioplayers` to `pubspec.yaml`.
- New `lib/core/platform/audioplayers_game_audio.dart` implementing
  `GameAudio` against a small pooled set of `AudioPlayer`s.
- Change the `GameAudio` interface: `muted` (bool) → `enabled` (bool) +
  `volume` (double 0..1). Update `SilentAudio` to store (not act on) both.
- Grow `SoundCue` from 7 to 13 cues (§4).
- `tools/gen_sfx.py` — pure-stdlib WAV synthesis for all 13 cues; optional
  `ffmpeg` transcode to `.ogg`. Committed output lives in `assets/audio/`.
- `assets/audio/` declared in `pubspec.yaml` `flutter: assets:`, with a
  `README.md` pointing at the generator.
- `CombatLogEntryView` gains `SoundCue? cue`; `combat_adapter.dart` sets it
  per entry.
- Combat log replay plays `entry.cue` on each reveal tick; `stopAll()` on
  leaving the screen.
- Training minigame plays cues at its existing hit / perfect / miss /
  timeout / wave / session-end points; `stopAll()` on screen dispose.
- `uiTap` on the primary action(s) of exactly four screens:
  `combat_preparation_screen`, `combat_screen` (result state),
  `training_preparation_screen`, `training_result_screen`.
- `techniqueEvolved` on the training result screen when a technique evolved.
- `SettingsRepository`: persisted `soundEnabled` (default `true`) +
  `soundVolume` (default `0.7`); write-through setters.
- Composition-root wiring: push `soundEnabled` / `soundVolume` into the live
  `GameAudio` on construction and on change.
- `settings_screen.dart`: a "Sound effects" toggle + a 0–100% volume slider
  (slider greyed when the toggle is off).
- Web unlock from first gesture; `stopAll()` on app `paused`/`hidden`.
- Tests per §8.

### 2.2 Out of scope

- Any music, ambient bed, or looping audio.
- Positional / stereo-panned audio.
- Per-cue or per-category volume.
- Sound on the title, hall, tome, loot, character-creation, or run-map
  screens (beyond the four prep/result screens listed above).
- Downloading third-party audio; all assets are generated in-repo.
- A `PlatformCapabilities` branch for audio — the backend is identical on
  every target.

## 3. Architecture

### 3.1 The seam (unchanged shape, changed surface)

`GameAudio` stays the single interface every caller depends on. Interface
delta:

```dart
abstract interface class GameAudio {
  bool get enabled;
  set enabled(bool value);

  double get volume;          // 0.0..1.0, clamped by the setter
  set volume(double value);

  Future<void> unlock();      // call once from the first user gesture
  void play(SoundCue cue);
  void stopAll();
}
```

`SilentAudio` (the default, and every test's default) becomes:

```dart
class SilentAudio implements GameAudio {
  @override bool enabled = false;
  @override double volume = 0;
  @override Future<void> unlock() async {}
  @override void play(SoundCue cue) {}
  @override void stopAll() {}
}
```

Storing `enabled` / `volume` (rather than ignoring them) lets a
`SettingsRepository` test assert the wiring drove the seam without a real
backend.

### 3.2 The real backend — `AudioPlayersGameAudio`

`lib/core/platform/audioplayers_game_audio.dart`.

- **Cue → asset map:** a `const Map<SoundCue, String>` to
  `'audio/<name>.ogg'` (paths relative to the Flutter asset root; the
  `assets/` prefix is implicit for `AssetSource`).
- **Player pool:** `List<AudioPlayer>` of length 4, created lazily on
  `unlock()`. `play()` advances a round-robin index and calls
  `player.play(AssetSource(path), volume: _volume)` — a fresh `play` on a
  busy player restarts it, which is the desired one-shot behaviour; four
  players give enough overlap headroom for the 400ms combat cadence and
  rapid training taps without cue-stealing being audible.
- **`play(cue)`** returns immediately and does nothing when
  `!_enabled || _volume <= 0 || (kIsWeb && !_unlocked)`. Otherwise it
  schedules the play inside a `try/catch` that swallows everything
  (`unawaited(...)` on the future, `.catchError((_) {})`).
- **`unlock()`** — on web: create the pool, then `for each player: await
  player.play(AssetSource(<any cue>), volume: 0)` then `player.stop()`,
  inside try/catch; set `_unlocked = true`. Idempotent (guarded by
  `_unlocked`). On non-web: still creates the pool, sets `_unlocked = true`,
  no priming needed.
- **`stopAll()`** — `for each player: player.stop()` in try/catch. Safe
  before `unlock()` (no pool yet → no-op).
- **`enabled` / `volume` setters** — store; `volume` clamps to `[0,1]` and
  is applied to subsequent `play` calls (no need to retro-adjust
  in-flight one-shots). Setting `enabled = false` also calls `stopAll()`.
- **Disposal:** the backend is app-lifetime; no `dispose()` in normal
  flow. (If a future teardown path needs it, add `dispose()` that stops +
  releases each player.)

### 3.3 Composition & wiring

Wherever `SettingsRepository` and the `GameAudio` instance are constructed
for the Flutter runtime (the app composition root — `lib/app/tome_app.dart`
or its `main` entry; the plan pins the exact spot):

- Construct `AudioPlayersGameAudio` instead of `SilentAudio` for the
  Flutter runtime. Tests and any headless path keep `SilentAudio`.
- Provide the `GameAudio` instance to the widget tree (the same mechanism
  the app already uses for `SettingsRepository` — `Provider` /
  `context.read`).
- Attach one listener that runs now and on every change:
  ```dart
  void _sync() {
    audio.enabled = settings.soundEnabled.value;
    audio.volume  = settings.soundVolume.value;
  }
  settings.soundEnabled.addListener(_sync);
  settings.soundVolume.addListener(_sync);
  _sync();
  ```
- Register an `AppLifecycleListener` (or `WidgetsBindingObserver`) whose
  `onHide` / `onPause` calls `audio.stopAll()`.
- The first-gesture unlock: wrap the app's root in a `Listener`
  (`onPointerDown`) that calls `audio.unlock()` once and then removes
  itself / no-ops. (Alternative: the title screen's first button — the
  plan picks whichever is least invasive; root `Listener` is preferred
  because training/combat can be deep-linked in tests and dev.)

### 3.4 Assets & the build

- `tools/gen_sfx.py`: stdlib only (`struct`, `wave`, `math`, `random` with
  a fixed seed). Writes 16-bit mono 44.1kHz WAV. Synthesis primitives:
  enveloped sine/triangle transient, band-limited noise burst, noise sweep
  (whoosh), short pitch-glide. Each cue 80–400ms, peak-normalised to
  −3 dBFS. If `ffmpeg` is on `PATH`, transcode each `.wav` → `.ogg`
  (`-q:a 3`) and delete the `.wav`; otherwise leave `.wav` (Flutter plays
  both, `.ogg` is just smaller). Deterministic: same input → byte-identical
  output.
- Committed assets: `assets/audio/*.ogg` (or `.wav` fallback), 13 files,
  target **< 150 KB total**.
- `pubspec.yaml`:
  ```yaml
  flutter:
    assets:
      - assets/audio/
  ```
- No build-script change. `scripts/build_web.sh` bundles `assets/` into
  `build/web/` as-is; `scripts/package_itch.sh` and
  `devvit/scripts/embed-flutter.sh` consume that same output, so both
  targets get the audio with zero per-target work. Devvit's external-origin
  CSP is irrelevant — the files are bundled, not fetched. Bundle-size
  impact: ~0.1 MB against the current ~14 MB.
- `assets/audio/README.md`: "Generated by `tools/gen_sfx.py`. To retune a
  cue, edit its recipe there and re-run: `python3 tools/gen_sfx.py`."

## 4. `SoundCue` — the 13 cues

```dart
enum SoundCue {
  uiTap,            // button / transition on the 4 prep+result screens
  strikeDull,       // your bare-handed hit lands (muffled thud)
  strikeWeapon,     // your weapon hit lands (short, sharp)
  strikeTechnique,  // your technique hit lands (longer, edged)
  strikePerfect,    // training: perfectly-timed hit (bright ring)
  strikeMiss,       // any missed attack (wind / whoosh)
  guardHold,        // a guard holds / armour soaks a blow (soft clack)
  bodyBlow,         // an enemy blow lands on you (low thud)
  waveStart,        // training: a new target wave begins (short tick)
  sessionEnd,       // training: session finishes (soft resolve)
  techniqueEvolved, // a technique evolves (flourish)
  fightWon,         // victory (rising chime)
  fightLost,        // defeat (low boom)
}
```

`strikeHit` / `strikePerfect` / `strikeMiss` from today's enum: `strikeHit`
is removed (split into `strikeDull` / `strikeWeapon` / `strikeTechnique`),
`strikePerfect` and `strikeMiss` keep their names. Zero call sites, so no
migration.

## 5. Combat integration

### 5.1 `CombatLogEntryView` gains a cue

```dart
class CombatLogEntryView {
  const CombatLogEntryView({
    required this.kind,
    required this.text,
    this.cue,               // NEW — nullable; not every line makes a sound
    this.playerHp,
    this.playerHpMax,
    this.enemyHp,
    this.enemyHpMax,
  });
  final SoundCue? cue;
  // …existing fields…
}
```

### 5.2 `combat_adapter.dart` sets `cue:` per entry

The adapter already classifies every action it logs. Mapping (all in the
`entry(...)` / `log.add(...)` sites around lines 355–463 and the
victory/defeat line at ~191):

| Logged event | `cue` |
|---|---|
| player hit, `_CompKind.weapon` | `strikeWeapon` |
| player hit, `_CompKind.technique` | `strikeTechnique` |
| player hit, `_CompKind.fist` | `strikeDull` |
| player action misses / "goes wide" / guard "breaks" | `strikeMiss` |
| guard holds, or player armour soaks (`heal` from a defence comp) | `guardHold` |
| "Enemy hits for …" / "Enemy hits again for …" (blow lands on player) | `bodyBlow` |
| "Enemy recovers …" (enemy self-heal) | `null` |
| `turnStart`, `actionResolved` summary line | `null` |
| victory line | `fightWon` |
| defeat line | `fightLost` |

Deterministic and pure — no RNG, no I/O. The cue is a function of the same
branch the adapter already took to choose the entry's `kind` and `text`.

### 5.3 Playback in `log_replay_combat_presentation.dart`

The presentation already reveals entries on a `Timer.periodic(400ms)`. In
the tick that reveals entry *i*: if `log[i].cue != null`, call
`context.read<GameAudio>().play(log[i].cue!)`. On `dispose()` (and when the
replay is skipped/fast-forwarded to the end), call `audio.stopAll()` so a
half-played whoosh doesn't trail into the result screen.

If a "reveal all instantly" / skip path exists, it plays only the final
`fightWon`/`fightLost` cue, not the whole backlog.

## 6. Training integration

The training minigame (`training_bloc`, `target_strike_controller`,
`active_training_screen`, `training_result_screen`) already emits the
events; add `context.read<GameAudio>().play(...)` at each:

| Training event | `cue` |
|---|---|
| target hit — session drills a technique | `strikeTechnique` |
| target hit — session drills a weapon | `strikeWeapon` |
| target hit — bare-handed session | `strikeDull` |
| hit landed inside the perfect window | `strikePerfect` (instead of the above) |
| target missed / timed out | `strikeMiss` |
| a new wave starts | `waveStart` |
| session ends (last wave resolved) | `sessionEnd` |
| training result screen, first build, a technique evolved | `techniqueEvolved` |

Which component a session drills is already known to the training
bloc/state (it's what mastery is awarded to); the plan pins the exact
accessor. `active_training_screen` calls `audio.stopAll()` on `dispose()`.

## 7. UI taps

A single helper — e.g. `void tap(BuildContext c) =>
c.read<GameAudio>().play(SoundCue.uiTap);` — invoked from the primary
action handler(s) of exactly:

- `combat_preparation_screen` — the "begin" action
- `combat_screen` — the result-state "continue" action
- `training_preparation_screen` — the "begin" action
- `training_result_screen` — the "continue" action

Not app-wide, not on secondary/back buttons. Keeps the change reviewable
and avoids a click on every tap in the game.

## 8. Settings & persistence

### 8.1 `SettingsRepository`

Same `settings.v1` `GameStore` key, two new fields:

```dart
late final ValueNotifier<bool>   soundEnabled;   // default true
late final ValueNotifier<double> soundVolume;    // default 0.7, clamp [0,1]

Future<void> setSoundEnabled(bool value);   // write-through
Future<void> setSoundVolume(double value);  // write-through, clamps
```

Constructor reads them from the same JSON blob it already reads
`reduceMotion` from (`json['soundEnabled'] ?? true`,
`(json['soundVolume'] as num?)?.toDouble() ?? 0.7`). A pre-existing
`settings.v1` blob without the keys reads the defaults — no migration.
Every setter writes the **whole** blob (`reduceMotion` + `soundEnabled` +
`soundVolume`) so the three stay co-persisted.

### 8.2 `settings_screen.dart`

Under the "Reduce motion" toggle:

- A `_Toggle` "Sound effects" / "Combat and training sound." bound to
  `soundEnabled` via `ValueListenableBuilder`.
- A new `_Slider` widget (thin wrapper over `Slider`, styled to the hall
  theme) labelled "Volume", 0–100%, bound to `soundVolume`. Wrapped in
  `IgnorePointer` + reduced opacity (or `Slider(onChanged: null)`) when
  `soundEnabled` is false.
- The trailing placeholder line changes from
  "More settings — audio, text size — arrive as the game fills out." to
  "More settings — text size — arrive as the game fills out."

### 8.3 Wiring

Per §3.3: one listener at the composition root keeps
`audio.enabled == soundEnabled` and `audio.volume == soundVolume` live.
Settings changes take effect on the next cue with no restart.

## 9. Web & lifecycle rules

The seam's docstring already enumerates these; the backend honours them:

1. **No sound before the first gesture.** Root `Listener.onPointerDown`
   calls `audio.unlock()` once. `play()` is a no-op on web until
   `unlock()` resolves. Native platforms are unaffected (unlock still
   called, harmless).
2. **`enabled` / `volume` honoured immediately**, and persisted by
   `SettingsRepository` (§8).
3. **Play/decode errors swallowed** — never thrown, never logged in a loop.
4. **`stopAll()` on background / screen change** — `AppLifecycleListener`
   `onHide`/`onPause`; combat & training screens on `dispose()`.

## 10. Files

**New:**
- `lib/core/platform/audioplayers_game_audio.dart`
- `tools/gen_sfx.py`
- `assets/audio/` — 13 generated files + `README.md`
- `test/core/platform/game_audio_test.dart` (SilentAudio surface,
  FakeGameAudio)
- `test/tools/gen_sfx_test.dart` **or** a `tools/` self-check invoked from
  CI (not a `flutter test`) — the plan picks one

**Modified:**
- `pubspec.yaml` — `audioplayers` dep, `assets/audio/` entry
- `lib/core/platform/game_audio.dart` — interface + `SilentAudio` + enum
- `lib/core/platform/platform.dart` — no change expected. The concrete
  `AudioPlayersGameAudio` is imported only at the composition root, not
  re-exported, so gameplay code sees only the `GameAudio` interface (same
  discipline as the other platform seams).
- `lib/core/models/combat_log_entry_view.dart` — `SoundCue? cue`
- `lib/core/engine/combat_adapter.dart` — set `cue:` per entry
- `lib/features/combat/presentation/log_replay_combat_presentation.dart` —
  play on reveal, `stopAll()` on dispose
- `lib/features/combat/combat_preparation_screen.dart`,
  `lib/features/combat/combat_screen.dart` — `uiTap`
- `lib/features/training/training_bloc.dart` and/or
  `lib/features/training/exercise/target_strike_controller.dart` — hit /
  perfect / miss / wave / end cues
- `lib/features/training/active_training_screen.dart` — `stopAll()` on
  dispose
- `lib/features/training/training_preparation_screen.dart`,
  `lib/features/training/training_result_screen.dart` — `uiTap`,
  `techniqueEvolved`
- `lib/core/persistence/settings_repository.dart` — `soundEnabled` /
  `soundVolume`
- `lib/features/title/settings_screen.dart` — toggle + slider
- `lib/app/tome_app.dart` (or the composition root the plan identifies) —
  construct `AudioPlayersGameAudio`, wire the listener, lifecycle,
  root-gesture unlock
- `test/core/engine/combat_adapter_test.dart` — assert `cue` sequence
- `test/core/engine/sp2_aura_inertness_test.dart` — fold `cue` into
  `structural`
- `test/core/persistence/settings_repository_test.dart` (or wherever it
  lives) — `soundEnabled` / `soundVolume` round-trip
- widget tests for the combat replay + training screens — `FakeGameAudio`
  assertions
- `test/features/title/settings_screen_test.dart` — toggle + slider

## 11. Testing

- **Cue determinism:** `combat_adapter_test.dart` asserts the `cue` on
  representative entries for each `_CompKind`, miss, guard hold, enemy
  blow, victory, defeat. The cue stream is now part of the observable
  combat result.
- **Aura inertness:** `sp2_aura_inertness_test.dart`'s `_runScenario`
  serialises `e.cue?.name` into the `structural` list; the SP1 baseline
  literals gain the cue column. A leaked aura that changed a hit/miss
  would change a cue too.
- **Seam:** `SilentAudio` stores `enabled`/`volume`; a `FakeGameAudio`
  records `(SoundCue, callIndex)` for widget-test assertions.
- **Combat replay widget test:** drive a known log through the
  presentation with a `FakeGameAudio` provided; assert the cue sequence
  matches the entries' `cue` values, and `stopAll()` on dispose.
- **Training widget test:** simulate hit / perfect / miss / wave / end;
  assert cues.
- **Settings:** `SettingsRepository` round-trips `soundEnabled` /
  `soundVolume` through a fake `GameStore`; defaults when keys absent;
  setter clamps volume. `settings_screen` widget test renders both
  controls, drives the repo, and disables the slider when off.
- **Generator:** `tools/gen_sfx.py` runs clean and emits 13 files with
  valid WAV/OGG headers; deterministic (two runs → identical bytes).
- **Not unit-tested:** `AudioPlayersGameAudio` itself (real
  `audioplayers` I/O) — exercised via `flutter run` / manual, like the
  other platform seams.
- **Gate:** `flutter analyze` clean, `flutter test` green,
  `scripts/package_itch.sh` builds and stays within its file-count / size
  limits.

## 12. Determinism & the SP4a determinism property

`combat_adapter` stays pure — the cue is derived, not drawn. The
"two fresh `EngineSession(seed)` → identical observable result" property
(SP4a §5) still holds and now additionally covers the cue stream:
`sp2_aura_inertness_test.dart` and `combat_adapter_test.dart` assert it.
No RNG, no I/O added to the engine-adjacent layer. All sound I/O lives
behind the `GameAudio` seam, which is `SilentAudio` in every test.

## 13. Self-review

- **Placeholders:** none. Every cue has a defined trigger and a
  one-line synthesis brief; every file is named.
- **Consistency:** the `GameAudio` interface delta (§3.1) matches
  `SilentAudio` (§3.1), the backend (§3.2), the wiring (§3.3), and the
  settings values (§8.1). The 13 cues (§4) are exactly the ones used in
  §5–§7. `strikeHit` removal is consistent with zero call sites.
- **Scope:** one dependency, one new backend file, one generator, a
  nullable field on one view + its producer, call sites in two feature
  areas + four screens, two persisted settings + two controls. No music,
  no positional audio, no per-category mixing, no sound outside the named
  screens.
- **Ambiguity:** "session drills a technique/weapon/fist" for the training
  hit cue — the plan pins the exact accessor on the training state. The
  first-gesture unlock hook (root `Listener` vs. title button) — the plan
  picks; root `Listener` recommended. The generator's `.ogg`-vs-`.wav`
  committed form depends on `ffmpeg` availability at generation time — the
  plan runs it once and commits whatever it produces; both play.

## 14. Next step

`superpowers:writing-plans` → implementation plan.
