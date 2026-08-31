// Client-side architecture guardrails. Locks the engine boundary and the
// audit A2/A4 refactor: the client consumes engine domain rules, it does
// not reimplement them.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('no file imports a build_engine src/ private path', () {
    final offenders = [
      for (final f in _dartFiles('lib'))
        if (f.readAsStringSync().contains('package:build_engine/src/')) f.path,
    ];
    expect(offenders, isEmpty,
        reason: 'consume the plugin barrels, never src/: $offenders');
  });

  test('web-safe: lib/ imports no native-only dart libraries', () {
    // The game ships to browsers (itch.io HTML5, Devvit Web). dart:io /
    // dart:ffi / dart:isolate / dart:mirrors have no web implementation.
    final banned = RegExp(
        r'''import\s+['"]dart:(io|ffi|isolate|mirrors|developer|cli)['"]''');
    final offenders = [
      for (final f in _dartFiles('lib'))
        if (banned.hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(offenders, isEmpty,
        reason: 'native-only dart: library in a web build: $offenders');
  });

  test('build_engine is imported only from lib/core/engine/, '
      'lib/core/models/seeded_random.dart, and the documented training_bloc '
      'exception', () {
    const allowed = {
      'lib/core/models/seeded_random.dart',
      'lib/features/training/training_bloc.dart',
    };
    final offenders = [
      for (final f in _dartFiles('lib'))
        if (f.readAsStringSync().contains('package:build_engine/') &&
            !f.path.startsWith('lib/core/engine/') &&
            !allowed.contains(f.path))
          f.path,
    ];
    expect(offenders, isEmpty, reason: 'unexpected engine import site: $offenders');
  });

  group('audit A2 — CombatAdapter consumes StyleCombatRules, does not '
      'reimplement it', () {
    final src = File('lib/core/engine/combat_adapter.dart').readAsStringSync();

    test('uses the engine StyleCombatRules / BurstChainState types', () {
      expect(src, contains('StyleCombatRules'));
      expect(src, contains('BurstChainState'));
    });

    test('no longer references the low-level style-combat vocabulary or a '
        'hand-rolled blade streak', () {
      for (final banned in const [
        'offSpecialtyDamageFactor',
        'styleAlignedFamilies',
        'recognisedFamilyTags',
        '_bladeStreak',
        'double offSpec(',
      ]) {
        expect(src, isNot(contains(banned)),
            reason: 'CombatAdapter must not restate "$banned"');
      }
    });
  });

  test('audit A4 — TrainingAdapter does not publish TechniqueEvolved itself', () {
    final src = File('lib/core/engine/training_adapter.dart').readAsStringSync();
    expect(src, isNot(contains('publish(')),
        reason: 'the engine publishes TechniqueEvolved from '
            'resolveTechniqueEvolutionAfterTraining, not the client');
    expect(src, contains('resolveTechniqueEvolutionAfterTraining'));
  });
}
