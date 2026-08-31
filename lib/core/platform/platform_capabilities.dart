// lib/core/platform/platform_capabilities.dart
import 'package:flutter/foundation.dart';

/// What the surrounding platform can do — consumed for the capability
/// matrix and for the few runtime branches that genuinely need it
/// (e.g. "show a 'saving disabled' notice"). Small and flat on purpose;
/// this is not a service, just a description.
@immutable
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.id,
    required this.localPersistence,
    required this.durablePersistence,
    required this.externalNetwork,
    required this.platformIdentity,
    required this.audio,
    required this.pointer,
    required this.touch,
  });

  /// `'desktop'`, `'web'`, `'devvit'`.
  final String id;

  /// A key/value store survives a page reload / app restart.
  final bool localPersistence;

  /// Persistence survives an app **update** (localStorage does not on
  /// Devvit — that needs the server/Redis path).
  final bool durablePersistence;

  /// The client may make arbitrary outbound requests.
  final bool externalNetwork;

  /// The host provides a stable player identity.
  final bool platformIdentity;

  /// Audio output is available (still gated behind a user gesture).
  final bool audio;

  /// A mouse / trackpad is likely present.
  final bool pointer;

  /// Touch input is likely present.
  final bool touch;

  static const desktop = PlatformCapabilities(
    id: 'desktop',
    localPersistence: true,
    durablePersistence: true,
    externalNetwork: true,
    platformIdentity: false,
    audio: true,
    pointer: true,
    touch: false,
  );

  /// itch.io HTML5 / a normal browser tab.
  static const web = PlatformCapabilities(
    id: 'web',
    localPersistence: true,
    durablePersistence: true,
    externalNetwork: true,
    platformIdentity: false,
    audio: true,
    pointer: true,
    touch: true,
  );

  /// Reddit Devvit webview. localStorage is transient; durable state is
  /// the server/Redis path. Outbound networking is restricted to the
  /// Devvit server endpoint.
  static const devvit = PlatformCapabilities(
    id: 'devvit',
    localPersistence: true,
    durablePersistence: false, // only via GameStoreTransport -> server
    externalNetwork: false,
    platformIdentity: true,
    audio: true,
    pointer: true,
    touch: true,
  );

  /// A best-effort guess for the current build with no platform shell
  /// wired. `--dart-define=TOME_PLATFORM=devvit` overrides it so the
  /// Devvit client build reports the right thing.
  static PlatformCapabilities get current {
    const override = String.fromEnvironment('TOME_PLATFORM');
    return switch (override) {
      'devvit' => devvit,
      'web' => web,
      'desktop' => desktop,
      _ => kIsWeb ? web : desktop,
    };
  }
}
