// lib/features/tome/hall/hall_theme.dart
//
// The Lineage Hall's material tokens and lettering, carried on a
// ThemeExtension so every widget in the surface reads one source of
// truth. Palette and type character are fixed by the direction contract
// (seed 6f69b7e6); nothing here is a per-widget choice.
import 'package:flutter/material.dart';

/// Where the hall's single raking light comes from, in the board's own
/// unit square (0,0 = top-left, 1,1 = bottom-right). Every painter that
/// models light or shadow reads this, so illumination stays consistent
/// across mounts, cords, seals, and the frontispiece.
const Alignment kRakingLight = Alignment(-0.72, -0.86);

@immutable
class HallTheme extends ThemeExtension<HallTheme> {
  const HallTheme({
    required this.lacquer,
    required this.lacquerDeep,
    required this.bone,
    required this.boneDim,
    required this.vermilion,
    required this.vermilionInk,
    required this.gold,
    required this.slate,
    required this.westGround,
    required this.eastGround,
    required this.display,
    required this.displayLarge,
    required this.heading,
    required this.label,
    required this.body,
    required this.reading,
    required this.measure,
    required this.measureStrong,
  });

  /// Board grounds.
  final Color lacquer;
  final Color lacquerDeep;

  /// Mount / paper marks.
  final Color bone;
  final Color boneDim;

  /// Live relationships, chops, the strike-mark.
  final Color vermilion;
  final Color vermilionInk;

  /// Reserved: mastered only.
  final Color gold;

  /// Dead / slack / disabled.
  final Color slate;

  /// The west↔east ground gradient ends.
  final Color westGround;
  final Color eastGround;

  /// Carved display (Cinzel) — school and lineage names.
  final TextStyle display;
  final TextStyle displayLarge;

  /// Section headings (Cinzel, smaller).
  final TextStyle heading;

  /// Struck / stamped labels (Archivo, tracked, upper).
  final TextStyle label;

  /// Readouts and control text (Archivo).
  final TextStyle body;

  /// Sheet prose (Archivo, comfortable measure).
  final TextStyle reading;

  /// Leader-line quantities (SplineSansMono).
  final TextStyle measure;
  final TextStyle measureStrong;

  // Fixed palette (direction seed 6f69b7e6). Public so the app-level
  // ThemeData can seed Material's ColorScheme from the same values.
  static const cLacquer = Color(0xFF141013);
  static const cLacquerDeep = Color(0xFF0C090B);
  static const cBone = Color(0xFFE7DDCA);
  static const cBoneDim = Color(0xFF9A9384);
  static const cVermilion = Color(0xFFB23A2E);
  static const cVermilionInk = Color(0xFF8E2C22);
  static const cGold = Color(0xFFB8933F);
  static const cSlate = Color(0xFF6E7377);

  /// Ink for a locked / undiscovered mount's name and chop — dark
  /// enough to clear 4.5:1 on the bone plate (measured ~5.2:1), so a
  /// locked form is legible, not merely dim.
  static const cLockedInk = Color(0xFF554C3E);

  /// The west (warm) and east (cool) ends of the hall's one organising
  /// axis — pulled far apart in hue and value so the left half reads
  /// warm and the right half cool at a glance, never a symmetric
  /// vignette.
  static const cWestGround = Color(0xFF3A2012);
  static const cEastGround = Color(0xFF0A1A22);

  static const _lacquer = cLacquer;
  static const _lacquerDeep = cLacquerDeep;
  static const _bone = cBone;
  static const _boneDim = cBoneDim;
  static const _vermilion = cVermilion;
  static const _vermilionInk = cVermilionInk;
  static const _gold = cGold;
  static const _slate = cSlate;
  static const _westGround = cWestGround;
  static const _eastGround = cEastGround;

