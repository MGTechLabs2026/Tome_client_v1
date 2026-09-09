// test/features/title/settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/core/persistence/settings_repository.dart';
import 'package:tome_client/features/title/settings_screen.dart';
import 'package:tome_client/app/theme.dart';

Widget _host(SettingsRepository settings) => RepositoryProvider.value(
      value: settings,
      child: MaterialApp(theme: tomeTheme(), home: const SettingsScreen()),
    );

void main() {
  testWidgets('toggling "Sound effects" calls setSoundEnabled', (tester) async {
    final settings = SettingsRepository(GameStore.memory());
    await tester.pumpWidget(_host(settings));

    expect(settings.soundEnabled.value, isTrue);
    await tester.tap(find.text('Sound effects'));
    await tester.pump();
    expect(settings.soundEnabled.value, isFalse);
  });

  testWidgets('the volume slider drives setSoundVolume and disables when off',
      (tester) async {
    final settings = SettingsRepository(GameStore.memory());
    await tester.pumpWidget(_host(settings));

    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);
    expect(tester.widget<Slider>(slider).onChanged, isNotNull);

    await tester.tap(find.text('Sound effects')); // turn off
    await tester.pump();
    expect(tester.widget<Slider>(slider).onChanged, isNull,
        reason: 'slider is inert while sound is off');
  });
}
