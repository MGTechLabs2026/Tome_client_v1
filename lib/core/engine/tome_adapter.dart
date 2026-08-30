import 'package:build_engine/build_engine.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/technique_plugin.dart';

import '../models/grid_cell_view.dart';
import 'engine_session.dart';

/// Owns the client's own real spatial 3x3 Tome grid, built via the
/// engine's generic `TomeDefinition.grid`/`Container.grid` — not the
/// flat 999-slot list the engine's own reference game uses. A true
/// spatial grid is central to this client's UX (see the design spec),
/// so this adapter deliberately does not reuse that reference layout.
class TomeAdapter {
  TomeAdapter(this._session);

  final EngineSession _session;

  static const _tomeId = 'client_tome';
  int _width = 3;
  int _height = 3;
  var _generation = 0;

  int get width => _width;
  int get height => _height;

  /// Defines and creates a 3x3 grid Tome for the current character.
  /// Called once, right after character creation. The starting kit is a
  /// separate step ([grantStartingKit]) so adapter/bloc tests can work
  /// against a bare grid.
  void createInitialTome() {
    _defineAndCreate(_width, _height);
  }

  /// Grants the run's opening components: the knife is hung centre
  /// (usable with no mastery gate); the cloth armour is owned +
  /// discovered but stays in the loose rack until trained past its
  /// mastery threshold — `addItemToTome` will not hang a locked item.
  void grantStartingKit() {
    insertItem('knife', '1,1');
    final cloth = itemDefinition('cloth_armor', _session.context);
    if (!isItemOwned(_session.character, 'cloth_armor', _session.context)) {
      ownItem(_session.character, 'cloth_armor', _session.context);
      discoverItem(_session.character, cloth, _session.context);
    }
  }

  void _defineAndCreate(int width, int height) {
    _generation++;
    final definitionId = '$_tomeId#$_generation';
    _session.context.tome.defineTome(
      TomeDefinition.grid(id: definitionId, width: width, height: height),
    );
    _session.context.tome.createTome(_session.character, definitionId);
  }

  List<GridCellView> inspect() {
    final placements = {
      for (final p in _session.context.tome.inspect(_session.character))
        p.slot.id: p,
    };
    final cells = <GridCellView>[];
    for (var row = 0; row < _height; row++) {
      for (var col = 0; col < _width; col++) {
        final slotId = '$row,$col';
        final placement = placements[slotId];
        cells.add(
          GridCellView(
            slotId: slotId,
            row: row,
            col: col,
            occupant:
                placement == null
                    ? null
                    : _occupantFor(placement.buildComponentRef),
          ),
        );
      }
    }
    return cells;
  }

  GridCellOccupant _occupantFor(BuildComponentRef ref) {
    if (ref.referenceType == itemReferenceType) {
      final item = itemDefinition(ref.contentId, _session.context);
      return GridCellOccupant(
        kind: GridComponentKind.item,
        contentId: item.id,
        displayName: item.id,
        instanceEntityValue: ref.instanceEntityId?.value,
      );
    }
    final technique = techniqueDefinition(ref.contentId, _session.context);
    return GridCellOccupant(
      kind: GridComponentKind.technique,
      contentId: technique.id,
      displayName: technique.name,
    );
  }

  /// Places [definitionId] at [slotId]. If [instanceEntityId] is omitted
  /// and the character doesn't already own a copy, owns+discovers one
  /// first (the starting-kit / reward-grant path); if a specific owned
  /// copy's entity id is already known (e.g. from `ItemAdapter`'s combine
  /// flow), pass it directly instead of minting a new one.
  void insertItem(
    String definitionId,
    String slotId, {
    EntityId? instanceEntityId,
  }) {
    final item = itemDefinition(definitionId, _session.context);
    var instance = instanceEntityId;
    if (instance == null) {
      final alreadyOwned = isItemOwned(
        _session.character,
        definitionId,
        _session.context,
      );
      if (!alreadyOwned) {
        instance = ownItem(_session.character, definitionId, _session.context);
        discoverItem(_session.character, item, _session.context);
      }
    }
    addItemToTome(
      _session.character,
      SlotId(slotId),
      item,
      _session.context,
      instanceEntityId: instance,
    );
  }

  /// Places an already-owned item instance (identified by its raw
  /// `EntityId.value`, the only handle the UI holds) at [slotId] — the
  /// tray-to-grid drop path, where the copy exists and must not be
  /// re-minted.
  void placeOwnedItem(
    String definitionId,
    int instanceEntityValue,
    String slotId,
  ) {
    insertItem(
      definitionId,
      slotId,
      instanceEntityId: EntityId(instanceEntityValue),
    );
  }

  void insertTechnique(String definitionId, String slotId) {
    final technique = techniqueDefinition(definitionId, _session.context);
    addTechniqueToTome(
      _session.character,
      SlotId(slotId),
      technique,
      _session.context,
    );
  }

  void remove(String slotId) =>
      _session.context.tome.remove(_session.character, SlotId(slotId));

  void move(String fromSlotId, String toSlotId) => _session.context.tome.move(
    _session.character,
    SlotId(fromSlotId),
    SlotId(toSlotId),
  );

  /// No engine primitive grows a live `Container` (`ARCHITECTURE.md`'s
  /// Tome section — a `Container` is fixed-size once built), so a grid
  /// expansion builds a brand-new, wider `TomeDefinition`, creates a
  /// fresh `TomeInstance` from it (this replaces the character's Tome
  /// component — see `TomeService.createTome`'s own "overwrites any
  /// existing Tome" doc comment), and replays every existing placement
  /// back in at the same `row,col` coordinates (still valid, since the
  /// new grid is only ever wider/taller, never smaller).
  ///
  /// The old grid's placements are explicitly [TomeService.remove]d
  /// *before* the new `TomeInstance` is created — `remove` is the only
  /// path that destroys a placement's placeholder entity and its
  /// `BuildComponentRef` component (`TomeService.insert` mints both;
  /// `createTome` just overwrites the `TomeInstance` component and would
  /// otherwise silently orphan them). This must happen while the old
  /// `TomeInstance` is still attached — `TomeService.remove` resolves
  /// via `tomeOf(owner)`, so it has to run before `_defineAndCreate`
  /// swaps that component out from under it.
  void expandGrid({int addWidth = 1, int addHeight = 0}) {
    final existing = _session.context.tome.inspect(_session.character);
    for (final placement in existing) {
      _session.context.tome.remove(_session.character, placement.slot);
    }
    _defineAndCreate(_width + addWidth, _height + addHeight);
    _width += addWidth;
    _height += addHeight;
    for (final placement in existing) {
      _session.context.tome.insert(
        _session.character,
        placement.slot,
        placement.buildComponentRef,
      );
    }
  }
}
