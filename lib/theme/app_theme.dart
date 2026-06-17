import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF6C63FF);
  static const Color secondary = Color(0xFF03DAC6);
  static const Color background = Color(0xFF0F0F1E);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceVariant = Color(0xFF16213E);
  static const Color onSurface = Color(0xFFE8E8F0);
  static const Color onSurfaceMuted = Color(0xFF9090A8);
  static const Color success = Color(0xFF00C896);
  static const Color error = Color(0xFFFF5370);
  static const Color warning = Color(0xFFFFAB40);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
    );
  }
}
