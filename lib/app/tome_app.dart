// lib/app/tome_app.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/engine/character_adapter.dart';
import '../core/engine/combat_adapter.dart';
import '../core/engine/engine_session.dart';
import '../core/engine/item_adapter.dart';
import '../core/engine/reward_adapter.dart';
import '../core/engine/technique_adapter.dart';
import '../core/engine/tome_adapter.dart';
import '../core/engine/training_adapter.dart';
import '../core/persistence/codex_repository.dart';
import '../core/persistence/game_store.dart';
import '../core/persistence/records_repository.dart';
import '../core/persistence/settings_repository.dart';
import '../core/persistence/training_pace_repository.dart';
import '../features/run/run_bloc.dart';
import '../features/training/training_bloc.dart';
import '../routing/app_router.dart';
import 'theme.dart';

/// Reward pools the New Component loot draws from — real registered
/// `build_engine` content ids. `RewardAdapter` rolls one at random (via
/// the run's seeded RNG) from the flattened pool every loot screen,
/// **with replacement**: the same id can be offered and taken again, so
/// a duplicate can be farmed for Combine and techniques stay in the mix.
const kRewardItemPool = [
  'iron_sword',
  'gloves',
  'training_staff',
  'cloth_armor',
  'training_shoes',
];
const kRewardTechniquePool = ['basic_slash', 'basic_guard', 'basic_punch'];

class TomeApp extends StatefulWidget {
  const TomeApp({super.key, required this.runBloc, this.session, this.store});

  final RunBloc runBloc;

  /// A fixed engine session — tests pin this so NEW RUN's seed bump is
  /// ignored. In the app it is null and the session is (re)built from
  /// [RunState.sessionSeed].
  final EngineSession? session;

  /// The cross-run store. Null in tests → an in-memory store that
  /// forgets everything.
  final GameStore? store;

  @override
  State<TomeApp> createState() => _TomeAppState();
}

class _TomeAppState extends State<TomeApp> {
  late final RunBloc _runBloc = widget.runBloc;

  /// Built once — its redirect reads the live run phase, so one router
  /// survives a NEW RUN session rebuild.
  late final _router = appRouter(_runBloc);

  // Cross-run state, kept above the session-keyed subtree so it survives
  // NEW RUN.
  late final GameStore _store = widget.store ?? GameStore.memory();
  late final RecordsRepository _records = RecordsRepository(_store);
  late final CodexRepository _codex = CodexRepository(_store);
  late final SettingsRepository _settings = SettingsRepository(_store);
  late final TrainingPaceRepository _trainingPace = TrainingPaceRepository(_store);

  /// A test-pinned session never rebuilds; otherwise the session tracks
  /// [RunState.sessionSeed] and is rebuilt on NEW RUN.
  late final bool _pinned = widget.session != null;
  late int _seed = _runBloc.state.sessionSeed;
  late EngineSession _session = widget.session ?? EngineSession(_seed);
  StreamSubscription<RunState>? _runSub;

  @override
  void initState() {
    super.initState();
    if (_pinned) return;
    _runSub = _runBloc.stream.listen((s) {
      if (s.sessionSeed == _seed) return;
      // NEW RUN: swap in a fresh engine session (fighter, build, RNG).
      // Capture the outgoing session *before* setState so overlapping
      // rebuilds each dispose their own predecessor exactly once.
      final old = _session;
      setState(() {
        _seed = s.sessionSeed;
        _session = EngineSession(_seed);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    });
  }

  @override
  void dispose() {
    _runSub?.cancel();
    _session.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<GameStore>.value(value: _store),
        RepositoryProvider<RecordsRepository>.value(value: _records),
        RepositoryProvider<CodexRepository>.value(value: _codex),
        RepositoryProvider<SettingsRepository>.value(value: _settings),
        RepositoryProvider<TrainingPaceRepository>.value(value: _trainingPace),
      ],
      child: MultiRepositoryProvider(
        // Key on the session so NEW RUN tears down and rebuilds every
        // engine adapter against the fresh EngineSession.
        key: ValueKey(session),
        providers: [
          RepositoryProvider<EngineSession>.value(value: session),
          RepositoryProvider<CharacterAdapter>(
            create: (_) => CharacterAdapter(session),
          ),
          // Lazy: first read is on /tome, after character creation has set
          // session.character, so createInitialTome runs once at the right
          // time.
          RepositoryProvider<TomeAdapter>(
            create: (_) => TomeAdapter(session)
              ..createInitialTome()
              ..grantStartingKit(),
          ),
          RepositoryProvider<ItemAdapter>(create: (_) => ItemAdapter(session)),
          RepositoryProvider<TechniqueAdapter>(
            create: (_) => TechniqueAdapter(session),
          ),
          RepositoryProvider<TrainingAdapter>(
            create: (ctx) => TrainingAdapter(
              session,
              tomeAdapter: ctx.read<TomeAdapter>(),
              techniqueAdapter: ctx.read<TechniqueAdapter>(),
              codex: _codex,
            ),
          ),
          RepositoryProvider<CombatAdapter>(
            create: (ctx) =>
                CombatAdapter(session, tomeAdapter: ctx.read<TomeAdapter>()),
          ),
          RepositoryProvider<RewardAdapter>(
            create: (ctx) => RewardAdapter(
              session,
              tomeAdapter: ctx.read<TomeAdapter>(),
              techniqueAdapter: ctx.read<TechniqueAdapter>(),
              characterAdapter: ctx.read<CharacterAdapter>(),
              itemAdapter: ctx.read<ItemAdapter>(),
              itemPool: kRewardItemPool,
              techniquePool: kRewardTechniquePool,
              codex: _codex,
            ),
          ),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<RunBloc>.value(value: _runBloc),
            // Training spans 3 routes (prepare -> exercise -> result) so it
            // lives here; Combat and Loot Blocs are per-route (created in
            // app_router) so each fight/loot visit starts clean.
            BlocProvider<TrainingBloc>(
              create: (ctx) => TrainingBloc(ctx.read<TrainingAdapter>()),
            ),
          ],
          child: MaterialApp.router(
            title: 'Tome: Martial Arts',
            debugShowCheckedModeBanner: false,
            theme: tomeTheme(),
            routerConfig: _router,
            builder: (context, child) => ValueListenableBuilder<bool>(
              valueListenable: _settings.reduceMotion,
              builder: (context, reduce, _) {
                final mq = MediaQuery.of(context);
                return MediaQuery(
                  data:
                      reduce ? mq.copyWith(disableAnimations: true) : mq,
                  child: child!,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
