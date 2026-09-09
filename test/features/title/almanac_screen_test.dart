// ALMANAC screen — the data-driven reference ledger.
//
// Covers: completion is codex ∩ current roster; an empty codex reads
// `0 / N` with everything locked; a locked entry never leaks its name
// (only its structural axis); the panel is master–detail, wide and
// narrow; and the screen imports no build_engine type.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/theme.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/persistence/codex_repository.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/features/title/almanac_screen.dart';

Widget _host(GameStore store) => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<EngineSession>(create: (_) => EngineSession(1)),
        RepositoryProvider<CodexRepository>(create: (_) => CodexRepository(store)),
      ],
      child: MaterialApp(theme: tomeTheme(), home: const AlmanacScreen()),
    );

Future<void> _pump(WidgetTester tester, GameStore store, {Size? size}) async {
  if (size != null) {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(_host(store));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the screen imports no build_engine type', (tester) async {
    final src = File('lib/features/title/almanac_screen.dart').readAsStringSync();
    expect(src.contains('package:build_engine'), isFalse);
  });

  testWidgets('empty codex reads 0 and every group is fully locked',
      (tester) async {
    await _pump(tester, GameStore.memory());

    expect(find.text('ALMANAC'), findsOneWidget);
    expect(find.text('0 / 6'), findsOneWidget); // styles group header
    expect(find.textContaining('met'), findsOneWidget); // overall bar
    expect(find.text('COMPLETE'), findsNothing);

    // Nothing discovered -> no style name is rendered anywhere.
    for (final name in ['Polearming', 'Wrestling', 'Fencing', 'Shaolin',
      'Tai Chi', 'Kunlun']) {
      expect(find.text(name), findsNothing, reason: '$name leaked while locked');
    }
    // ...but the structural axis (tradition) is shown.
    expect(find.text('western'), findsWidgets);
    expect(find.text('eastern'), findsWidgets);
  });

  testWidgets('completion counts only ids still on the roster', (tester) async {
    final store = GameStore.memory();
    final codex = CodexRepository(store);
    await codex.discover(CodexKind.style, 'kunlun');
    await codex.discover(CodexKind.style, 'ghost_style_no_longer_shipped');

    await _pump(tester, store);

    // 1 of the 2 recorded style ids is on the current roster.
    expect(find.text('1 / 6'), findsOneWidget);
    expect(find.text('Kunlun'), findsOneWidget); // now discovered -> named
  });

  testWidgets('wide surface shows roster and detail side by side',
      (tester) async {
    await _pump(tester, GameStore.memory(), size: const Size(1100, 820));

    expect(find.text('STYLES'), findsOneWidget);
    expect(
      find.textContaining('Choose an entry'),
      findsOneWidget,
      reason: 'the detail leaf is present alongside the roster on a wide panel',
    );
  });

  testWidgets('narrow surface opens the detail as an internal page',
      (tester) async {
    final store = GameStore.memory();
    await CodexRepository(store).discover(CodexKind.style, 'shaolin');
    await _pump(tester, store, size: const Size(560, 900));

    // Roster only — no detail leaf yet.
    expect(find.textContaining('Choose an entry'), findsNothing);
    expect(find.text('ALL ENTRIES'), findsNothing);

    await tester.tap(find.text('Shaolin'));
    await tester.pumpAndSettle();

    // Internal detail page, with its own quiet back step.
    expect(find.text('ALL ENTRIES'), findsOneWidget);
    expect(find.textContaining('tradition'), findsWidgets); // badge

    await tester.tap(find.text('ALL ENTRIES'));
    await tester.pumpAndSettle();
    expect(find.text('ALL ENTRIES'), findsNothing);
  });

  testWidgets('a locked entry opens a leaf that reveals only its axis',
      (tester) async {
    await _pump(tester, GameStore.memory(), size: const Size(560, 900));

    await tester.tap(find.text('western').first); // a locked style plate
    await tester.pumpAndSettle();

    expect(find.textContaining('has not been met'), findsOneWidget);
    expect(find.text('Polearming'), findsNothing);
  });
}
