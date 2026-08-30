class CharacterView {
  const CharacterView({
    required this.name,
    required this.physiqueId,
    required this.physiqueAffinityTradition,
    required this.martialTradition,
    required this.styleId,
    required this.healthCurrent,
    required this.healthMax,
  });

  final String name;
  final String physiqueId;

  /// `'western'`/`'eastern'` — the tradition this physique carries a
  /// synergy modifier for, read from its content tags.
  final String physiqueAffinityTradition;
  final String martialTradition;
  final String styleId;
  final num healthCurrent;
  final num healthMax;
}
