enum CombineResultKind { fail, classUpgraded, evolvedIntoNewItem }

class CombineResultView {
  const CombineResultView({
    required this.kind,
    required this.resultingDefinitionId,
    required this.resultingItemClass,
  });

  final CombineResultKind kind;
  final String resultingDefinitionId;
  final int resultingItemClass;
}
