// lib/core/models/seeded_random.dart
//
// A plain seeded-random contract the feature layer can depend on
// without reaching for `package:build_engine`'s RngService. The engine
// boundary (`lib/core/engine/`) supplies the real implementation off
// the run's own seeded RNG; tests can pass a scripted one.
abstract class SeededRandom {
  double nextDouble();
  int nextInt(int max);

  /// A double in `[min, max)`.
  double range(double min, double max) => min + nextDouble() * (max - min);
}
