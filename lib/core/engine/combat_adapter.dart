// lib/core/engine/combat_adapter.dart
import 'package:build_engine/auto_combat_plugin.dart';
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/build_interpretation.dart';
import 'package:build_engine/combat_plugin.dart';
import 'package:build_engine/item_plugin.dart';

import '../models/combat_log_entry_view.dart';
import 'engine_session.dart';
import 'tome_adapter.dart';

const _interpreter = CompositeBuildActionInterpreter([
  TechniqueActionInterpreter(),
  ItemActionInterpreter(),
]);

/// Runs one fight to completion the same way `CombatStage.runFight` does
/// — resolve the active Tome build into interpreted player actions (with
/// a bare-handed fallback strike when the Tome holds no technique yet),
/// spawn the enemy, and drive `AutoCombatController` until the battle
/// ends. Instead of the reference stage's `EncounterOutcome` bookkeeping,
/// this adapter captures every turn/damage/heal event as a
/// `CombatLogEntryView` for the placeholder combat screen to render.
class CombatAdapter {
  CombatAdapter(this._session, {required TomeAdapter tomeAdapter})
    : _tomeAdapter = tomeAdapter;

  final EngineSession _session;
  // ignore: unused_field
  final TomeAdapter _tomeAdapter;

  String _fallbackStrikeStat(ActiveBuild build) {
    for (final ref in build.components) {
      if (ref.referenceType != itemReferenceType) continue;
      final content = _session.context.content.find(ref.contentId);
      if (content == null) continue;
      final item = itemDefinitionFromContent(content);
      if (!item.properties.containsKey('attack')) continue;
      return WeaponStatTags.matchOrFallback(item.tags, 'item:${item.id}');
    }
    return 'fist';
  }

  ({bool won, List<CombatLogEntryView> log}) runFight(
    String enemyId, {
    required num enemyHealth,
    required num enemyDamage,
    required String enemyDamageStat,
    int enemyInitiative = 8,
  }) {
    final enemy = _session.context.entities.create();
    _session.context.components.add(
      enemy,
      CombatantComponent(team: 'enemy', initiative: enemyInitiative),
    );
    _session.context.components.add(
      enemy,
      HealthComponent(current: enemyHealth, max: enemyHealth),
    );

    final build = _session.context.tome.resolve(_session.character);
    final playerActions = _interpreter.interpret(
      build: build,
      actor: _session.character,
      targets: [enemy],
      context: _session.context,
    );
    final effectiveActions =
        playerActions.isEmpty
            ? [
              AttackAction(
                actor: _session.character,
                targets: [enemy],
                baseDamage: 4,
                damageStat: _fallbackStrikeStat(build),
              ),
            ]
            : playerActions;

    final battle = _session.combatPlugin.system.startBattle([
      _session.character,
      enemy,
    ]);
    final controller = AutoCombatController(
      context: _session.context,
      combatSystem: _session.combatPlugin.system,
      battle: battle,
      availableActions: [
        ...effectiveActions,
        AttackAction(
          actor: enemy,
          targets: [_session.character],
          baseDamage: enemyDamage,
          damageStat: enemyDamageStat,
        ),
      ],
      policy: CombatPolicy.scored(),
    );

    final log = <CombatLogEntryView>[];
    final subs = [
      _session.context.events.subscribe<TurnStarted>((e) {
        final label = e.actor == _session.character ? 'You' : 'Enemy';
        log.add(
          CombatLogEntryView(
            kind: CombatLogEntryKind.turnStart,
            text: '$label act.',
          ),
        );
      }),
      _session.context.events.subscribe<EntityDamaged>((e) {
        final label = e.id == _session.character ? 'You take' : 'Enemy takes';
        log.add(
          CombatLogEntryView(
            kind: CombatLogEntryKind.damage,
            text: '$label ${e.amount} damage.',
          ),
        );
      }),
      _session.context.events.subscribe<EntityHealed>((e) {
        final label = e.id == _session.character ? 'You heal' : 'Enemy heals';
        log.add(
          CombatLogEntryView(
            kind: CombatLogEntryKind.heal,
            text: '$label ${e.amount}.',
          ),
        );
      }),
    ];

    controller.runUntilBattleEnds();
    for (final s in subs) {
      s.cancel();
    }

    final playerHealth =
        _session.context.components
            .get<HealthComponent>(_session.character)!
            .current;
    final won = playerHealth > 0 && !controller.isActive;
    log.add(
      CombatLogEntryView(
        kind: won ? CombatLogEntryKind.victory : CombatLogEntryKind.defeat,
        text: won ? 'Victory!' : 'Defeated...',
      ),
    );

    return (won: won, log: log);
  }
}
