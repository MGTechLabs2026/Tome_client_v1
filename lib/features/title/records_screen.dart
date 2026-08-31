// lib/features/title/records_screen.dart
//
// RECORDS — the lineage's bests, read from RecordsRepository. Every
// figure is a "keep it if it beats what's stored" scalar written at run
// boundaries and once per fight; unset figures show an em dash.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/persistence/records_repository.dart';
import '../tome/hall/hall_theme.dart';
import 'threshold_page.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final r = context.read<RecordsRepository>().snapshot;
    String n(int v) => v == 0 ? '—' : '$v';

    return ThresholdPage(
      heading: 'Records',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LedgerRow(label: 'Runs cleared', value: n(r.runsCleared)),
          LedgerRow(label: 'Furthest run', value: n(r.furthestRun)),
          LedgerRow(
            label: 'Longest run',
            value: r.longestRunBouts == 0 ? '—' : '${r.longestRunBouts} bouts',
          ),
          LedgerRow(label: 'Heaviest blow', value: n(r.heaviestBlow)),
          LedgerRow(label: 'Blows landed', value: n(r.blowsLanded)),
          LedgerRow(label: 'Defences held', value: n(r.defencesHeld)),
          LedgerRow(
            label: 'Mastery from combat',
            value: r.combatMastery == 0
                ? '—'
                : (r.combatMastery / 10).toStringAsFixed(1),
          ),
          const SizedBox(height: 14),
          Text(
            r.isEmpty
                ? 'No runs on the board yet. Clear a hard fight and the '
                    'first marks land here.'
                : 'Every fight trains the build it was fought with — a clean '
                    'hit is a little mastery, a fumble is more.',
            style: hall.reading.copyWith(color: hall.boneDim),
          ),
        ],
      ),
    );
  }
}
