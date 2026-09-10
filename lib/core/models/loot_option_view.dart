enum LootKind { upgradePoints, gridExpansion, newComponent }

class LootOptionView {
  const LootOptionView({
    required this.kind,
    required this.title,
    required this.detail,
    this.badge,
    this.seed = 0,
    this.effects = const [],
    this.prefixAffixId,
    this.suffixAffixId,
  });

  final LootKind kind;

  /// The card headline. For [LootKind.newComponent] this is the affixed
  /// name: `<Prefix> <Name> <Suffix>`, prefix/suffix from engine
  /// `AffixDefinition.label`.
  final String title;

  /// One line under the title — what the reward is.
  final String detail;

  /// Small tag on the card (`CLASS II`, `TECHNIQUE`), or null.
  final String? badge;

  /// Seeds the card's chop mark so the same component always draws the
  /// same glyph.
  final int seed;

  /// The card's effect list — one line per resolved affix slot, composed
  /// from the engine `AffixMechanic`.
  final List<String> effects;

  /// Engine affix id resolved for the prefix slot of a New Component
  /// offer (`af_*`), or null when the slot rolled empty. Fixed at
  /// generation; identical through preview and TAKE.
  final String? prefixAffixId;

  /// Engine affix id resolved for the suffix slot, or null.
  final String? suffixAffixId;
}
