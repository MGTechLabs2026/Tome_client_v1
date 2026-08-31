// lib/core/engine/combat_adapter.dart
import 'dart:math' as math;

import 'package:build_engine/auto_combat_plugin.dart';
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/build_interpretation.dart';
import 'package:build_engine/combat_plugin.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/martial_arts_plugin.dart'
    show BurstChainState, StyleCombatRules;
import 'package:build_engine/technique_plugin.dart';

import '../models/combat_log_entry_view.dart';
import '../models/combat_tally_view.dart';
import 'engine_session.dart';
import 'tome_adapter.dart';

const _itemInterpreter = ItemActionInterpreter();

/// Mastery a component earns per resolved action in combat: a clean
/// success trains it a little, a miss/fumble trains it more (you learn
/// most from what goes wrong).
const kCombatMasterySuccess = 0.1;
const kCombatMasteryFail = 0.3;

/// Runs one auto-fight, restructured so every turn resolves in order:
///
///   1. whose turn it is        (CombatStateComponent.currentTurnIndex)
///   2. which active component   (the scored policy picks from the
///      per-component action pool built off the Tome)
///   3. did the action succeed   (a chance roll off that component's
///      mastery, via the run's seeded RNG)
///   4. damage / recovery        (the engine's effects run only on a
///      success; a miss still spends the turn)
///
/// Each resolved player action then trains the component that threw it
/// ([kCombatMasterySuccess] / [kCombatMasterySuccess]) and is counted in
/// the returned [CombatTally]. The engine's generic `CombatSystem` is
/// untouched — this is the roguelike rule "combat trains your build",
/// which lives with the client's run orchestration.
class CombatAdapter {
  CombatAdapter(this._session, {required TomeAdapter tomeAdapter})
      : _tomeAdapter = tomeAdapter;

  final EngineSession _session;
  // ignore: unused_field
  final TomeAdapter _tomeAdapter;

  PluginContext get _ctx => _session.context;
  EntityId get _me => _session.character;

