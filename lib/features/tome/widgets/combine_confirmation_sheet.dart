// lib/features/tome/widgets/combine_confirmation_sheet.dart
import 'package:flutter/material.dart';

import '../../../core/models/item_view.dart';

Future<void> showCombineConfirmation(
  BuildContext context, {
  required List<ItemView> matched,
  required VoidCallback onConfirm,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Combine ${matched.length} × ${matched.first.name}',
              style: const TextStyle(fontSize: 20)),
          Text('Cost: ${matched.first.itemClass} upgrade point(s)'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text('Attempt Combine'),
          ),
        ],
      ),
    ),
  );
}
