// lib/features/tome/hall/first_run_callout.dart
//
// The one-time note pinned over the hall the first time it opens.
// Dismissible; never returns.
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
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: hall.lacquer,
          border: Border.all(color: hall.bone.withValues(alpha: 0.28)),
          boxShadow: rakingShadow(elevation: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'YOUR FIRST FORMS',
                    style: hall.heading.copyWith(fontSize: 11, letterSpacing: 2.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Both your starting forms hang ready. Train to earn a '
                    'technique or raise a form\'s mastery. Two matching forms '
                    'grow a cord you can bind.',
                    style: hall.reading.copyWith(fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            InkButton(label: 'Got it', dense: true, onPressed: onDismiss),
          ],
        ),
      ),
    );
  }
}
