// test/core/engine/reward_affix_test.dart
import 'package:build_engine/build_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/reward_affix.dart';

void main() {
  test('every affix roster is populated and self-describing', () {
    for (final pool in [
      itemPrefixes,
      itemSuffixes,
      techniquePrefixes,
      techniqueSuffixes,
    ]) {
      expect(pool, isNotEmpty);
      for (final a in pool) {
        expect(a.label.trim(), isNotEmpty);
        expect(a.blurb.trim(), isNotEmpty);
        expect(a.lean, isIn(AffixLean.values));
      }
      // each roster has at least one of each lean so weighting has an effect
      expect(pool.map((a) => a.lean).toSet(),
          containsAll([AffixLean.neutral, AffixLean.force, AffixLean.flow]));
    }
  });

  Map<AffixLean, int> tally(String affinity, int seed) {
    final rng = RngService(seed);
    final counts = {for (final l in AffixLean.values) l: 0};
    for (var i = 0; i < 6000; i++) {
      final a = rollAffix(itemPrefixes, affinity, rng);
      counts[a.lean] = counts[a.lean]! + 1;
    }
    return counts;
  }

  test('a western-affinity physique leans Force', () {
    final c = tally('western', 1);
    expect(c[AffixLean.force]!, greaterThan(c[AffixLean.flow]!));
  });

  test('an eastern-affinity physique leans Flow', () {
    final c = tally('eastern', 2);
    expect(c[AffixLean.flow]!, greaterThan(c[AffixLean.force]!));
  });

  test('no physique affinity: Force and Flow come up about the same', () {
    final c = tally('', 3);
    final f = c[AffixLean.force]!;
    final w = c[AffixLean.flow]!;
    expect((f - w).abs() / (f + w), lessThan(0.25));
  });
}
