// lib/features/character_creation/character_creation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/game_phase.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';
import 'character_creation_bloc.dart';
import 'character_creation_event.dart';

class CharacterCreationScreen extends StatelessWidget {
  const CharacterCreationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CharacterCreationBloc, CharacterCreationState>(
      listener: (context, state) {
        if (state.confirmed) {
          context.read<RunBloc>().add(const PhaseCompleted(GamePhase.tome));
          context.go('/tome');
        }
      },
      builder: (context, state) {
        if (state.name == null) {
          return _NameStep(
            onSubmit: (name) => context.read<CharacterCreationBloc>().add(NameSubmitted(name)),
          );
        }
        return _StyleStep(
          state: state,
          onChoose: (id) => context.read<CharacterCreationBloc>().add(StyleChosen(id)),
        );
      },
    );
  }
}

class _NameStep extends StatefulWidget {
  const _NameStep({required this.onSubmit});
  final ValueChanged<String> onSubmit;

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Name your fighter', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 16),
              TextField(controller: _controller, autofocus: true),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => widget.onSubmit(
                  _controller.text.trim().isEmpty ? 'Fighter' : _controller.text.trim(),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleStep extends StatelessWidget {
  const _StyleStep({required this.state, required this.onChoose});
  final CharacterCreationState state;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final physiqueTradition = state.character!.physiqueAffinityTradition;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Your physique: ${state.character!.physiqueId} — synergizes with $physiqueTradition training',
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              children: [
                for (final styleId in state.availableStyles)
                  _StyleCard(
                    styleId: styleId,
                    synergizes: state.synergyByStyle[styleId] == physiqueTradition,
                    onTap: () => onChoose(styleId),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({required this.styleId, required this.synergizes, required this.onTap});
  final String styleId;
  final bool synergizes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: synergizes ? Colors.green : Colors.red, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(styleId, style: const TextStyle(fontSize: 18))),
      ),
    );
  }
}
