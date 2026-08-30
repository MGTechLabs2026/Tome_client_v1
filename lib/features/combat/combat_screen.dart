// lib/features/combat/combat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'combat_bloc.dart';
import 'presentation/log_replay_combat_presentation.dart';

class CombatScreen extends StatelessWidget {
  const CombatScreen({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CombatBloc, CombatState>(
      builder: (context, state) => Scaffold(
        body: LogReplayCombatPresentation(log: state.log, onFinished: onFinished),
      ),
    );
  }
}
