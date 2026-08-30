// lib/features/tome/tome_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/character_adapter.dart';
import '../../core/engine/item_adapter.dart';
import '../../core/engine/technique_adapter.dart';
import '../../core/engine/tome_adapter.dart';
import 'tome_event.dart';
import 'tome_state.dart';

export 'tome_state.dart';

class TomeBloc extends Bloc<TomeEvent, TomeState> {
  TomeBloc({
    required TomeAdapter tomeAdapter,
    required ItemAdapter itemAdapter,
    required CharacterAdapter characterAdapter,
    required TechniqueAdapter techniqueAdapter,
  }) : _tomeAdapter = tomeAdapter,
       _itemAdapter = itemAdapter,
       _characterAdapter = characterAdapter,
       _techniqueAdapter = techniqueAdapter,
       super(const TomeState()) {
    on<TomeRefreshRequested>((event, emit) => emit(_snapshot()));
    on<FirstRunCalloutDismissed>((event, emit) {
      _calloutDismissed = true;
      emit(_snapshot());
    });
    on<ComponentMoved>((event, emit) {
      _tomeAdapter.move(event.fromSlotId, event.toSlotId);
      emit(_snapshot());
    });
    on<ComponentRemoved>((event, emit) {
      _tomeAdapter.remove(event.slotId);
      emit(_snapshot());
    });
    on<ComponentUpgraded>((event, emit) {
      _itemAdapter.spendUpgradePoint(event.definitionId);
      emit(_snapshot());
    });
    on<CombineRequested>((event, emit) {
      final result = _itemAdapter.combine(event.instanceEntityValues);
      _lastCombine = CombineOutcome(
        kind: result.kind,
        resultName: result.resultingDefinitionId,
        resultClass: result.resultingItemClass,
        seq: ++_combineSeq,
      );
      emit(_snapshot());
    });
    on<ComponentInserted>((event, emit) {
      if (event.isTechnique) {
        _tomeAdapter.insertTechnique(event.definitionId, event.slotId);
      } else if (event.instanceEntityValue != null) {
        _tomeAdapter.placeOwnedItem(
          event.definitionId,
          event.instanceEntityValue!,
          event.slotId,
        );
      } else {
        _tomeAdapter.insertItem(event.definitionId, event.slotId);
      }
      emit(_snapshot());
    });
  }

  final TomeAdapter _tomeAdapter;
  final ItemAdapter _itemAdapter;
  final CharacterAdapter _characterAdapter;
  final TechniqueAdapter _techniqueAdapter;

  bool _calloutDismissed = false;
  Set<int>? _prevOwned;
  int _combineSeq = 0;
  CombineOutcome? _lastCombine;

  TomeState _snapshot() {
    final owned = _itemAdapter.ownedItems();
    final cells = _tomeAdapter.inspect();

    final placedInstanceValues = <int?>{
      for (final cell in cells)
        if (cell.occupant?.instanceEntityValue != null)
          cell.occupant!.instanceEntityValue,
    };
    final placedTechniqueIds = <String>{
      for (final cell in cells)
        if (cell.occupant != null && cell.occupant!.instanceEntityValue == null)
          cell.occupant!.contentId,
    };

    final ownedValues = <int>{
      for (final v in owned)
        if (v.instanceEntityValue != null) v.instanceEntityValue!,
    };
    // First snapshot establishes the baseline; the starting kit is never
    // "new". After that, anything freshly owned is spotlighted.
    final spotlight =
        _prevOwned == null
            ? const <int>{}
            : ownedValues.difference(_prevOwned!);
    _prevOwned = ownedValues;

    final allTechniques = _techniqueAdapter.discoveredTechniques();
    final trayTechniques = [
      for (final t in allTechniques)
        if (!placedTechniqueIds.contains(t.definitionId)) t,
    ];

    return TomeState(
      cells: cells,
      tray: [
        for (final v in owned)
          if (!placedInstanceValues.contains(v.instanceEntityValue)) v,
      ],
      trayTechniques: trayTechniques,
      techniquesByContentId: {for (final t in allTechniques) t.definitionId: t},
      width: _tomeAdapter.width,
      height: _tomeAdapter.height,
      ownedByInstanceValue: {
        for (final v in owned)
          if (v.instanceEntityValue != null) v.instanceEntityValue!: v,
      },
      character: _characterAdapter.currentView(),
      spotlightInstanceValues: spotlight,
      showFirstRunCallout: !_calloutDismissed && cells.any((c) => !c.isEmpty),
      lastCombine: _lastCombine,
      upgradePoints: _itemAdapter.upgradePoints(),
    );
  }
}
