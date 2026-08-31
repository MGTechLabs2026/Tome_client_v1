import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/features/training/presentation/training_scene.dart';

void main() {
  test('Western lineage selects the Western scene', () {
    expect(TrainingScene.forTradition('western'), isA<WesternScene>());
  });

  test('Eastern lineage selects the Eastern scene', () {
    expect(TrainingScene.forTradition('eastern'), isA<EasternScene>());
  });

  test('an unknown / empty tradition falls back to Western, never crashes', () {
    expect(TrainingScene.forTradition(''), isA<WesternScene>());
    expect(TrainingScene.forTradition('mystery'), isA<WesternScene>());
  });
}
