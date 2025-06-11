import 'package:flutter/material.dart';

/// A simple [ValueNotifier]-based theme controller.
class ThemeProvider extends ValueNotifier<ThemeMode> {
  ThemeProvider() : super(ThemeMode.system);

  /// Toggle between dark and light themes.
  void toggle() {
    value = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

/// Global instance used throughout the app.
final ThemeProvider themeProvider = ThemeProvider();
