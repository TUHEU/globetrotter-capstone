import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final s = settings.s;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(s.appearance,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                icon: const Icon(Icons.brightness_auto_outlined, size: 18),
                label: Text(s.themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode_outlined, size: 18),
                label: Text(s.themeLight),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: const Icon(Icons.dark_mode_outlined, size: 18),
                label: Text(s.themeDark),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (sel) => settings.setThemeMode(sel.first),
          ),
          const SizedBox(height: 32),
          Text(s.language,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'fr',
                label: Text('Français'),
                icon: Text('🇫🇷'),
              ),
              ButtonSegment(
                value: 'en',
                label: Text('English'),
                icon: Text('🇬🇧'),
              ),
            ],
            selected: {settings.languageCode},
            onSelectionChanged: (sel) => settings.setLanguage(sel.first),
          ),
          const SizedBox(height: 32),
          Text(s.currency,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(s.currencyHelper, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'FCFA', label: Text('FCFA')),
              ButtonSegment(value: 'USD', label: Text(r'USD ($)')),
              ButtonSegment(value: 'EUR', label: Text('EUR (€)')),
            ],
            selected: {settings.currency},
            onSelectionChanged: (sel) => settings.setCurrency(sel.first),
          ),
        ],
      ),
    );
  }
}
