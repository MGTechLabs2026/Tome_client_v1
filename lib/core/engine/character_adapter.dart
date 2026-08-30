import 'package:build_engine/build_engine.dart';
import 'package:build_engine/combat_plugin.dart';
import 'package:build_engine/game.dart' show restoreHealth;
import 'package:build_engine/martial_arts_plugin.dart';
import 'package:build_engine/physique_plugin.dart';

import '../models/character_view.dart';
import 'engine_session.dart';

/// Creates the run's one player character (`EngineSession.character`,
/// set exactly once here — see that field's doc) and drives its
/// physique/style creation flow. `createCharacter` assigns physique
/// immediately (the engine's own random pick — `initializePhysique`
/// indexes into `PhysiqueTypes.all` via `context.rng`); style is a
/// player choice, so `availableStyles`/`synergyTraditionFor` let the UI
/// show real synergy data (the physique's tradition affinity vs. each
/// style's tradition) before `chooseStyle` commits one via `learnStyle`.
class CharacterAdapter {
  CharacterAdapter(this._session);

  final EngineSession _session;

  String _name = '';
  String _physiqueId = '';
  String _styleId = '';
  String _martialTradition = '';

  /// The `'western_affinity'`/`'eastern_affinity'` tag on [physiqueId]'s
  /// content, mapped to the matching `MartialTraditions` value — the real
  /// tradition this physique's synergy `Modifier`s favor (see
  /// physique_content.dart's `×1.25`/`×0.85` conditional modifiers).
  String _affinityTraditionFor(String physiqueId) {
    final definition = _session.context.content.get(physiqueId);
    if (definition.tags.contains('western_affinity')) {
      return MartialTraditions.western;
    }
    return MartialTraditions.eastern;
  }

  /// The current character as a view model — for surfaces (e.g. the
  /// Tome frontispiece) that render the character after creation without
  /// re-running the creation flow. Returns empty fields before
  /// [createCharacter] has run.
  CharacterView currentView() => _view();

  CharacterView _view() => CharacterView(
    name: _name,
    physiqueId: _physiqueId,
    physiqueAffinityTradition: _affinityTraditionFor(_physiqueId),
    martialTradition: _martialTradition,
    styleId: _styleId,
    healthCurrent:
        _session.context.components
            .get<HealthComponent>(_session.character)
            ?.current ??
        0,
    healthMax:
        _session.context.components
            .get<HealthComponent>(_session.character)
            ?.max ??
        0,
  );

  /// Creates the character entity, assigns a `CombatantComponent` and
  /// starting `HealthComponent`, and assigns physique (random, per the
  /// engine). `martialTradition`/`styleId` are still empty on the
  /// returned view — style is chosen next via [chooseStyle].
  CharacterView createCharacter(String name) {
    _name = name;
    final character = _session.context.characters.create();
    _session.character = character;
    _session.context.components.add(
      character,
      const CombatantComponent(team: 'player', initiative: 10),
    );
    _session.context.components.add(
      character,
      const HealthComponent(current: 100, max: 100),
    );
    _physiqueId = initializePhysique(character, _session.context);
    return _view();
  }

  /// All 6 known martial styles, western traditions first.
  List<String> availableStyles() => [
    ...stylesForTradition(MartialTraditions.western),
    ...stylesForTradition(MartialTraditions.eastern),
  ];

  /// Wraps `martialTraditionOf` so the UI can compare a candidate
  /// style's tradition against the view's `physiqueAffinityTradition`
  /// before the player commits.
  String? synergyTraditionFor(String styleId) => martialTraditionOf(styleId);

  /// Commits [styleId] via `learnStyle` and returns the completed
  /// `CharacterView`.
  CharacterView chooseStyle(String styleId) {
    _styleId = styleId;
    _martialTradition = martialTraditionOf(styleId) ?? '';
    learnStyle(_session.character, styleId, _session.context);
    return _view();
  }

  /// Heals the fighter back to full vitality — the engine's own
  /// `restoreHealth` (`package:build_engine/game.dart`), the same call
  /// the reference run makes at each run boundary. Used when a run is
  /// cleared, before the next one begins.
  void restoreVitality() => restoreHealth(_session.character, _session.context);
}
