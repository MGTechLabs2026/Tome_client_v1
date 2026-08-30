enum LootKind { upgradePoints, gridExpansion, newComponent }

class LootOptionView {
  const LootOptionView({
    required this.kind,
    required this.title,
    required this.detail,
  });

  final LootKind kind;
  final String title;
  final String detail;
}
