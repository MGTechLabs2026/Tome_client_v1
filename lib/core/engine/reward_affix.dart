// lib/core/engine/reward_affix.dart
//
// The prefix (quality) + suffix (effect) rolled onto a New Component
// reward. Both are real: on TAKE, `RewardAdapter` turns each Affix into
// an engine Modifier / effect on the character. The draw is weighted
// toward the fighter's physique — a western-affinity physique leans
// Force, an eastern one leans Flow; Neutral affixes are always in play.
import 'package:build_engine/build_engine.dart';

enum AffixLean { neutral, force, flow }

/// What an Affix does when the card is taken.
enum AffixEffect {
  /// `+amount` to the reward's primary combat stat.
  statUp,

  /// `+amount` initiative — the fighter acts sooner.
  initiativeUp,

  /// Restore `amount` vitality immediately.
  healNow,

  /// Bank `amount` extra upgrade points.
  bankPoint,
}

class Affix {
  const Affix(this.label, this.lean, this.effect, this.amount, this.blurb);

  /// "Keen" / "of the Ember" — rendered straight into the card title.
  final String label;
  final AffixLean lean;
  final AffixEffect effect;
  final int amount;

  /// One line for the card's effect list, e.g. "well-kept — bite +2".
  final String blurb;
}

// ── Item (card) affixes ──────────────────────────────────────────────

const itemPrefixes = <Affix>[
  Affix('Plain', AffixLean.neutral, AffixEffect.statUp, 1, 'unremarkable — bite +1'),
  Affix('Sturdy', AffixLean.neutral, AffixEffect.statUp, 2, 'well-made — bite +2'),
  Affix('Keen', AffixLean.neutral, AffixEffect.statUp, 3, 'sharp and true — bite +3'),
  Affix('Tempered', AffixLean.neutral, AffixEffect.statUp, 3, 'quench-hardened — bite +3'),
  Affix('Masterwork', AffixLean.neutral, AffixEffect.statUp, 5, "a smith's best — bite +5"),
  Affix('Heavy', AffixLean.force, AffixEffect.statUp, 4, 'built to break things — bite +4'),
  Affix('Brutal', AffixLean.force, AffixEffect.statUp, 5, 'no finesse, all force — bite +5'),
  Affix('Ember-Forged', AffixLean.force, AffixEffect.statUp, 6, 'forged in coal-heat — bite +6'),
  Affix('Swift', AffixLean.flow, AffixEffect.initiativeUp, 2, 'light in the hand — act sooner (+2)'),
  Affix('Flowing', AffixLean.flow, AffixEffect.initiativeUp, 3, 'moves with you — act sooner (+3)'),
  Affix('Whispering', AffixLean.flow, AffixEffect.statUp, 3, 'barely a sound — bite +3'),
];

const itemSuffixes = <Affix>[
  Affix('of the Journeyman', AffixLean.neutral, AffixEffect.bankPoint, 1, 'came with a spare — bank +1 point'),
  Affix('of the Vanguard', AffixLean.neutral, AffixEffect.initiativeUp, 3, 'always first to the line — act sooner (+3)'),
  Affix('of Second Wind', AffixLean.neutral, AffixEffect.healNow, 12, 'a steadying weight — restore 12 vitality'),
  Affix('of the Ember', AffixLean.force, AffixEffect.statUp, 4, 'strikes land like coals — bite +4'),
  Affix('of the Bear', AffixLean.force, AffixEffect.statUp, 5, 'ruinous weight behind it — bite +5'),
  Affix('of the Avalanche', AffixLean.force, AffixEffect.statUp, 6, 'once it moves, nothing stops it — bite +6'),
  Affix('of the Gale', AffixLean.flow, AffixEffect.initiativeUp, 4, 'quick as weather — act sooner (+4)'),
  Affix('of Still Water', AffixLean.flow, AffixEffect.healNow, 18, 'calm returns with it — restore 18 vitality'),
  Affix('of the Reed', AffixLean.flow, AffixEffect.initiativeUp, 3, 'bends, never breaks — act sooner (+3)'),
];

