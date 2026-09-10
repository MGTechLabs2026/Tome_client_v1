// ALMANAC screen — the data-driven reference ledger.
//
// Covers: completion is codex ∩ current roster; an empty codex reads
// `0 / N` with everything locked; a locked entry never leaks its name
// (only its structural axis); the panel is master–detail, wide and
// narrow; and the screen imports no build_engine type.
import 'dart:io';

import 'package:build_engine/almanac.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/theme.dart';
import 'package:tome_client/core/engine/almanac_session.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/persistence/codex_repository.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/core/persistence/game_store_almanac_repository.dart';
import 'package:tome_client/features/title/almanac_screen.dart';

Widget _host(GameStore store, {AlmanacSession? almanac}) =>
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<EngineSession>(create: (_) => EngineSession(1)),
        RepositoryProvider<CodexRepository>(create: (_) => CodexRepository(store)),
        RepositoryProvider<AlmanacSession>(
          create: (_) =>
              almanac ?? AlmanacSession(GameStoreAlmanacRepository(store)),
        ),
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

  testWidgets('AFFIXES group renders with recorded / canonical completion',
      (tester) async {
    await _pump(tester, GameStore.memory(), size: const Size(560, 900));

    final roster = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('AFFIXES'), 300,
        scrollable: roster);

    expect(find.text('AFFIXES'), findsOneWidget);
    // empty almanac -> 0 of the 33 canonical affixes recorded
    expect(find.text('0 / 33'), findsOneWidget);
  });

  testWidgets('a locked affix leaks no name / stat / value — UI or semantics',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, GameStore.memory(), size: const Size(560, 900));

    final roster = find.byType(Scrollable).last;
    // locked affix plates show the category axis only, e.g. 'item prefix'
    await tester.scrollUntilVisible(find.text('AFFIXES'), 300,
        scrollable: roster);
    // a little further so a locked item-prefix plate sits clear of the fold
    await tester.drag(roster, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(find.text('item prefix'), findsWidgets);

    // no affix name / magnitude / raw stat token, anywhere in the roster
    expect(find.textContaining('Keen'), findsNothing);
    expect(find.textContaining('Brutal'), findsNothing);
    expect(find.textContaining('Plain'), findsNothing);
    expect(find.textContaining('+1'), findsNothing);
    expect(find.textContaining('weapon_stat_bonus'), findsNothing);
    // ...nor in the semantics tree — the locked plate says only its axis
    expect(find.bySemanticsLabel(RegExp('Keen|Brutal|Plain')), findsNothing);
    expect(find.bySemanticsLabel('Locked affix. item prefix'), findsWidgets);

    // opening one still reveals only the axis, never a name/stat/value
    final lockedPlate = find
        .ancestor(
          of: find.text('item prefix').first,
          matching: find.byType(GestureDetector),
        )
        .first;
    await tester.tap(lockedPlate, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('has not been met'), findsOneWidget);
    expect(find.textContaining('item prefix'), findsWidgets);
    expect(find.textContaining('Keen'), findsNothing);
    expect(find.textContaining('Brutal'), findsNothing);
    expect(find.textContaining('weapon_stat_bonus'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Keen|Brutal|Plain')), findsNothing);

    handle.dispose();
  });

  testWidgets('a recorded affix opens a leaf with its label + effect',
      (tester) async {
    final store = GameStore.memory();
    final almanac = AlmanacSession(GameStoreAlmanacRepository(store));
    almanac.recorder.recordAffixDiscovered(
      affixId: 'af_keen',
      observation: const AffixObservation(
          affixEventId: '13:1:affix:0:0', runId: '13:1', runNumber: 1),
      snapshot: const AffixSnapshot(
          affixId: 'af_keen',
          stat: 'weapon_stat_bonus',
          value: 3,
          category: 'item_prefix'),
      timestamp: DateTime.utc(2026),
    );

    await tester.binding.setSurfaceSize(const Size(560, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(store, almanac: almanac));
    await tester.pumpAndSettle();

    final roster = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Keen'), 300, scrollable: roster);
    expect(find.text('Keen'), findsOneWidget); // roster plate label

    await tester.tap(find.text('Keen'));
    await tester.pumpAndSettle();

    expect(find.text('ITEM PREFIX'), findsOneWidget); // _LeafTitle badge
    expect(find.text('Weapon stat'), findsOneWidget); // effect label
    expect(find.text('3'), findsWidgets); // the effect value
  });
}
