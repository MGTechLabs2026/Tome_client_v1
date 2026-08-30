// lib/features/tome/tome_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'tome_bloc.dart';
import 'tome_event.dart';
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
                onMove: (from, to) => context.read<TomeBloc>().add(ComponentMoved(from, to)),
              ),
            ),
            ComponentTray(items: state.tray),
          ],
        ),
      ),
    );
  }
}
