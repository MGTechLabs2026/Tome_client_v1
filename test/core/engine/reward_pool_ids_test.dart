// test/core/engine/reward_pool_ids_test.dart
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/technique_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/tome_app.dart';
import 'package:tome_client/core/engine/engine_session.dart';

/// Content Expansion V1, matrix §J (client half): every id the reward
/// weighter can roll must resolve in the engine's loaded content —
/// otherwise a grown pool silently offers a card that crashes on apply.
void main() {
  late EngineSession session;

  setUp(() => session = EngineSession(1));

  test('every kRewardItemPool id is a real engine item', () {
    for (final id in kRewardItemPool) {
      expect(() => itemDefinition(id, session.context), returnsNormally,
          reason: '$id is in kRewardItemPool but not registered content');
    }
  });

  test('every kRewardTechniquePool id is a real engine technique', () {
    for (final id in kRewardTechniquePool) {
      expect(() => techniqueDefinition(id, session.context), returnsNormally,
          reason: '$id is in kRewardTechniquePool but not registered content');
    }
  });

  test('the reward pools hold no duplicates', () {
    expect(kRewardItemPool.toSet(), hasLength(kRewardItemPool.length));
    expect(kRewardTechniquePool.toSet(), hasLength(kRewardTechniquePool.length));
  });
}