  ({bool won, List<CombatLogEntryView> log, CombatTally tally}) runFight(
    String enemyId, {
    required num enemyHealth,
    required num enemyDamage,
    required String enemyDamageStat,
    int enemyInitiative = 8,
    // Content Expansion V1 — enemy archetype behaviour (matrix §G/§H).
    // All default to "no effect" so existing callers are unchanged.
    double enemyArmour = 0,
    double enemyDodge = 0,
    double enemyMissPunish = 0,
    num enemyRegen = 0,
    int enemyHits = 1,
  }) {
    final enemy = _ctx.entities.create();
    _ctx.components
        .add(enemy, CombatantComponent(team: 'enemy', initiative: enemyInitiative));
    _ctx.components
        .add(enemy, HealthComponent(current: enemyHealth, max: enemyHealth));

    // A2: the style-scoped combat rules (off-specialty penalty, Shaolin
    // Conditioning, Kunlun Burst Chain) are engine-owned. Build the rules
    // object from the fighter's tags and let it answer; this adapter no
    // longer computes any of the numbers itself.
    final myTags = _ctx.components.get<TagSet>(_me)?.tags ?? const <String>{};
    final styleRules = StyleCombatRules(myTags);

    final build = _ctx.tome.resolve(_me);
    // Items contribute passive stat modifiers (weapon attack, affixes) —
    // run that side effect, and note which items are weapons vs armour.
    _itemInterpreter.interpret(
        build: build, actor: _me, targets: [enemy], context: _ctx);
    final weapons = <String>[];
    final armour = <String>[];
    for (final ref in build.components) {
      if (ref.referenceType != itemReferenceType) continue;
      final def = _ctx.content.find(ref.contentId);
      if (def == null) continue;
      final item = itemDefinitionFromContent(def);
      (item.properties.containsKey('attack') ? weapons : armour).add(item.id);
    }

    // One tagged action per hung technique, plus a bare-handed fallback
    // strike when nothing on the Tome can attack.
    final pool = <_Tagged>[];
    for (final ref in build.components) {
      if (ref.referenceType != techniqueReferenceType) continue;
      final def = _ctx.content.find(ref.contentId);
      if (def == null) continue;
      final tech = techniqueDefinitionFromContent(def);
      if (tech.tags.contains('guard')) {
        pool.add(_Tagged(
          SelfEffectAction(
            actor: _me,
            selfEffects: [ApplyStatus('status:guard:${tech.id}')],
          ),
          _Comp.guard(tech.id),
        ));
      } else if (tech.properties['damage'] != null) {
        pool.add(_Tagged(
          AttackAction(
            actor: _me,
            targets: [enemy],
            // The enemy's armour shrugs off a fraction of every landed
            // hit; a technique outside the style's lane lands softer
            // (engine-owned rule). Both baked into the action so
            // player-facing numbers and the tally already reflect them.
            baseDamage: tech.properties['damage']! *
                (1 - enemyArmour) *
                styleRules.outgoingDamageFactor(tech.tags),
            damageStat:
                WeaponStatTags.matchOrFallback(tech.tags, techniqueSubject(tech.id)),
          ),
          _Comp.technique(tech.id),
          tags: tech.tags,
        ));
      }
    }
    if (!pool.any((t) => t.action is AttackAction)) {
      final weapon = weapons.isEmpty ? '' : weapons.first;
      final weaponTags = weapon.isEmpty
          ? const <String>{'fist'}
          : itemDefinitionFromContent(_ctx.content.find(weapon)!).tags;
      pool.add(_Tagged(
        AttackAction(
          actor: _me,
          targets: [enemy],
          baseDamage:
              4 * (1 - enemyArmour) * styleRules.outgoingDamageFactor(weaponTags),
          damageStat: weapon.isEmpty
              ? 'fist'
              : WeaponStatTags.matchOrFallback(weaponTags, 'item:$weapon'),
        ),
        weapon.isEmpty ? const _Comp.fist() : _Comp.weapon(weapon),
        tags: weaponTags,
      ));
    }

    final enemyAttack = AttackAction(
      actor: enemy,
      targets: [_me],
      baseDamage: enemyDamage,
      damageStat: enemyDamageStat,
    );

    final battle = _session.combatPlugin.system.startBattle([_me, enemy]);

    final resolver = _Resolver(
      ctx: _ctx,
      rng: _session.rng,
      system: _session.combatPlugin.system,
      battle: battle,
      me: _me,
      enemy: enemy,
      pool: pool,
      enemyAttack: enemyAttack,
      armour: armour,
      enemyDodge: enemyDodge,
      enemyMissPunish: enemyMissPunish,
      enemyRegen: enemyRegen,
      enemyHits: enemyHits,
      styleRules: styleRules,
    );
    resolver.run();

    final playerHp =
        _ctx.components.get<HealthComponent>(_me)!.current;
    final won = playerHp > 0 &&
        !(_ctx.components.get<CombatStateComponent>(battle)?.active ?? false);
    final t = resolver.tally;
    resolver.log.add(resolver.entry(
      CombatLogEntryKind.actionResolved,
      'Landed ${t.hitsLanded} · missed ${t.strikesMissed} · '
      'defence ${t.defenceHeld}/${t.defenceHeld + t.defenceBroken}.',
    ));
    resolver.log.add(resolver.entry(
      won ? CombatLogEntryKind.victory : CombatLogEntryKind.defeat,
      won ? 'Victory!' : 'Defeated...',
    ));

    return (won: won, log: resolver.log, tally: t);
  }
}

/// A combat action paired with the Tome component that produced it, plus
/// that component's content tags (for the style specialty / off-lane
/// checks).
class _Tagged {
  _Tagged(this.action, this.comp, {this.tags = const <String>{}});
  final CombatAction action;
  final _Comp comp;
  final Set<String> tags;
}

enum _CompKind { technique, guard, weapon, fist }

class _Comp {
  const _Comp(this.kind, this.id);
  const _Comp.technique(this.id) : kind = _CompKind.technique;
  const _Comp.guard(this.id) : kind = _CompKind.guard;
  const _Comp.weapon(this.id) : kind = _CompKind.weapon;
  const _Comp.fist()
      : kind = _CompKind.fist,
        id = '';

