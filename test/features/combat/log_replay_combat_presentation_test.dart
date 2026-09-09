// test/features/combat/log_replay_combat_presentation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/theme.dart';
import 'package:tome_client/core/models/combat_log_entry_view.dart';
import 'package:tome_client/core/platform/game_audio.dart';
import 'package:tome_client/features/combat/presentation/log_replay_combat_presentation.dart';

import '../../support/fake_game_audio.dart';

void main() {
  testWidgets('plays each revealed entry\'s cue and stopAll on dispose',
      (tester) async {
    final audio = FakeGameAudio();
    const log = [
      CombatLogEntryView(
          kind: CombatLogEntryKind.damage, text: 'a', cue: SoundCue.strikeWeapon,
          playerHp: 10, playerHpMax: 10, enemyHp: 8, enemyHpMax: 10),
      CombatLogEntryView(kind: CombatLogEntryKind.turnStart, text: 'b'),
      CombatLogEntryView(
          kind: CombatLogEntryKind.victory, text: 'c', cue: SoundCue.fightWon,
          playerHp: 10, playerHpMax: 10, enemyHp: 0, enemyHpMax: 10),
    ];

    await tester.pumpWidget(RepositoryProvider<GameAudio>.value(
      value: audio,
      child: MaterialApp(
        theme: tomeTheme(),
        home: Scaffold(
          body: LogReplayCombatPresentation(
            log: log,
            onFinished: () {},
            playerName: 'You',
            enemyName: 'Foe',
          ),
        ),
      ),
    ));

    // Reveal cadence is 400ms.
    await tester.pump(const Duration(milliseconds: 400)); // entry 0
    await tester.pump(const Duration(milliseconds: 400)); // entry 1 (no cue)
    await tester.pump(const Duration(milliseconds: 400)); // entry 2
    expect(audio.played, [SoundCue.strikeWeapon, SoundCue.fightWon]);

    await tester.pumpWidget(const SizedBox()); // dispose
    expect(audio.stopAllCalls, greaterThanOrEqualTo(1));
  });
}
