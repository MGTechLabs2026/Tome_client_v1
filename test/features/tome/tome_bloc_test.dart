// test/features/tome/tome_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/item_adapter.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/features/tome/tome_bloc.dart';
import 'package:tome_client/features/tome/tome_event.dart';

void main() {
  late EngineSession session;
  late TomeAdapter tomeAdapter;

  setUp(() {
    session = EngineSession(31);
    CharacterAdapter(session).createCharacter('Test Fighter');
    tomeAdapter = TomeAdapter(session)..createInitialTome();
    tomeAdapter.insertItem('knife', '0,0');
  });

  blocTest<TomeBloc, TomeState>(
    'TomeRefreshRequested loads the current grid',
    build: () => TomeBloc(tomeAdapter: tomeAdapter, itemAdapter: ItemAdapter(session)),
    act: (bloc) => bloc.add(const TomeRefreshRequested()),
    verify: (bloc) => expect(bloc.state.cells.where((c) => !c.isEmpty).length, 1),
  );
}
