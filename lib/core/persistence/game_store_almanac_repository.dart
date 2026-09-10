import 'package:build_engine/almanac.dart';

import 'game_store.dart';

const _kKey = 'almanac.v1';

/// The client's persistence backing for the engine Almanac. The engine
/// owns recording, querying, identity and serialization; this only moves
/// a complete [AlmanacState] between [AlmanacSerialization] JSON and one
/// [GameStore] document. Tolerates a missing / unparseable document by
/// returning [AlmanacState.empty] — same forward-compat contract as the
/// other repositories.
///
/// `save()` delegates persistence through the existing asynchronous,
/// fire-and-forget `GameStore.write()` contract. It does NOT redefine
/// that contract or synchronously guarantee remote-transport completion;
/// "repository state updated" and "remote write completed" are distinct.
/// Tests observe completion through a deterministic test store/transport.
class GameStoreAlmanacRepository implements AlmanacRepository {
  GameStoreAlmanacRepository(this._store);

  final GameStore _store;

  @override
  AlmanacState load() {
    final json = _store.read(_kKey);
    if (json.isEmpty) return AlmanacState.empty();
    try {
      return AlmanacSerialization.stateFromJson(Map<String, dynamic>.from(json));
    } catch (_) {
      return AlmanacState.empty();
    }
  }

  @override
  void save(AlmanacState state) {
    _store.write(_kKey, AlmanacSerialization.stateToJson(state));
  }
}
