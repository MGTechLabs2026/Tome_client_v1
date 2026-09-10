/// The fixed semantic slot a reward card occupies. Card order on the
/// screen is always `[progression, utility, component]`.
///
/// * [upgradePoints] — SLOT 1, always Upgrade Point.
/// * [gridExpansion] — SLOT 2, the *utility* slot: a Tome Slot **or** a
///   Consumable ([LootOptionView.contentKind] disambiguates).
/// * [newComponent]  — SLOT 3, an Item **or** a Technique.
///
/// This enum is the slot identity `LootChosen` carries; what the slot
/// currently *holds* is [LootOptionView.contentKind]. Slot identity ≠
/// reward content, so this enum never grows past the three slots.
enum LootKind { upgradePoints, gridExpansion, newComponent }

/// What a card actually offers — so the UI renders the right card
/// without sniffing the title string.
enum RewardContentKind { upgradePoint, tomeSlot, consumable, item, technique }

class LootOptionView {
  const LootOptionView({
    required this.kind,
    required this.contentKind,
    required this.title,
    required this.detail,
    this.contentId,
    this.badge,
    this.seed = 0,
    this.effects = const [],
    this.prefixAffixId,
    this.suffixAffixId,
  });

  /// The fixed slot this card fills.
  final LootKind kind;

  /// The reward family currently in this slot.
  final RewardContentKind contentKind;

  /// The engine content id for a [RewardContentKind.consumable] /
  /// `.item` / `.technique` card; null for the point and tome-slot
  /// rewards which have no content id.
  final String? contentId;

  /// The card headline. For an item / technique this is the affixed
  /// name: `<Prefix> <Name> <Suffix>`, prefix/suffix from engine
  /// `AffixDefinition.label`.
  final String title;

  /// One line under the title — what the reward is.
  final String detail;

  /// Small tag on the card (`CLASS II`, `TECHNIQUE`, `CONSUMABLE`), or null.
  final String? badge;

  /// Seeds the card's chop mark so the same component always draws the
  /// same glyph.
  final int seed;

  /// The card's effect list — one line per resolved affix slot (item /
  /// technique), or the consumable's gameplay-effect line(s).
  final List<String> effects;

  /// Engine affix id resolved for the prefix slot of an item / technique
  /// offer (`af_*`), or null when the slot rolled empty. Fixed at
  /// generation; identical through preview and TAKE. Never set for a
  /// consumable.
  final String? prefixAffixId;

  /// Engine affix id resolved for the suffix slot, or null.
  final String? suffixAffixId;
}
