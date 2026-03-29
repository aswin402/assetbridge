import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light(ColorScheme? scheme) {
    final cs = scheme ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo 500
          surface: const Color(0xFFFAFAFA),
          surfaceContainerLow: const Color(0xFFF4F4F5), // Zinc 100
          surfaceContainerHighest: const Color(0xFFE4E4E7), // Zinc 200
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: 0.5),
        thickness: 0.5,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: StadiumBorder(
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF18181B), // Zinc 900
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  static ThemeData dark(ColorScheme? scheme) {
    final cs = scheme ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF818CF8), // Indigo 400
          brightness: Brightness.dark,
          surface: const Color(0xFF09090B), // Zinc 950
          surfaceContainerLow: const Color(0xFF18181B), // Zinc 900
          surfaceContainerHighest: const Color(0xFF27272A), // Zinc 800
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: 0.2),
        thickness: 0.5,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: StadiumBorder(
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F5), // Zinc 100
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.black, fontSize: 11),
      ),
    );
  }
}

