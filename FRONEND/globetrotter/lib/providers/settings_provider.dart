import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_strings.dart';

/// Gère le thème (clair/sombre/système) et la langue (fr/en),
/// persistés localement pour survivre à un redémarrage de l'app.
class SettingsProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  String languageCode = 'fr';
  // FCFA (XAF) est la devise native de toutes les données - "USD"/"EUR"
  // sont un affichage converti pour l'utilisateur, jamais stocké ni
  // envoyé au backend (voir currency_format.dart : la conversion est
  // strictement côté client, avec un taux fixe étiqueté comme estimation
  // plutôt que de prétendre à un taux de change en direct que nous
  // n'avons pas intégré).
  String currency = 'FCFA';

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
    currency = prefs.getString('currency') ?? 'FCFA';
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

  Future<void> setCurrency(String code) async {
    currency = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', code);
  }
}