  final _CompKind kind;
  final String id;

  bool get isDefence => kind == _CompKind.guard;
  bool get trainsAComponent => id.isNotEmpty;
}

/// The turn loop. Replaces `AutoCombatController.runUntilBattleEnds` for
/// the player's side so success/fail is decided per turn (off live
/// mastery) before the engine calculates damage/recovery.
class _Resolver {
  _Resolver({
    required this.ctx,
    required this.rng,
    required this.system,
    required this.battle,
    required this.me,
    required this.enemy,
    required this.pool,
    required this.enemyAttack,
    required this.armour,
    this.enemyDodge = 0,
    this.enemyMissPunish = 0,
    this.enemyRegen = 0,
    this.enemyHits = 1,
    required this.styleRules,
  });

  final PluginContext ctx;
  final RngService rng;
  final CombatSystem system;
  final EntityId battle;
  final EntityId me;
  final EntityId enemy;
  final List<_Tagged> pool;
  final AttackAction enemyAttack;
  final List<String> armour;

  /// Enemy archetype behaviour (matrix §G/§H).
  final double enemyDodge;
  final double enemyMissPunish;
  final num enemyRegen;
  final int enemyHits;

  /// The engine-owned style-scoped combat rules (A2): off-specialty
  /// penalty (applied at pool build above), Shaolin Conditioning and
  /// Kunlun Burst Chain. This loop only threads state through them; the
  /// numbers are the engine's. The stance-gated specialties still need
  /// mid-fight stance entry this loop doesn't model — deferred (matrix
  /// §L), unchanged.
  final StyleCombatRules styleRules;
  BurstChainState _burst = BurstChainState.broken;

  // Scored so the player prefers a real attack over re-casting a guard
  // while the enemy is up; falls back to whatever is legal otherwise.
  final _policy = CombatPolicy.scored();
  final log = <CombatLogEntryView>[];
  final tally = CombatTally();

  num get _hp => ctx.components.get<HealthComponent>(me)?.current ?? 0;
  bool get _active =>
      ctx.components.get<CombatStateComponent>(battle)?.active ?? false;

  CombatLogEntryView entry(CombatLogEntryKind kind, String text) {
    final p = ctx.components.get<HealthComponent>(me);
    final f = ctx.components.get<HealthComponent>(enemy);
    return CombatLogEntryView(
      kind: kind,
      text: text,
      playerHp: p?.current,
      playerHpMax: p?.max,
      enemyHp: f?.current,
      enemyHpMax: f?.max,
    );
  }

  void run({int maxSteps = 2000}) {
    var steps = 0;
    while (_active && steps++ < maxSteps) {
      final state = ctx.components.get<CombatStateComponent>(battle);
      if (state == null || !state.active) break;
      final actor = state.participants[state.currentTurnIndex];
      final living = ctx.queries
          .evaluate(state.participants, HealthBelowQuery(1).not())
          .toSet();
      if (!living.contains(actor)) break;

      if (actor == me) {
        if (!_playerTurn(state, living)) break;
      } else {
        _enemyTurn();
      }
    }
  }

