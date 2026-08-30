// lib/features/training/presentation/training_presentation.dart
import 'package:flutter/widgets.dart';

/// The seam a future Flame/3D training implementation replaces -- every
/// concrete presentation reports raw millisecond timestamps up through
/// [onTap], never anything build_engine-shaped.
abstract class TrainingPresentation extends StatelessWidget {
  const TrainingPresentation({super.key});
}
