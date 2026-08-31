// lib/features/title/threshold_page.dart
//
// The shared shell for the menus opened from the title screen (Almanac,
// Records, Settings): the same oiled-paper panel on the same field, a
// Cinzel heading, the page body, and a single quiet Back action.
import 'package:flutter/material.dart';

import '../tome/hall/hall_theme.dart';
import 'oiled_paper_panel.dart';
import 'threshold_button.dart';

/// The field a threshold panel floats on — flat lacquer with the hall's
/// one raking light pooled at the upper-left, plus a near-invisible
/// scrim ready for a background painting.
class ThresholdField extends StatelessWidget {
  const ThresholdField({super.key});

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: kRakingLight,
          radius: 1.4,
          colors: [
            Color.alphaBlend(hall.gold.withValues(alpha: 0.05), hall.lacquer),
            hall.lacquer,
            hall.lacquerDeep,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: hall.lacquerDeep.withValues(alpha: 0.06),
        ),
      ),
    );
  }
}

class ThresholdPage extends StatelessWidget {
  const ThresholdPage({
    super.key,
    required this.heading,
    required this.child,
    this.maxWidth = 460,
  });

  final String heading;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Scaffold(
      backgroundColor: hall.lacquer,
      body: Stack(
        children: [
          const Positioned.fill(child: ThresholdField()),
          Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: OiledPaperPanel(
                maxWidth: maxWidth,
                padding: const EdgeInsets.fromLTRB(30, 28, 30, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      heading.toUpperCase(),
                      style: hall.heading.copyWith(letterSpacing: 4),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 1,
                      color: hall.bone.withValues(alpha: 0.14),
                    ),
                    const SizedBox(height: 20),
                    child,
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ThresholdButton(
                        label: 'Back',
                        tone: ThresholdTone.quiet,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A left label / right value ledger row for the Records and Almanac
/// pages — the mono figure sits right on a faint dotted lead.
class LedgerRow extends StatelessWidget {
  const LedgerRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: hall.body),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: hall.bone.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                child: const SizedBox(height: 1),
              ),
            ),
          ),
          Text(value, style: hall.measureStrong),
        ],
      ),
    );
  }
}
