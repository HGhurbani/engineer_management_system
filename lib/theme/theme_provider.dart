import 'package:flutter/material.dart';

/// A simple [ValueNotifier]-based theme controller.
class ThemeProvider extends ValueNotifier<ThemeMode> {
  ThemeProvider() : super(ThemeMode.light);

  /// Dark mode has been removed, so toggling simply ensures light mode.
  void toggle() {
    value = ThemeMode.light;
  }
}

/// Global instance used throughout the app.
final ThemeProvider themeProvider = ThemeProvider();
