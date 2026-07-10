import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Warna aplikasi yang mengikuti mode terang/gelap.
///
/// Warna diakses lewat getter (mis. `AppTheme.primary`) sehingga nilainya
/// berubah otomatis saat mode diganti. Karena getter bukan `const`, widget
/// yang memakainya tidak boleh memakai `const` pada bagian tersebut.
class AppTheme {
  AppTheme._();

  /// Mode aktif. Dengarkan via [ValueListenableBuilder] di root agar seluruh
  /// UI rebuild ketika mode berubah.
  static final ValueNotifier<bool> isDark = ValueNotifier<bool>(true);

  static bool get _d => isDark.value;

  static const _prefKey = 'theme_is_dark';

  /// Muat preferensi tema tersimpan (panggil sebelum runApp).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDark.value = prefs.getBool(_prefKey) ?? true;
    } catch (_) {
      isDark.value = true;
    }
  }

  /// Ganti mode & simpan preferensi.
  static Future<void> toggle(bool dark) async {
    isDark.value = dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, dark);
    } catch (_) {}
  }

  // ── Palet ───────────────────────────────────────────────────────────────
  static Color get primary =>
      _d ? const Color(0xFF6C63FF) : const Color(0xFF5A52E0);
  static Color get secondary => const Color(0xFF03DAC6);
  static Color get background =>
      _d ? const Color(0xFF0F0F1E) : const Color(0xFFF3F4FB);
  static Color get surface => _d ? const Color(0xFF1A1A2E) : Colors.white;
  static Color get surfaceVariant =>
      _d ? const Color(0xFF16213E) : const Color(0xFFEAECF6);
  static Color get onSurface =>
      _d ? const Color(0xFFE8E8F0) : const Color(0xFF1A1A2E);
  static Color get onSurfaceMuted =>
      _d ? const Color(0xFF9090A8) : const Color(0xFF6B6B84);
  static Color get success => const Color(0xFF00C896);
  static Color get error => const Color(0xFFFF5370);
  static Color get warning => const Color(0xFFFFAB40);

  static ThemeData get theme {
    final brightness = _d ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
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
