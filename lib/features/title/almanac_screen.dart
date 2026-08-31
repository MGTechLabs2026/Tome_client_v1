// lib/features/title/almanac_screen.dart
//
// ALMANAC — a browser of what the lineage has met, across every run,
// read from CodexRepository. Undiscovered entries hang as ink-smudged
// silhouettes so the shape of what's left is visible without spoiling
// the names.
//
// The catalogue below is presentation data (id + label). It is not the
// engine's registry — widgets never import build_engine — so a brand
// new style/item/technique gains an entry here when it ships.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/persistence/codex_repository.dart';
import '../tome/hall/hall_theme.dart';
import 'threshold_page.dart';

const almanacStyles = <(String, String)>[
  ('polearming', 'Polearming'),
  ('wrestling', 'Wrestling'),
  ('fencing', 'Fencing'),
  ('shaolin', 'Shaolin'),
  ('taiChi', 'Tai Chi'),
  ('kunlun', 'Kunlun'),
];

const almanacItems = <(String, String)>[
  ('polearm', 'Polearm'),
  ('chair', 'Chair'),
  ('mask', 'Mask'),
  ('rapier', 'Rapier'),
  ('staff', 'Staff'),
  ('fan', 'Fan'),
  ('towel', 'Towel'),
  ('cloth', 'Cloth'),
  ('iron_sword', 'Iron Sword'),
  ('gloves', 'Gloves'),
  ('training_staff', 'Training Staff'),
  ('cloth_armor', 'Cloth Armor'),
  ('training_shoes', 'Training Shoes'),
];

const almanacTechniques = <(String, String)>[
  ('basic_punch', 'Basic Punch'),
  ('basic_slash', 'Basic Slash'),
  ('basic_guard', 'Basic Guard'),
];

class AlmanacScreen extends StatelessWidget {
  const AlmanacScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final codex = context.read<CodexRepository>().snapshot;
    final met = codex.total;
    final known = almanacStyles.length + almanacItems.length + almanacTechniques.length;

    return ThresholdPage(
      heading: 'Almanac',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$met of $known met',
            style: hall.measure.copyWith(color: hall.boneDim),
          ),
          const SizedBox(height: 18),
          _Group(title: 'Styles', entries: almanacStyles, known: codex.styles),
          _Group(title: 'Items', entries: almanacItems, known: codex.items),
          _Group(
            title: 'Techniques',
            entries: almanacTechniques,
            known: codex.techniques,
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.entries,
    required this.known,
  });

  final String title;
  final List<(String, String)> entries;
  final Set<String> known;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: hall.label.copyWith(color: hall.boneDim),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (id, label) in entries)
                _Chip(label: label, met: known.contains(id)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.met});
  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: hall.bone.withValues(alpha: met ? 0.4 : 0.14),
        ),
      ),
      child: Text(
        met ? label : '—' * label.length.clamp(3, 9),
        style: hall.measure.copyWith(
          color: met ? hall.bone : hall.boneDim.withValues(alpha: 0.5),
          letterSpacing: met ? 0.2 : 1.5,
        ),
      ),
    );
  }
}
