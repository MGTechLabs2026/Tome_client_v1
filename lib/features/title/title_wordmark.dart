// lib/features/title/title_wordmark.dart
//
// The game wordmark, set never drawn (DESIGN.md — The Wordmark-Is-Type
// Rule): TOME in Cinzel Display Large over the edition line in the
// mono, a hairline between, the seal chop alongside as the only
// identity mark the product carries.
import 'package:flutter/material.dart';

import '../tome/hall/hall_theme.dart';
import '../tome/hall/ink.dart';

class TitleWordmark extends StatelessWidget {
  const TitleWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOME',
              style: hall.displayLarge.copyWith(
                fontSize: 40,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SizedBox(
                width: 26,
                height: 26,
                child: CustomPaint(
                  painter: SealChopPainter(
                    contentId: 'tome:wordmark',
                    ink: hall.vermilion,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(width: 46, height: 1, color: hall.bone.withValues(alpha: 0.4)),
        const SizedBox(height: 10),
        Text(
          'THE MARTIAL ART EDITION',
          style: hall.measure.copyWith(letterSpacing: 2, color: hall.boneDim),
        ),
      ],
    );
  }
}
