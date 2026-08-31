import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/models/game_phase.dart';

void main() {
  test('GamePhase has one variant per milestone phase', () {
    const phases = <GamePhase>[
      GamePhase.title,
      GamePhase.characterCreation,
      GamePhase.tome,
      GamePhase.trainingPreparation,
      GamePhase.training,
      GamePhase.trainingResult,
      GamePhase.combatPreparation,
      GamePhase.combat,
      GamePhase.loot,
      GamePhase.defeat,
    ];
    expect(phases.toSet().length, 10);
    expect(GamePhase.values.length, 10);
  });

  test('the app boots on the title screen and defeat is the last phase', () {
    expect(GamePhase.values.first, GamePhase.title);
    expect(GamePhase.values.last, GamePhase.defeat);
  });
}
