import 'package:build_engine/almanac.dart';

/// The app-lifetime owner of the engine Almanac recorder + its persistence.
///
/// Built ONCE at the composition root (beside `CodexRepository`), above the
/// session-keyed provider subtree, so it survives NEW RUN — an affix
/// recorded in one `EngineSession` stays available after the session is
/// rebuilt for the next run. Injected directly into the adapters that use
/// it; it is deliberately NOT threaded through `EngineSession` (which is
/// run-scoped and would be torn down each run).
///
/// The engine owns recording, querying, identity and serialization. This
/// only: hydrates a recorder from the repository at startup, exposes it,
/// and flushes it back through the repository on [persist].
class AlmanacSession {
  AlmanacSession(this._repo) : _recorder = AlmanacRecorder(_repo.load());

  final AlmanacRepository _repo;
  final AlmanacRecorder _recorder;

  /// The live recorder — Task 4 calls `recordAffixDiscovered` on it.
  AlmanacRecorder get recorder => _recorder;

  /// A read-only view over the recorder's current state. Rebuilt per call
  /// because `AlmanacRecorder.state` materialises a fresh `AlmanacState`.
  AlmanacQueries get queries => AlmanacQueries(_recorder.state);

  /// Flush the whole current `AlmanacState` back to the repository.
  /// Fire-and-forget by the repository's contract.
  void persist() => _repo.save(_recorder.state);
}
