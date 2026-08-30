// lib/features/tome/tome_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/item_adapter.dart';
import '../../core/engine/tome_adapter.dart';
import 'tome_event.dart';
import 'tome_state.dart';

export 'tome_state.dart';

class TomeBloc extends Bloc<TomeEvent, TomeState> {
  TomeBloc({required TomeAdapter tomeAdapter, required ItemAdapter itemAdapter})
      : _tomeAdapter = tomeAdapter,
        _itemAdapter = itemAdapter,
        super(const TomeState()) {
    on<TomeRefreshRequested>((event, emit) => emit(_snapshot()));
    on<ComponentMoved>((event, emit) {
      _tomeAdapter.move(event.fromSlotId, event.toSlotId);
      emit(_snapshot());
    });
    on<CombineRequested>((event, emit) {
      _itemAdapter.combine(event.instanceEntityValues);
      emit(_snapshot());
    });
    on<ComponentInserted>((event, emit) {
      if (event.isTechnique) {
        _tomeAdapter.insertTechnique(event.definitionId, event.slotId);
      } else {
        _tomeAdapter.insertItem(event.definitionId, event.slotId);
      }
      emit(_snapshot());
    });
  }

  final TomeAdapter _tomeAdapter;
  final ItemAdapter _itemAdapter;

  TomeState _snapshot() {
    final owned = _itemAdapter.ownedItems();
    final cells = _tomeAdapter.inspect();
    final placedInstanceValues = {
      for (final cell in cells)
        if (cell.occupant?.instanceEntityValue != null) cell.occupant!.instanceEntityValue,
    };
    return TomeState(
      cells: cells,
      tray: [
        for (final v in owned)
          if (!placedInstanceValues.contains(v.instanceEntityValue)) v,
      ],
      width: _tomeAdapter.width,
      height: _tomeAdapter.height,
      ownedByInstanceValue: {
        for (final v in owned)
          if (v.instanceEntityValue != null) v.instanceEntityValue!: v,
      },
    );
  }
}
