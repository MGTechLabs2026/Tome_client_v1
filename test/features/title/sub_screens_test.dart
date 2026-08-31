import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/theme.dart';
import 'package:tome_client/core/persistence/codex_repository.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/core/persistence/records_repository.dart';
import 'package:tome_client/core/persistence/settings_repository.dart';
import 'package:tome_client/features/title/almanac_screen.dart';
import 'package:tome_client/features/title/records_screen.dart';
import 'package:tome_client/features/title/settings_screen.dart';

Widget _host(GameStore store, Widget child) => MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => RecordsRepository(store)),
        RepositoryProvider(create: (_) => CodexRepository(store)),
        RepositoryProvider(create: (_) => SettingsRepository(store)),
      ],
      child: MaterialApp(theme: tomeTheme(), home: child),
    );

void main() {
  testWidgets('RECORDS renders em-dashes on an empty ledger', (tester) async {
    await tester.pumpWidget(_host(GameStore.memory(), const RecordsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('RECORDS'), findsOneWidget);
    expect(find.text('Runs cleared'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('RECORDS shows a stored figure', (tester) async {
    final store = GameStore.memory();
    await RecordsRepository(store).recordRunCleared(runNumber: 3, bouts: 5);
    await tester.pumpWidget(_host(store, const RecordsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget); // runs cleared
    expect(find.text('3'), findsOneWidget); // furthest run
  });

  testWidgets('ALMANAC renders the three groups and a met count', (tester) async {
    final store = GameStore.memory();
    await CodexRepository(store).discover(CodexKind.style, 'kunlun');
    await tester.pumpWidget(_host(store, const AlmanacScreen()));
    await tester.pumpAndSettle();

    expect(find.text('ALMANAC'), findsOneWidget);
    expect(find.text('STYLES'), findsOneWidget);
    expect(find.text('ITEMS'), findsOneWidget);
    expect(find.text('TECHNIQUES'), findsOneWidget);
    expect(find.textContaining(' of '), findsOneWidget); // "1 of 22 met"
  });

  testWidgets('SETTINGS toggle flips and persists', (tester) async {
    final store = GameStore.memory();
    await tester.pumpWidget(_host(store, const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('Reduce motion'), findsOneWidget);

    await tester.tap(find.text('Reduce motion'));
    await tester.pumpAndSettle();

    // A fresh repository over the same store sees the persisted value.
    expect(SettingsRepository(store).reduceMotion.value, isTrue);
  });
}
