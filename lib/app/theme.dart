// lib/app/theme.dart
//
// The whole app wears the Lineage Hall (direction seed 6f69b7e6): a
// lacquered near-black board, aged-bone marks, vermilion seal-ink, gold
// reserved for mastered. Every surface Material would otherwise paint
// with its own defaults — selection, scrollbar, focus, splash — is
// pulled onto the palette here.
import 'package:flutter/material.dart';

import '../features/tome/hall/hall_theme.dart';

ThemeData tomeTheme() {
  final hall = HallTheme.standard();

  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: HallTheme.cVermilion,
    onPrimary: HallTheme.cBone,
    secondary: HallTheme.cGold,
    onSecondary: Color(0xFF141013),
    error: HallTheme.cVermilion,
    onError: HallTheme.cBone,
    surface: HallTheme.cLacquer,
    onSurface: HallTheme.cBone,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: hall.lacquerDeep,
    canvasColor: hall.lacquer,
    fontFamily: 'Archivo',
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: hall.bone.withValues(alpha: 0.04),
    extensions: [hall],
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: hall.bone,
      displayColor: hall.bone,
      fontFamily: 'Archivo',
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: hall.vermilion,
      selectionColor: hall.vermilion.withValues(alpha: 0.30),
      selectionHandleColor: hall.vermilion,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(hall.bone.withValues(alpha: 0.22)),
      thickness: const WidgetStatePropertyAll(3),
      radius: const Radius.circular(0),
      crossAxisMargin: 2,
    ),
    dividerTheme: DividerThemeData(
      color: hall.bone.withValues(alpha: 0.14),
      thickness: 1,
      space: 1,
    ),
    focusColor: hall.gold.withValues(alpha: 0.55),
    tooltipTheme: TooltipThemeData(
      textStyle: hall.body.copyWith(fontSize: 12),
      decoration: BoxDecoration(
        color: hall.lacquerDeep,
        border: Border.all(color: hall.bone.withValues(alpha: 0.20)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: hall.lacquer,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Colors.black.withValues(alpha: 0.62),
      shape: const RoundedRectangleBorder(),
      elevation: 0,
    ),
  );
}
