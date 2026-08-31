import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/tome_app.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/features/run/run_bloc.dart';
import 'package:tome_client/features/run/run_event.dart';

void main() {
  testWidgets('NEW RUN rebuilds the EngineSession; cross-run repos survive it',
      (tester) async {
    final runBloc = RunBloc();
    addTearDown(runBloc.close);
    // No pinned session → TomeApp derives it from RunState.sessionSeed.
    await tester.pumpWidget(TomeApp(runBloc: runBloc, store: GameStore.memory()));
    await tester.pumpAndSettle();

    EngineSession sessionOf() => tester
        .element(find.byType(MaterialApp))
        .read<EngineSession>();
    GameStore storeOf() =>
        tester.element(find.byType(MaterialApp)).read<GameStore>();

    final before = sessionOf();
    final storeBefore = storeOf();

    runBloc.add(const NewRunRequested());
    await tester.pumpAndSettle();

    final after = sessionOf();
    expect(identical(before, after), isFalse,
        reason: 'a fresh fighter/build/RNG for the new run');
    expect(identical(storeBefore, storeOf()), isTrue,
        reason: 'Records / Codex / Settings persist across NEW RUN');
  });
}
