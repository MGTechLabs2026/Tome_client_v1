// lib/core/persistence/records_repository.dart
//
// The lineage's bests, shown on the RECORDS page of the title screen.
// Every field is a "keep it if it beats what's stored" scalar, written
// at run boundaries (a run cleared, a run ended) and once per fight
// (the heaviest single blow). Nothing here needs the engine.
import 'game_store.dart';

const _kKey = 'records.v1';

/// An immutable read of every tracked record. Zeroes mean "not set yet"
/// — the RECORDS page renders those as an em dash.
class RecordsSnapshot {
  const RecordsSnapshot({
    this.runsCleared = 0,
    this.furthestRun = 0,
    this.longestRunBouts = 0,
    this.heaviestBlow = 0,
  });

  /// How many runs have been carried to their hard fight and won.
  final int runsCleared;

  /// The highest run number ever reached (cleared or fallen on).
  final int furthestRun;

  /// The bout count of the longest run ever entered (3 / 5 / 7 / 9).
  final int longestRunBouts;

  /// The largest amount of damage dealt in one blow, across all fights.
  final int heaviestBlow;

  bool get isEmpty =>
      runsCleared == 0 &&
      furthestRun == 0 &&
      longestRunBouts == 0 &&
      heaviestBlow == 0;

  RecordsSnapshot _copyWith({
    int? runsCleared,
    int? furthestRun,
    int? longestRunBouts,
    int? heaviestBlow,
  }) =>
      RecordsSnapshot(
        runsCleared: runsCleared ?? this.runsCleared,
        furthestRun: furthestRun ?? this.furthestRun,
        longestRunBouts: longestRunBouts ?? this.longestRunBouts,
        heaviestBlow: heaviestBlow ?? this.heaviestBlow,
      );

  Map<String, Object?> _toJson() => {
        'runsCleared': runsCleared,
        'furthestRun': furthestRun,
        'longestRunBouts': longestRunBouts,
        'heaviestBlow': heaviestBlow,
      };

  static RecordsSnapshot _fromJson(Map<String, Object?> json) => RecordsSnapshot(
        runsCleared: (json['runsCleared'] as num?)?.toInt() ?? 0,
        furthestRun: (json['furthestRun'] as num?)?.toInt() ?? 0,
        longestRunBouts: (json['longestRunBouts'] as num?)?.toInt() ?? 0,
        heaviestBlow: (json['heaviestBlow'] as num?)?.toInt() ?? 0,
      );
}

class RecordsRepository {
  RecordsRepository(this._store)
      : _snapshot = RecordsSnapshot._fromJson(_store.read(_kKey));

  final GameStore _store;
  RecordsSnapshot _snapshot;

  RecordsSnapshot get snapshot => _snapshot;

  /// A run was carried to its hard fight and won.
  Future<void> recordRunCleared({
    required int runNumber,
    required int bouts,
  }) =>
      _update(_snapshot._copyWith(
        runsCleared: _snapshot.runsCleared + 1,
        furthestRun: _max(_snapshot.furthestRun, runNumber),
        longestRunBouts: _max(_snapshot.longestRunBouts, bouts),
      ));

  /// A run ended with the fighter down.
  Future<void> recordRunEnded({
    required int runNumber,
    required int bouts,
  }) =>
      _update(_snapshot._copyWith(
        furthestRun: _max(_snapshot.furthestRun, runNumber),
        longestRunBouts: _max(_snapshot.longestRunBouts, bouts),
      ));

  /// The single largest hit seen in a fight just replayed.
  Future<void> recordBlow(int amount) async {
    if (amount <= _snapshot.heaviestBlow) return;
    await _update(_snapshot._copyWith(heaviestBlow: amount));
  }

  Future<void> _update(RecordsSnapshot next) {
    _snapshot = next;
    return _store.write(_kKey, next._toJson());
  }

  static int _max(int a, int b) => a > b ? a : b;
}
