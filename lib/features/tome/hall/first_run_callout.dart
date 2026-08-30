// lib/features/tome/hall/first_run_callout.dart
//
// The one-time note pinned over the starting kit the first time the hall
// opens. Dismissible; never returns.
import 'package:flutter/material.dart';

import 'hall_controls.dart';
import 'hall_theme.dart';
import 'ink.dart';

class FirstRunCallout extends StatelessWidget {
  const FirstRunCallout({super.key, required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: hall.lacquer,
          border: Border.all(color: hall.gold.withValues(alpha: 0.6)),
          boxShadow: rakingShadow(elevation: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'YOUR FIRST TWO FORMS',
              style: hall.heading.copyWith(fontSize: 12, letterSpacing: 2.4),
            ),
            const SizedBox(height: 8),
            Text(
              'The knife and the cloth are hung and ready. Drag a loose form from '
              'the rack onto any open mount, or tap a mount to read its plate. '
              'Two matching forms grow a cord you can bind.',
              style: hall.reading.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: InkButton(
                label: 'Got it',
                dense: true,
                onPressed: onDismiss,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