  bool _playerTurn(CombatStateComponent state, Set<EntityId> living) {
    // 2. which component — the scored policy picks from the legal pool.
    final legal = [
      for (final t in pool)
        if (t.action.actor == me &&
            t.action.targets.isNotEmpty &&
            t.action.targets.every(living.contains))
          t,
    ];
    if (legal.isEmpty) return false;
    final chosenAction = _policy.decideNextAction(
      me,
      [for (final t in legal) t.action],
      [
        for (final id in state.participants)
          if (id != me && living.contains(id)) id,
      ],
      ctx,
    );
    if (chosenAction == null) return false;
    final chosen = legal.firstWhere((t) => identical(t.action, chosenAction));
    final comp = chosen.comp;

    // 3. success / fail — an evasive enemy shaves the hit chance down.
    final success = rng.chance(_chance(comp) * (1 - enemyDodge));
    final name = _pretty(comp.id.isEmpty ? 'a bare-handed strike' : comp.id);

    if (success) {
      // 4. damage / recovery — the engine runs the real effects.
      final foeBefore =
          ctx.components.get<HealthComponent>(enemy)?.current ?? 0;
      system.executeAction(battle, chosen.action);
      var dealt =
          foeBefore - (ctx.components.get<HealthComponent>(enemy)?.current ?? 0);
      // kunlun Burst Chain (engine rule) — thread the streak through it.
      final bc = styleRules.burstChainOnHit(_burst, chosen.tags.contains('blade'));
      if (bc.bonus > 0) dealt += _chip(enemy, bc.bonus);
      _burst = bc.state;
      _award(comp, kCombatMasterySuccess);
      _count(comp, hit: true);
      log.add(entry(
        comp.isDefence ? CombatLogEntryKind.heal : CombatLogEntryKind.damage,
        comp.isDefence
            ? 'You set $name — it holds.'
            : 'You land $name — $dealt damage.',
      ));
    } else {
      _burst = BurstChainState.broken; // a miss breaks the chain
      // A miss still spends the turn (a no-op self action advances it).
      system.executeAction(battle, SelfEffectAction(actor: me));
      _award(comp, kCombatMasteryFail);
      _count(comp, hit: false);
      log.add(entry(
        CombatLogEntryKind.actionResolved,
        comp.isDefence ? 'Your $name breaks.' : 'Your $name goes wide.',
      ));
      // A counter fighter makes you pay for the opening.
      if (enemyMissPunish > 0 && _active) {
        final before = _hp;
        system.executeAction(
          battle,
          AttackAction(
            actor: enemy,
            targets: [me],
            baseDamage: enemyAttack.baseDamage * enemyMissPunish,
            damageStat: enemyAttack.damageStat,
          ),
        );
        final bit = before - _hp;
        if (bit > 0) {
          log.add(entry(CombatLogEntryKind.damage,
              'It reads the opening — $bit on the counter.'));
        }
      }
    }
    return true;
  }

  void _enemyTurn() {
    _burst = BurstChainState.broken; // the enemy acting breaks a blade chain
    // The turn-spending strike (rolls the player's armour).
    _enemyStrike();
    // A fast striker / flash duelist adds a flurry — extra chip that
    // does not go through the engine's one-action-per-turn machinery.
    for (var i = 1; i < enemyHits && _hp > 0; i++) {
      _enemyFlurryHit();
    }
    // An endurance fighter knits itself back together each turn.
    if (enemyRegen > 0) {
      final h = ctx.components.get<HealthComponent>(enemy);
      if (h != null && h.current > 0 && h.current < h.max) {
        final back = math.min(enemyRegen, h.max - h.current);
        ctx.components.add(enemy,
            HealthComponent(current: h.current + back, max: h.max));
        ctx.events.publish(EntityHealed(enemy, back is int ? back : back.round()));
        log.add(entry(CombatLogEntryKind.heal, 'Enemy recovers $back.'));
      }
    }
  }

  void _enemyStrike() {
    final before = _hp;
    system.executeAction(battle, enemyAttack);
    var dealt = before - _hp;
    // Shaolin Conditioning (engine rule): shrug 1 off the incoming hit,
    // and restore the point already taken from HP.
    final mitigated = styleRules.mitigateIncoming(dealt);
    if (mitigated < dealt) {
      _heal((dealt - mitigated).round());
      dealt = mitigated;
    }
    if (dealt <= 0 || armour.isEmpty) {
      if (dealt > 0) {
        log.add(entry(CombatLogEntryKind.damage, 'Enemy hits for $dealt.'));
      }
      return;
    }
    // The player's defence rolls against the blow that landed.
    final piece = armour.first;
    final held = rng.chance(_armourChance(piece));
    if (held) {
      final shrug = (dealt * 0.3).floor();
      if (shrug > 0) _heal(shrug);
      tally.defenceHeld++;
      _awardItem(piece, kCombatMasterySuccess);
      log.add(entry(CombatLogEntryKind.heal,
          'Enemy hits for $dealt — your ${_pretty(piece)} soaks $shrug.'));
    } else {
      tally.defenceBroken++;
      _awardItem(piece, kCombatMasteryFail);
      log.add(entry(CombatLogEntryKind.damage,
          'Enemy hits for $dealt — your ${_pretty(piece)} gives.'));
    }
  }

