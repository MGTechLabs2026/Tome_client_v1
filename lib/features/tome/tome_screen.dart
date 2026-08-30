// lib/features/tome/tome_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/game_phase.dart';
import '../../core/models/item_view.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';
import 'tome_bloc.dart';
import 'tome_event.dart';
import 'widgets/combine_confirmation_sheet.dart';
import 'widgets/component_detail_sheet.dart';
import 'widgets/component_tray.dart';
import 'widgets/tome_grid.dart';

class TomeScreen extends StatelessWidget {
  const TomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<TomeBloc>().add(const TomeRefreshRequested());
    return Scaffold(
      appBar: AppBar(title: const Text('Your Tome')),
      body: BlocBuilder<TomeBloc, TomeState>(
        builder: (context, state) => Column(
          children: [
            Expanded(
              child: TomeGrid(
                cells: state.cells,
                width: state.width,
                ownedByInstanceValue: state.ownedByInstanceValue,
                onMove: (from, to) => context.read<TomeBloc>().add(ComponentMoved(from, to)),
              ),
            ),
            ComponentTray(
              items: state.tray,
              onItemTap: (item) => _openDetail(context, item),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: () =>
              context.read<RunBloc>().add(const PhaseCompleted(GamePhase.combatPreparation)),
          child: const Text('Start Fight'),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, ItemView item) {
    final run = context.read<RunBloc>();
    showComponentDetail(
      context,
      item: item,
      onTrain: () {
        Navigator.of(context).pop();
        run.add(TrainingRequested(item.definitionId, isTechnique: false));
      },
      onCombine: item.combinableWith.isEmpty
          ? null
          : () {
              Navigator.of(context).pop();
              _confirmCombine(context, item);
            },
    );
  }

  void _confirmCombine(BuildContext context, ItemView item) {
    final ownedByInstanceValue = context.read<TomeBloc>().state.ownedByInstanceValue;
    final matched = <ItemView>[
      item,
      for (final v in item.combinableWith)
        if (ownedByInstanceValue[v] != null) ownedByInstanceValue[v]!,
    ];
    final values = <int>[
      if (item.instanceEntityValue != null) item.instanceEntityValue!,
      ...item.combinableWith,
    ];
    final bloc = context.read<TomeBloc>();
    showCombineConfirmation(
      context,
      matched: matched,
      onConfirm: () => bloc.add(CombineRequested(values)),
    );
  }
}
