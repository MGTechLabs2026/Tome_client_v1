// lib/core/models/combat_tally_view.dart
//
// What one auto-fight recorded about how the active build performed:
// landed vs missed strikes keyed by the component that threw them, and
// how the fighter's defence held. `CombatAdapter` turns each entry into
// mastery for that item/technique during the fight (see the
// kCombat* constants); this view is what the fight hands back.
class CombatTally {
  CombatTally();

  /// Successful attacks keyed by the technique that produced them.
  final Map<String, int> hitsByTechnique = {};

  /// Missed / fumbled attacks keyed by technique.
  final Map<String, int> missesByTechnique = {};

  /// Successful strikes keyed by the weapon item that powered them
  /// (the bare-handed fallback strike, when a weapon is hung).
  final Map<String, int> hitsByItem = {};

  /// Missed strikes keyed by weapon item.
  final Map<String, int> missesByItem = {};

  /// Bare-handed strikes that landed / missed (train no component).
  int fistHits = 0;
  int fistMisses = 0;

  /// Guard casts that held + enemy blows an armour piece shrugged off.
  int defenceHeld = 0;

  /// Guard casts that broke + enemy blows armour failed to blunt.
  int defenceBroken = 0;

  /// Total mastery points handed out across every component this fight.
  double masteryAwarded = 0;

  static int _sum(Iterable<int> xs) => xs.fold<int>(0, (a, b) => a + b);

  int get hitsLanded =>
      _sum(hitsByTechnique.values) + _sum(hitsByItem.values) + fistHits;

  int get strikesMissed =>
      _sum(missesByTechnique.values) + _sum(missesByItem.values) + fistMisses;

  void _bump(Map<String, int> m, String id) =>
      m[id] = (m[id] ?? 0) + (id.isEmpty ? 0 : 1);

  void techniqueHit(String id) => _bump(hitsByTechnique, id);
  void techniqueMiss(String id) => _bump(missesByTechnique, id);
  void itemHit(String id) => _bump(hitsByItem, id);
  void itemMiss(String id) => _bump(missesByItem, id);
}
