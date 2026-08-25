import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/models/game_phase.dart';

void main() {
  test('GamePhase has one variant per milestone phase', () {
    const phases = <GamePhase>[
      GamePhase.characterCreation,
      GamePhase.tome,
      GamePhase.trainingPreparation,
      GamePhase.training,
      GamePhase.trainingResult,
      GamePhase.combatPreparation,
      GamePhase.combat,
      GamePhase.loot,
      GamePhase.runComplete,
    ];
    expect(phases.toSet().length, 9);
  });
}
