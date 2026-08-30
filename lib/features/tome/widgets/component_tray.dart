// lib/features/tome/widgets/component_tray.dart
import 'package:flutter/material.dart';

import '../../../core/models/item_view.dart';

class ComponentTray extends StatelessWidget {
  const ComponentTray({super.key, required this.items});
  final List<ItemView> items;

  Color _borderColorFor(ItemDisplayState state) => switch (state) {
        ItemDisplayState.locked => Colors.grey,
        ItemDisplayState.usable => Colors.white70,
        ItemDisplayState.mastered => Colors.amber,
        ItemDisplayState.equipped => Colors.blueAccent,
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final item in items)
            Container(
              width: 80,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: _borderColorFor(item.state), width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(item.definitionId, textAlign: TextAlign.center)),
            ),
        ],
      ),
    );
  }
}
