class TrainingResultView {
  const TrainingResultView({
    required this.subject,
    required this.dimensions,
    required this.gain,
    required this.crossedIntoUsableOrLearned,
    this.evolvedIntoDefinitionId,
    this.evolvedFromDefinitionId,
  });

  final String subject;
  final Map<String, double> dimensions;
  final num gain;
  final bool crossedIntoUsableOrLearned;
  final String? evolvedIntoDefinitionId;
  final String? evolvedFromDefinitionId;
}
