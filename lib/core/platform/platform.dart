// lib/core/platform/platform.dart
//
// The client's platform-adaptation seam for itch.io HTML5 and Reddit
// Devvit Web. Small, independent interfaces — no umbrella "PlatformService".
//
//   Persistence  -> core/persistence/game_store.dart
//                   (LocalGameStore | RemoteGameStore + GameStoreTransport)
//   Identity     -> platform_identity.dart  (PlatformIdentity)
//   Audio        -> game_audio.dart          (GameAudio, SilentAudio)
//   Capabilities -> platform_capabilities.dart
//   Lifecycle    -> Flutter's own WidgetsBindingObserver / AppLifecycleState;
//                   the timing-sensitive surface (training) additionally
//                   rejects a stalled frame in TargetField._onFrame.
//
// The engine (`built_engine`) contains none of this and never will:
// gameplay rules stay deterministic and platform-free.
export 'devvit_backend.dart';
export 'game_audio.dart';
export 'platform_capabilities.dart';
export 'platform_identity.dart';
