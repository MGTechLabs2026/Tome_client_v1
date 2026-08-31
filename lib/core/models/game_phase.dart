enum GamePhase {
  /// The threshold: the title screen. The app boots here and returns
  /// here when a lineage falls.
  title,
  characterCreation,
  tome,
  trainingPreparation,
  training,
  trainingResult,
  combatPreparation,
  combat,
  loot,

  /// The lineage is down — a brief "the line ends" beat that hands back
  /// to the title screen.
  defeat,
}
