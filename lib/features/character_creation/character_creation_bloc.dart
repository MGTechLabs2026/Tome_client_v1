// lib/features/character_creation/character_creation_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/character_adapter.dart';
import 'character_creation_event.dart';
import 'character_creation_state.dart';

export 'character_creation_state.dart';

class CharacterCreationBloc extends Bloc<CharacterCreationEvent, CharacterCreationState> {
  CharacterCreationBloc(this._adapter) : super(const CharacterCreationState()) {
    on<NameSubmitted>((event, emit) {
      final character = _adapter.createCharacter(event.name);
      final styles = _adapter.availableStyles();
      emit(state.copyWith(
        name: event.name,
        character: character,
        availableStyles: styles,
        synergyByStyle: {for (final s in styles) s: _adapter.synergyTraditionFor(s)},
      ));
    });

    on<StyleChosen>((event, emit) {
      final character = _adapter.chooseStyle(event.styleId);
      emit(state.copyWith(character: character, confirmed: true));
    });
  }

  final CharacterAdapter _adapter;
}
