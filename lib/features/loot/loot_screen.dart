// lib/features/loot/loot_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'loot_bloc.dart';
import 'loot_event.dart';

class LootScreen extends StatelessWidget {
  const LootScreen({super.key, this.onApplied});

  /// Fired once the chosen loot has been applied — the router uses it to
  /// send the player back to the Tome for the next bout.
  final VoidCallback? onApplied;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LootBloc>();
    if (bloc.state.options.isEmpty && !bloc.state.applied) {
      bloc.add(const LootOffered());
    }
    return BlocConsumer<LootBloc, LootState>(
      listenWhen: (prev, next) => !prev.applied && next.applied,
      listener: (context, state) => onApplied?.call(),
      builder: (context, state) => Scaffold(
        body: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final option in state.options)
              GestureDetector(
                onTap: () => context.read<LootBloc>().add(LootChosen(option.kind)),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [Text(option.title), Text(option.detail, textAlign: TextAlign.center)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
