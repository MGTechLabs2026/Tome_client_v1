enum LootKind { upgradePoints, gridExpansion, newComponent }

class LootOptionView {
  const LootOptionView({
    required this.kind,
    required this.title,
    required this.detail,
    this.badge,
    this.seed = 0,
    this.effects = const [],
  });

  final LootKind kind;

  /// The card headline. For [LootKind.newComponent] this is the affixed
  /// name: `<Prefix> <Name> <Suffix>`.
  final String title;

  /// One line under the title — what the reward is.
  final String detail;

  /// Small tag on the card (`CLASS II`, `TECHNIQUE`), or null.
  final String? badge;

  /// Seeds the card's chop mark so the same component always draws the
  /// same glyph.
  final int seed;

  /// The rolled prefix/suffix blurbs, shown as the card's effect list.
  final List<String> effects;
}
