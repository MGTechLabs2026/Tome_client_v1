// lib/features/tome/hall/board_drag.dart
//
// What travels between a rack piece / a placed mount and a target cell.
import '../../../core/models/grid_cell_view.dart';

enum DragKind { move, placeItem, placeTechnique }

class TomeDrag {
  const TomeDrag._(
    this.kind, {
    this.fromSlotId,
    this.definitionId,
    this.instanceEntityValue,
    this.componentKind,
  });

  /// Relocating a placed mount.
  factory TomeDrag.fromSlot(String slotId) =>
      TomeDrag._(DragKind.move, fromSlotId: slotId);

  /// A loose owned item from the rack.
  factory TomeDrag.rackItem(String definitionId, int instanceEntityValue) =>
      TomeDrag._(
        DragKind.placeItem,
        definitionId: definitionId,
        instanceEntityValue: instanceEntityValue,
        componentKind: GridComponentKind.item,
      );

  /// A loose discovered technique from the rack.
  factory TomeDrag.rackTechnique(String definitionId) => TomeDrag._(
    DragKind.placeTechnique,
    definitionId: definitionId,
    componentKind: GridComponentKind.technique,
  );

  final DragKind kind;
  final String? fromSlotId;
  final String? definitionId;
  final int? instanceEntityValue;
  final GridComponentKind? componentKind;

  bool get isMove => kind == DragKind.move;
  bool get isTechnique => kind == DragKind.placeTechnique;
}
