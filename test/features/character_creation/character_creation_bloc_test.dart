// test/features/character_creation/character_creation_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:build_engine/martial_arts_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/features/character_creation/character_creation_bloc.dart';
import 'package:tome_client/features/character_creation/character_creation_event.dart';

void main() {
  late CharacterAdapter adapter;

  setUp(() {
    adapter = CharacterAdapter(EngineSession(21));
  });

  blocTest<CharacterCreationBloc, CharacterCreationState>(
    'NameSubmitted then StyleChosen produces a confirmed character',
    build: () => CharacterCreationBloc(adapter),
    act: (bloc) {
      bloc.add(const NameSubmitted('Test Fighter'));
      bloc.add(const StyleChosen(MartialStyles.boxing));
    },
    verify: (bloc) {
      expect(bloc.state.confirmed, isTrue);
      expect(bloc.state.character!.name, 'Test Fighter');
      expect(bloc.state.character!.styleId, MartialStyles.boxing);
    },
  );
}
