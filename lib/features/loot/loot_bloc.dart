// lib/features/loot/loot_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/reward_adapter.dart';
import 'loot_event.dart';
import 'loot_state.dart';

export 'loot_state.dart';

class LootBloc extends Bloc<LootEvent, LootState> {
  LootBloc(this._adapter) : super(const LootState()) {
    on<LootOffered>((event, emit) => emit(LootState(options: _adapter.offerLoot())));
    on<LootChosen>((event, emit) {
      _adapter.applyLoot(event.kind);
      emit(LootState(options: state.options, applied: true));
    });
  }

  final RewardAdapter _adapter;
}
