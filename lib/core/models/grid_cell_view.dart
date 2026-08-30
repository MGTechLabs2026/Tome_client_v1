enum GridComponentKind { item, technique }

class GridCellView {
  const GridCellView({
    required this.slotId,
    required this.row,
    required this.col,
    this.occupant,
  });

  final String slotId;
  final int row;
  final int col;
  final GridCellOccupant? occupant;

  bool get isEmpty => occupant == null;
}

class GridCellOccupant {
  const GridCellOccupant({
    required this.kind,
    required this.contentId,
    required this.displayName,
    this.instanceEntityValue,
  });

  final GridComponentKind kind;
  final String contentId;
  final String displayName;

  /// The owning `ItemInstance` entity's raw id (`EntityId.value`), for
  /// item occupants only — used to detect same-definitionId/same-class
  /// combine matches without leaking `EntityId` itself past core/engine.
  final int? instanceEntityValue;
}
