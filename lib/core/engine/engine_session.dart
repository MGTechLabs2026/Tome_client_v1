import 'package:build_engine/build_engine.dart';
import 'package:build_engine/combat_plugin.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/martial_arts_plugin.dart';
import 'package:build_engine/physique_plugin.dart';
import 'package:build_engine/technique_plugin.dart';

/// Bootstraps one `PluginContext` with every plugin the client drives,
/// and owns the small pieces of session-scoped bookkeeping build_engine
/// itself has no reason to store: which character this session is for,
/// and the technique-evolution lineage chain (`TechniqueEvolved` is
/// one-hop only — see the design spec's §2.1).
///
/// Mirrors game_run.dart's own `PluginContext` construction block
/// exactly, so this session composes with build_engine the same way the
/// engine's own reference run does.
///
/// `TechniqueEvolved` is a Technique-domain event, imported from the
/// public `package:build_engine/technique_plugin.dart` surface.
/// `evolveTechnique` is a pure resolver and never publishes it — a
/// caller does, explicitly, after resolving an evolution (the engine's
/// own `training_stage.dart` does exactly this), so any adapter here
/// that evolves a technique must publish this same event class for the
/// lineage subscription below to see it.
class EngineSession {
  EngineSession(int seed) : rng = RngService(seed) {
    final events = EventBus();
    final entities = EntityRegistry(events);
    final components = ComponentStore();
    final shared = CoreServices(components: components, events: events);
    context = PluginContext(
      entities: entities,
      components: components,
      events: events,
      rng: rng,
      rules: RuleEngine(
        entities: entities,
        components: components,
        events: events,
        rng: rng,
        shared: shared,
      ),
      queries: QueryEngine(QueryScope(components: components)),
      modifiers: ModifierCollection(),
      content: ContentRegistry(),
      shared: shared,
    );

    combatPlugin = CombatPlugin()..initialize(context);
    // MartialArtsPlugin.dependencies => ['combat'] must already be initialized.
    MartialArtsPlugin().initialize(context);
    PhysiquePlugin().initialize(context);
    ItemPlugin().initialize(context);
    TechniquePlugin().initialize(context);

    _lineageSubscription = context.events.subscribe<TechniqueEvolved>((event) {
      lineage[event.toId] = event.fromId;
    });
  }

  final RngService rng;
  late final PluginContext context;
  late final CombatPlugin combatPlugin;
  late final EventSubscription _lineageSubscription;

  /// Set once by `CharacterAdapter.createCharacter`; every other adapter
  /// requires it to already be set (a `StateError` on read-before-write
  /// would only ever indicate a client bug, so a plain late field is used
  /// rather than a nullable one threaded through every adapter method).
  late EntityId character;

  final Map<String, String> lineage = {};

  void dispose() => _lineageSubscription.cancel();
}