  /// An extra hit in a multi-strike turn — applied straight to the
  /// player's HealthComponent so it doesn't trip the engine's
  /// one-action-per-turn guard.
  void _enemyFlurryHit() {
    final h = ctx.components.get<HealthComponent>(me);
    if (h == null || h.current <= 0) return;
    final raw = enemyAttack.baseDamage;
    var dmg = raw is int ? raw : raw.round();
    dmg = styleRules.mitigateIncoming(dmg).round(); // Shaolin Conditioning
    dmg = dmg.clamp(0, h.current.toInt());
    if (dmg <= 0) return;
    ctx.components.add(me, HealthComponent(current: h.current - dmg, max: h.max));
    ctx.events.publish(EntityDamaged(me, dmg));
    log.add(entry(CombatLogEntryKind.damage, 'Enemy hits again for $dmg.'));
  }

  /// Direct damage to [target]'s HealthComponent (used for effects that
  /// must not consume a turn — e.g. a Burst Chain bonus). Returns the HP
  /// actually removed.
  num _chip(EntityId target, num amount) {
    final h = ctx.components.get<HealthComponent>(target);
    if (h == null || h.current <= 0 || amount <= 0) return 0;
    final removed = math.min(amount, h.current);
    ctx.components
        .add(target, HealthComponent(current: h.current - removed, max: h.max));
    ctx.events
        .publish(EntityDamaged(target, removed is int ? removed : removed.round()));
    return removed;
  }

  void _heal(int amount) {
    final h = ctx.components.get<HealthComponent>(me);
    if (h == null) return;
    ctx.components.add(
      me,
      HealthComponent(
        current: math.min(h.current + amount, h.max),
        max: h.max,
      ),
    );
    ctx.events.publish(EntityHealed(me, amount));
  }

  double _chance(_Comp c) {
    final base = switch (c.kind) {
      _CompKind.technique => 0.72,
      _CompKind.guard => 0.60,
      _CompKind.weapon => 0.68,
      _CompKind.fist => 0.62,
    };
    final level = c.id.isEmpty
        ? 0
        : ctx.mastery.levelOf(
            me,
            c.kind == _CompKind.weapon ? itemSubject(c.id) : techniqueSubject(c.id),
          );
    final step = c.kind == _CompKind.guard ? 0.06 : 0.05;
    return (base + step * level).clamp(0.35, 0.95);
  }

  double _armourChance(String itemId) =>
      (0.45 + 0.05 * ctx.mastery.levelOf(me, itemSubject(itemId)))
          .clamp(0.25, 0.85);

  void _count(_Comp c, {required bool hit}) {
    switch (c.kind) {
      case _CompKind.technique:
        hit ? tally.techniqueHit(c.id) : tally.techniqueMiss(c.id);
      case _CompKind.weapon:
        hit ? tally.itemHit(c.id) : tally.itemMiss(c.id);
      case _CompKind.fist:
        hit ? tally.fistHits++ : tally.fistMisses++;
      case _CompKind.guard:
        hit ? tally.defenceHeld++ : tally.defenceBroken++;
    }
  }

  void _award(_Comp c, double amount) {
    if (!c.trainsAComponent) return;
    final subject =
        c.kind == _CompKind.weapon ? itemSubject(c.id) : techniqueSubject(c.id);
    ctx.mastery.increase(me, subject, amount);
    tally.masteryAwarded += amount;
  }

  void _awardItem(String id, double amount) {
    if (id.isEmpty) return;
    ctx.mastery.increase(me, itemSubject(id), amount);
    tally.masteryAwarded += amount;
  }

  String _pretty(String id) => id
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
