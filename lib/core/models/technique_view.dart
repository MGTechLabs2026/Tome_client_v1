class TechniqueView {
  const TechniqueView({
    required this.definitionId,
    required this.name,
    required this.tier,
    required this.properties,
    required this.discovered,
    required this.learned,
    required this.masteryLevel,
    required this.evolvedFromId,
  });

  final String definitionId;
  final String name;
  final String tier;
  final Map<String, num> properties;
  final bool discovered;
  final bool learned;
  final int masteryLevel;

  /// The technique this one evolved from, if any — one hop, sourced
  /// from `EngineSession`'s accumulated lineage map.
  final String? evolvedFromId;
}
