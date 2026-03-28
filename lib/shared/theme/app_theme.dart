import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light(ColorScheme? scheme) {
    final cs = scheme ?? ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB));
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      visualDensity: VisualDensity.standard,
    );
  }

  static ThemeData dark(ColorScheme? scheme) {
    final cs = scheme ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      visualDensity: VisualDensity.standard,
    );
  }
}
