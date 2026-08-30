// lib/app/tome_app.dart
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
import '../features/run/run_bloc.dart';
import '../features/training/training_bloc.dart';
import '../routing/app_router.dart';
import 'theme.dart';

/// Reward pools the New Component loot draws from — real registered
/// `build_engine` content ids. `RewardAdapter` rolls one at random (via
/// the run's seeded RNG) from whatever the player has not been granted
/// yet, each loot screen, so the offered component varies run to run
/// and pick to pick.
const _rewardItemPool = [
  'iron_sword',
  'gloves',
  'training_staff',
  'cloth_armor',
  'training_shoes',
];
const _rewardTechniquePool = ['basic_slash', 'basic_guard'];

class TomeApp extends StatefulWidget {
  const TomeApp({super.key, required this.runBloc, this.session});

  final RunBloc runBloc;
  final EngineSession? session;

  @override
  State<TomeApp> createState() => _TomeAppState();
}

class _TomeAppState extends State<TomeApp> {
  late final EngineSession _session = widget.session ?? _freshSession();
  late final RunBloc _runBloc = widget.runBloc;

  EngineSession _freshSession() =>
      EngineSession(DateTime.now().millisecondsSinceEpoch);

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return MultiRepositoryProvider(
      // Key on the session so a restart tears down and rebuilds every
      // adapter against the fresh EngineSession.
      key: ValueKey(session),
      providers: [
        RepositoryProvider<EngineSession>.value(value: session),
        RepositoryProvider<CharacterAdapter>(
          create: (_) => CharacterAdapter(session),
        ),
        // Lazy: first read is on /tome, after character creation has set
        // session.character, so createInitialTome runs once at the right time.
        RepositoryProvider<TomeAdapter>(
          create:
              (_) =>
                  TomeAdapter(session)
                    ..createInitialTome()
                    ..grantStartingKit(),
        ),
        RepositoryProvider<ItemAdapter>(create: (_) => ItemAdapter(session)),
        RepositoryProvider<TechniqueAdapter>(
          create: (_) => TechniqueAdapter(session),
        ),
        RepositoryProvider<TrainingAdapter>(
          create:
              (ctx) => TrainingAdapter(
                session,
                tomeAdapter: ctx.read<TomeAdapter>(),
              ),
        ),
        RepositoryProvider<CombatAdapter>(
          create:
              (ctx) =>
                  CombatAdapter(session, tomeAdapter: ctx.read<TomeAdapter>()),
        ),
        RepositoryProvider<RewardAdapter>(
          create:
              (ctx) => RewardAdapter(
                session,
                tomeAdapter: ctx.read<TomeAdapter>(),
                techniqueAdapter: ctx.read<TechniqueAdapter>(),
                itemPool: _rewardItemPool,
                techniquePool: _rewardTechniquePool,
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
          routerConfig: appRouter(_runBloc),
        ),
      ),
    );
  }
}
