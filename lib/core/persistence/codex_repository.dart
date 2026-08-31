// lib/core/persistence/codex_repository.dart
//
// What the player has met, across every run — the source of the
// ALMANAC page's lock state. Three sets of content ids (styles, items,
// techniques); `discover` is idempotent. Fed from the discovery calls
// the engine adapters already make, never from the engine directly.
import 'game_store.dart';

const _kKey = 'codex.v1';

enum CodexKind { style, item, technique }

class CodexSnapshot {
  const CodexSnapshot({
    this.styles = const {},
    this.items = const {},
    this.techniques = const {},
  });

  final Set<String> styles;
  final Set<String> items;
  final Set<String> techniques;

  Set<String> of(CodexKind kind) => switch (kind) {
        CodexKind.style => styles,
        CodexKind.item => items,
        CodexKind.technique => techniques,
      };

  int get total => styles.length + items.length + techniques.length;
  bool get isEmpty => total == 0;
}

class CodexRepository {
  CodexRepository(this._store) {
    final json = _store.read(_kKey);
    _styles = _readSet(json['styles']);
    _items = _readSet(json['items']);
    _techniques = _readSet(json['techniques']);
  }

  final GameStore _store;
  late Set<String> _styles;
  late Set<String> _items;
  late Set<String> _techniques;

  CodexSnapshot get snapshot => CodexSnapshot(
        styles: Set.unmodifiable(_styles),
        items: Set.unmodifiable(_items),
        techniques: Set.unmodifiable(_techniques),
      );

  /// Records [id] under [kind]. A no-op (no write) if already known.
  Future<void> discover(CodexKind kind, String id) {
    if (id.isEmpty) return Future.value();
    final set = switch (kind) {
      CodexKind.style => _styles,
      CodexKind.item => _items,
      CodexKind.technique => _techniques,
    };
    if (!set.add(id)) return Future.value();
    return _store.write(_kKey, {
      'styles': _styles.toList(),
      'items': _items.toList(),
      'techniques': _techniques.toList(),
    });
  }

  static Set<String> _readSet(Object? raw) => raw is List
      ? raw.map((e) => e.toString()).toSet()
      : <String>{};
}