  factory HallTheme.standard() {
    const bone = _bone;
    return HallTheme(
      lacquer: _lacquer,
      lacquerDeep: _lacquerDeep,
      bone: bone,
      boneDim: _boneDim,
      vermilion: _vermilion,
      vermilionInk: _vermilionInk,
      gold: _gold,
      slate: _slate,
      westGround: _westGround,
      eastGround: _eastGround,
      display: const TextStyle(
        fontFamily: 'Cinzel',
        fontVariations: [FontVariation('wght', 600)],
        fontWeight: FontWeight.w600,
        fontSize: 22,
        height: 1.12,
        letterSpacing: 1.4,
        color: bone,
      ),
      displayLarge: const TextStyle(
        fontFamily: 'Cinzel',
        fontVariations: [FontVariation('wght', 700)],
        fontWeight: FontWeight.w700,
        fontSize: 34,
        height: 1.05,
        letterSpacing: 1.0,
        color: bone,
      ),
      heading: const TextStyle(
        fontFamily: 'Cinzel',
        fontVariations: [FontVariation('wght', 600)],
        fontWeight: FontWeight.w600,
        fontSize: 15,
        height: 1.2,
        letterSpacing: 2.6,
        color: bone,
      ),
      label: const TextStyle(
        fontFamily: 'Archivo',
        fontVariations: [FontVariation('wght', 640)],
        fontWeight: FontWeight.w600,
        fontSize: 10.5,
        height: 1.1,
        letterSpacing: 1.9,
        color: _boneDim,
      ),
      body: const TextStyle(
        fontFamily: 'Archivo',
        fontVariations: [FontVariation('wght', 440)],
        fontSize: 13.5,
        height: 1.35,
        letterSpacing: 0.1,
        color: bone,
      ),
      reading: const TextStyle(
        fontFamily: 'Archivo',
        fontVariations: [FontVariation('wght', 420)],
        fontSize: 14.5,
        height: 1.5,
        letterSpacing: 0.1,
        color: bone,
      ),
      measure: const TextStyle(
        fontFamily: 'SplineSansMono',
        fontVariations: [FontVariation('wght', 460)],
        fontSize: 12,
        height: 1.2,
        letterSpacing: 0.2,
        color: _boneDim,
      ),
      measureStrong: const TextStyle(
        fontFamily: 'SplineSansMono',
        fontVariations: [FontVariation('wght', 560)],
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
        height: 1.2,
        letterSpacing: 0.2,
        color: bone,
      ),
    );
  }

  /// A ground colour for a mount that hangs on the [tradition] side of
  /// the hall (`'western'` / `'eastern'`), or neutral bone otherwise.
  Color groundFor(String? tradition) => switch (tradition) {
    'western' => Color.alphaBlend(westGround.withValues(alpha: 0.5), bone),
    'eastern' => Color.alphaBlend(eastGround.withValues(alpha: 0.5), bone),
    _ => bone,
  };

  @override
  HallTheme copyWith({
    Color? lacquer,
    Color? lacquerDeep,
    Color? bone,
    Color? boneDim,
    Color? vermilion,
    Color? vermilionInk,
    Color? gold,
    Color? slate,
    Color? westGround,
    Color? eastGround,
    TextStyle? display,
    TextStyle? displayLarge,
    TextStyle? heading,
    TextStyle? label,
    TextStyle? body,
    TextStyle? reading,
    TextStyle? measure,
    TextStyle? measureStrong,
  }) {
    return HallTheme(
      lacquer: lacquer ?? this.lacquer,
      lacquerDeep: lacquerDeep ?? this.lacquerDeep,
      bone: bone ?? this.bone,
      boneDim: boneDim ?? this.boneDim,
      vermilion: vermilion ?? this.vermilion,
      vermilionInk: vermilionInk ?? this.vermilionInk,
      gold: gold ?? this.gold,
      slate: slate ?? this.slate,
      westGround: westGround ?? this.westGround,
      eastGround: eastGround ?? this.eastGround,
      display: display ?? this.display,
      displayLarge: displayLarge ?? this.displayLarge,
      heading: heading ?? this.heading,
      label: label ?? this.label,
      body: body ?? this.body,
      reading: reading ?? this.reading,
      measure: measure ?? this.measure,
      measureStrong: measureStrong ?? this.measureStrong,
    );
  }

  @override
  HallTheme lerp(ThemeExtension<HallTheme>? other, double t) {
    if (other is! HallTheme) return this;
    return HallTheme(
      lacquer: Color.lerp(lacquer, other.lacquer, t)!,
      lacquerDeep: Color.lerp(lacquerDeep, other.lacquerDeep, t)!,
      bone: Color.lerp(bone, other.bone, t)!,
      boneDim: Color.lerp(boneDim, other.boneDim, t)!,
      vermilion: Color.lerp(vermilion, other.vermilion, t)!,
      vermilionInk: Color.lerp(vermilionInk, other.vermilionInk, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      slate: Color.lerp(slate, other.slate, t)!,
      westGround: Color.lerp(westGround, other.westGround, t)!,
      eastGround: Color.lerp(eastGround, other.eastGround, t)!,
      display: TextStyle.lerp(display, other.display, t)!,
      displayLarge: TextStyle.lerp(displayLarge, other.displayLarge, t)!,
      heading: TextStyle.lerp(heading, other.heading, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      reading: TextStyle.lerp(reading, other.reading, t)!,
      measure: TextStyle.lerp(measure, other.measure, t)!,
      measureStrong: TextStyle.lerp(measureStrong, other.measureStrong, t)!,
    );
  }
}

extension HallThemeContext on BuildContext {
  HallTheme get hall =>
      Theme.of(this).extension<HallTheme>() ?? HallTheme.standard();
}