// ── Technique (card) affixes ─────────────────────────────────────────

const techniquePrefixes = <Affix>[
  Affix('Rough', AffixLean.neutral, AffixEffect.statUp, 1, 'half-remembered — force +1'),
  Affix('Clean', AffixLean.neutral, AffixEffect.statUp, 2, 'no wasted motion — force +2'),
  Affix('Sharp', AffixLean.neutral, AffixEffect.statUp, 3, 'lands where aimed — force +3'),
  Affix('Perfected', AffixLean.neutral, AffixEffect.statUp, 5, 'drilled to the bone — force +5'),
  Affix('Crushing', AffixLean.force, AffixEffect.statUp, 5, 'meant to end things — force +5'),
  Affix('Thunderous', AffixLean.force, AffixEffect.statUp, 6, 'you feel it in the floor — force +6'),
  Affix('Darting', AffixLean.flow, AffixEffect.initiativeUp, 3, 'struck before seen — act sooner (+3)'),
  Affix('Serene', AffixLean.flow, AffixEffect.healNow, 10, 'the calm to keep going — restore 10 vitality'),
  Affix('Ghosting', AffixLean.flow, AffixEffect.initiativeUp, 4, 'never quite there — act sooner (+4)'),
];

const techniqueSuffixes = <Affix>[
  Affix('of the First Form', AffixLean.neutral, AffixEffect.statUp, 2, 'the root of the style — force +2'),
  Affix('of Seven Stars', AffixLean.neutral, AffixEffect.statUp, 3, 'a set path, well worn — force +3'),
  Affix('of the Broken Guard', AffixLean.neutral, AffixEffect.initiativeUp, 3, 'punishes hesitation — act sooner (+3)'),
  Affix('of the Rising Sun', AffixLean.force, AffixEffect.statUp, 4, 'opens with everything — force +4'),
  Affix('of the Iron Ox', AffixLean.force, AffixEffect.statUp, 5, 'slow, certain, heavy — force +5'),
  Affix('of the Turning Wheel', AffixLean.flow, AffixEffect.initiativeUp, 4, 'momentum feeds itself — act sooner (+4)'),
  Affix('of Still Water', AffixLean.flow, AffixEffect.healNow, 16, 'yield, then recover — restore 16 vitality'),
  Affix('of the Coiled Spring', AffixLean.flow, AffixEffect.initiativeUp, 3, 'stored, then released — act sooner (+3)'),
];

/// How often a prefix / suffix slot comes up empty — a plain, unadorned
/// piece ("Iron Sword", "Basic Slash"). Rolled independently for each
/// slot, so most cards carry one affix, some carry two, and a few carry
/// none at all.
const kNoAffixChance = 0.34;

/// [rollAffix], but with a [noneChance] probability of returning null —
/// no prefix / no suffix on this slot.
Affix? rollAffixOrNone(
  List<Affix> pool,
  String affinity,
  RngService rng, {
  double noneChance = kNoAffixChance,
}) =>
    rng.nextDouble() < noneChance ? null : rollAffix(pool, affinity, rng);

/// A weighted draw from [pool]: Neutral affixes weigh 2, the lean that
/// matches [affinity] weighs 3, the opposite lean weighs 1. [affinity]
/// is `'western'` / `'eastern'` (from the physique) — anything else
/// leaves every lean at weight 2.
Affix rollAffix(List<Affix> pool, String affinity, RngService rng) {
  final favoured = switch (affinity) {
    'western' => AffixLean.force,
    'eastern' => AffixLean.flow,
    _ => null,
  };
  int weightOf(AffixLean lean) {
    if (lean == AffixLean.neutral) return 2;
    if (favoured == null) return 2;
    return lean == favoured ? 3 : 1;
  }

  final total = pool.fold<int>(0, (sum, a) => sum + weightOf(a.lean));
  var roll = rng.nextInt(total);
  for (final a in pool) {
    roll -= weightOf(a.lean);
    if (roll < 0) return a;
  }
  return pool.last;
}
