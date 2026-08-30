enum CombatLogEntryKind { turnStart, damage, heal, actionResolved, victory, defeat }

class CombatLogEntryView {
  const CombatLogEntryView({
    required this.kind,
    required this.text,
  });

  final CombatLogEntryKind kind;
  final String text;
}
