import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_strings.dart';

/// Gère le thème (clair/sombre/système) et la langue (fr/en),
/// persistés localement pour survivre à un redémarrage de l'app.
class SettingsProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  String languageCode = 'fr';

  AppStrings get s => AppStrings(languageCode);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('theme_mode');
    themeMode = switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    languageCode = prefs.getString('language_code') ?? 'fr';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  Future<void> setLanguage(String code) async {
    languageCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
  }
}
