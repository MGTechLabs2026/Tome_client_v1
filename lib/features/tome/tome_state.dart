// lib/features/tome/tome_state.dart
import '../../core/models/character_view.dart';
import '../../core/models/combine_result_view.dart';
import '../../core/models/grid_cell_view.dart';
import '../../core/models/item_view.dart';
import '../../core/models/technique_view.dart';

/// The result of the most recent Combine, for the one-time seal-press
/// reveal. [seq] increments per combine so the screen can tell a fresh
/// result from a rebuild.
class CombineOutcome {
  const CombineOutcome({
    required this.kind,
    required this.resultName,
    required this.resultClass,
    required this.seq,
  });
  final CombineResultKind kind;
  final String resultName;
  final int resultClass;
  final int seq;
}

class TomeState {
  const TomeState({
    this.cells = const [],
    this.tray = const [],
    this.trayTechniques = const [],
    this.techniquesByContentId = const {},
    this.width = 3,
    this.height = 3,
    this.ownedByInstanceValue = const {},
    this.character,
    this.spotlightInstanceValues = const {},
    this.showFirstRunCallout = false,
    this.lastCombine,
    this.upgradePoints = 0,
  });

  final List<GridCellView> cells;

  /// Loose (owned but unplaced) items in the rack.
  final List<ItemView> tray;

  /// Loose (discovered but unplaced) techniques in the rack.
  final List<TechniqueView> trayTechniques;

  /// Every discovered technique by definition id (placed or loose) — the
  /// board's detail-sheet lookup for a placed technique.
  final Map<String, TechniqueView> techniquesByContentId;

  final int width;
  final int height;

  /// Every owned item's `instanceEntityValue` → its [ItemView] (tray and
  /// placed alike) — the combine-tether overlay's lookup table.
  final Map<int, ItemView> ownedByInstanceValue;

  /// The run's character, for the frontispiece.
  final CharacterView? character;

  /// Instance values that entered the player's possession since the last
  /// snapshot — the "returned from Loot with something new" spotlight.
  final Set<int> spotlightInstanceValues;

  /// True until the player dismisses the one-time starting-kit callout.
  final bool showFirstRunCallout;

  /// The most recent Combine's outcome, for the seal-press reveal.
  final CombineOutcome? lastCombine;

  /// Banked upgrade points — the foot-bar tally.
  final int upgradePoints;
}
