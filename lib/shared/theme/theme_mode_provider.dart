import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/preferences/shared_preferences_provider.dart';

const _kThemeModeKey = 'theme_mode';

/// Loaded in [bootstrapPreferences] before [runApp]; defaults to system.
ThemeMode _initialThemeMode = ThemeMode.system;

/// Call after [WidgetsFlutterBinding.ensureInitialized] to restore theme from prefs.
Future<void> bootstrapPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  _initialThemeMode = _parseThemeMode(prefs.getString(_kThemeModeKey));
}

ThemeMode _parseThemeMode(String? raw) {
  if (raw == null || raw.isEmpty) return ThemeMode.system;
  for (final mode in ThemeMode.values) {
    if (mode.name == raw) return mode;
  }
  return ThemeMode.system;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => _initialThemeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_kThemeModeKey, mode.name);
  }
}
