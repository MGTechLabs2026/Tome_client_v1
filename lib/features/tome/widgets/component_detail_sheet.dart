// lib/features/tome/widgets/component_detail_sheet.dart
import 'package:flutter/material.dart';

import '../../../core/models/item_view.dart';
import '../../../core/models/technique_view.dart';

String _stateLabel(ItemDisplayState state) => switch (state) {
      ItemDisplayState.locked => 'LOCKED',
      ItemDisplayState.usable => 'USABLE',
      ItemDisplayState.mastered => 'MASTERED',
      ItemDisplayState.equipped => 'EQUIPPED',
    };

Future<void> showComponentDetail(
  BuildContext context, {
  ItemView? item,
  TechniqueView? technique,
  required VoidCallback onTrain,
  VoidCallback? onEquip,
  VoidCallback? onUnequip,
  VoidCallback? onUpgrade,
  VoidCallback? onCombine,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item?.name ?? technique?.name ?? '', style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          if (item != null) ...[
            Text(_stateLabel(item.state), style: const TextStyle(fontWeight: FontWeight.bold)),
            if (item.state == ItemDisplayState.locked)
              Text(
                '${item.masteryProgress.toStringAsFixed(0)} / '
                '${item.masteryThresholds.isEmpty ? '-' : item.masteryThresholds.first}',
              ),
            for (final entry in item.properties.entries) Text('${entry.key}: +${entry.value}'),
            if (item.combinableWith.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  const Text('Combinable with → '),
                  if (onCombine != null)
                    TextButton(onPressed: onCombine, child: const Text('Combine')),
                ]),
              ),
          ],
          if (technique != null) ...[
            Text(
              technique.learned
                  ? 'LEARNED'
                  : (technique.discovered ? 'DISCOVERED' : 'UNKNOWN'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (technique.evolvedFromId != null)
              Text('Evolved from: ${technique.evolvedFromId}'),
            for (final entry in technique.properties.entries)
              Text('${entry.key}: ${entry.value}'),
          ],
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            if (item?.state != ItemDisplayState.equipped && (item != null || technique != null))
              FilledButton(onPressed: onTrain, child: const Text('Train')),
            if (onEquip != null) FilledButton(onPressed: onEquip, child: const Text('Equip')),
            if (onUnequip != null)
              OutlinedButton(onPressed: onUnequip, child: const Text('Unequip')),
            if (onUpgrade != null)
              IconButton(onPressed: onUpgrade, icon: const Icon(Icons.hardware)),
          ]),
        ],
      ),
    ),
  );
}
