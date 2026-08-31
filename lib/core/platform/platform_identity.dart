// lib/core/platform/platform_identity.dart

/// Resolves a stable **persistence key** for the current player. The
/// engine never sees this — nothing in `built_engine` knows about a
/// Reddit username, a subreddit, or a device. Game logic keys off the
/// returned string only; it is opaque, and it is never derived from a
/// wall clock or any gameplay value.
abstract interface class PlatformIdentity {
  /// A stable, opaque key for scoping this player's saved state. Never a
  /// username or PII — a hash / uuid / the constant `'local'`.
  Future<String> persistenceKey();
}

/// The single-player default: one save per browser/device, so the key is
/// simply `'local'`. A platform that provides real identity (Devvit
/// resolves a per-user id server-side) supplies its own [PlatformIdentity]
/// whose `persistenceKey()` returns that id — the repositories then scope
/// their keys by it without any other code changing.
class LocalIdentity implements PlatformIdentity {
  const LocalIdentity([this.key = 'local']);
  final String key;
  @override
  Future<String> persistenceKey() async => key;
}
