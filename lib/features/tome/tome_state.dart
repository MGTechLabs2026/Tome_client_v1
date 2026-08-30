// lib/features/tome/tome_state.dart
import '../../core/models/grid_cell_view.dart';
import '../../core/models/item_view.dart';

class TomeState {
  const TomeState({
    this.cells = const [],
    this.tray = const [],
    this.width = 3,
    this.height = 3,
    this.ownedByInstanceValue = const {},
  });
  final List<GridCellView> cells;
  final List<ItemView> tray;
  final int width;
  final int height;

  /// Every owned item's `instanceEntityValue` → its [ItemView] (tray and
  /// placed alike) — the combine-tether overlay's lookup table.
  final Map<int, ItemView> ownedByInstanceValue;
}
