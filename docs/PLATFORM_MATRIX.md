# Platform capability matrix — Tome: Martial Arts

One game, one engine, one client. This is what the client's platform seam
(`lib/core/platform/`) has to adapt per target.

Legend: **✅ supported** · **🔌 supported with adapter** · **⛔ unavailable** ·
**🕓 future**

| Capability | Desktop | Web / itch.io | Devvit |
|---|---|---|---|
| Tome UI | ✅ | ✅ | ✅ |
| Training (target-strike) | ✅ | ✅ (mouse **and** touch) | ✅ (mouse **and** touch) |
| Combat (auto-resolved) | ✅ | ✅ | ✅ |
| Local persistence (survives reload) | ✅ `LocalGameStore` | ✅ `LocalGameStore` → `localStorage` | ✅ `localStorage` — **transient only** |
| Durable persistence (survives app update) | ✅ | ✅ (`localStorage` is stable per origin) | 🔌 `RemoteGameStore` + `GameStoreTransport` → Devvit server → Redis |
| Sound | 🕓 seam only (`SilentAudio`) | 🕓 seam only; real impl must gate on first gesture | 🕓 seam only |
| Mouse / pointer | ✅ | ✅ | ✅ |
| Touch | ⛔ (n/a) | ✅ | ✅ |
| External network (arbitrary) | ✅ | ✅ | ⛔ — only the Devvit server endpoint |
| Platform identity | ⛔ (`LocalIdentity` → `'local'`) | ⛔ (`LocalIdentity` → `'local'`) | 🔌 `PlatformIdentity` impl resolves the Devvit user id server-side |
| Analytics / telemetry | 🕓 | 🕓 | 🕓 (Devvit server, optional) |
| Tab / visibility lifecycle | n/a | ✅ handled (`TargetField` stall clamp + `AppLifecycleState`) | ✅ same |
| Fullscreen / embedded resize | ✅ | ✅ responsive to available box (iframe) | ✅ responsive to available box (webview) |

## Notes

- **No gameplay code branches on platform.** Combat, training, evolution,
  reward and progression run the same deterministic `built_engine` code on
  every target. The seam only swaps *persistence transport*, *identity
  source*, and (later) *audio backend*.
- **`localStorage` on Devvit is not authoritative.** Devvit rebuilds the
  webview iframe URL on app update, which can drop `localStorage`. The
  character lineage must round-trip through the Devvit server (Redis) via
  `GameStoreTransport`. `localStorage` there is fine only for throwaway UI
  state (last-open tab, a collapsed panel).
- **Audio is a seam, not a feature.** There are no audio assets in the
  project. `SilentAudio` is wired so call sites exist; a real backend
  (which must respect browser autoplay rules — nothing before the first
  user gesture) drops in without touching gameplay.
- **`PlatformCapabilities.current`** guesses from `kIsWeb` and honours
  `--dart-define=TOME_PLATFORM=devvit|web|desktop`. The Devvit client
  build (`scripts/build_devvit_client.sh`) sets that define.
