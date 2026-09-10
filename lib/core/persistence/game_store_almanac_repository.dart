import 'package:build_engine/almanac.dart';
import 'package:flutter/foundation.dart';

import 'game_store.dart';

const _kKey = 'almanac.v1';

/// The client's persistence backing for the engine Almanac. The engine
/// owns recording, querying, identity and serialization; this only moves
/// a complete [AlmanacState] between [AlmanacSerialization] JSON and one
/// [GameStore] document.
///
/// A missing, malformed, or envelope-less document loads as
/// [AlmanacState.empty] and the next [save] overwrites it — the same
/// self-healing tolerance the other repositories give a garbage read.
/// A document whose `almanacSchemaVersion` is *present but unrecognised*
/// is different: it holds real v1+ history this build cannot parse, so
/// [load] still returns empty but latches [_incompatible], and [save]
/// then becomes a no-op for the session — that document is never
/// clobbered by a fresh empty state.
///
/// `save()` otherwise delegates through the existing asynchronous,
/// fire-and-forget `GameStore.write()` contract. It does NOT redefine
/// that contract or synchronously guarantee remote-transport completion;
/// "repository state updated" and "remote write completed" are distinct.
/// Tests observe completion through a deterministic test store/transport.
class GameStoreAlmanacRepository implements AlmanacRepository {
  GameStoreAlmanacRepository(this._store);

  final GameStore _store;

  /// Set when [load] met an [AlmanacSchemaVersionError]. While set, [save]
  /// refuses to write so a newer on-disk document is not clobbered.
  bool _incompatible = false;

  @override
  AlmanacState load() {
    final json = _store.read(_kKey);
    if (json.isEmpty) return AlmanacState.empty();
    try {
      return AlmanacSerialization.stateFromJson(Map<String, dynamic>.from(json));
    } on AlmanacSchemaVersionError catch (e) {
      // `found == null` means no envelope at all — garbage or a pre-v1
      // doc, nothing to lose, let the next save overwrite it. A real but
      // unrecognised version number is v1+ history from a newer build.
      if (e.found != null) {
        _incompatible = true;
        debugPrint(
          'AlmanacRepository: on-disk schema unreadable ($e) — keeping it '
          'untouched; affix history is unavailable this session.',
        );
      }
      return AlmanacState.empty();
    } catch (_) {
      return AlmanacState.empty();
    }
  }

  @override
  void save(AlmanacState state) {
    if (_incompatible) return;
    _store.write(_kKey, AlmanacSerialization.stateToJson(state));
  }
}
