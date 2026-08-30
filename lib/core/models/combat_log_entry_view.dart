enum CombatLogEntryKind { turnStart, damage, heal, actionResolved, victory, defeat }

class CombatLogEntryView {
  const CombatLogEntryView({
    required this.kind,
    required this.text,
    this.playerHp,
    this.playerHpMax,
    this.enemyHp,
    this.enemyHpMax,
  });

  final CombatLogEntryKind kind;
  final String text;

  /// Both fighters' health at the moment this entry was logged, so the
  /// replay can drive its HP bars off engine truth rather than
  /// re-deriving totals from the log text. Null only if the relevant
  /// `HealthComponent` was already gone (e.g. the final victory line
  /// after the enemy entity was cleaned up).
  final num? playerHp;
  final num? playerHpMax;
  final num? enemyHp;
  final num? enemyHpMax;
}
