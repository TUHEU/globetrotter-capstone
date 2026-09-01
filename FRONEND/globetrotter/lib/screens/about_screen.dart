import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/settings_provider.dart';

// Garde cette valeur alignée sur la ligne "version:" de pubspec.yaml -
// Flutter n'expose pas cette info à l'app sans un package supplémentaire
// (package_info_plus), qu'on évite d'ajouter juste pour ce seul écran.
const String kAppVersion = '1.0.0';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Icon(Icons.travel_explore_rounded, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('GlobeTrotter Yaoundé',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('v$kAppVersion', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(s.aboutWhat, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(s.aboutWhatText, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 22),
          Text(s.aboutFeatures, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._featureLines(s).map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2, right: 8),
                    child: Icon(Icons.check_circle_outline, size: 16),
                  ),
                  Expanded(child: Text(f, style: theme.textTheme.bodyMedium)),
                ]),
              )),
          const SizedBox(height: 22),
          Text(s.aboutProject, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(s.aboutProjectText, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 22),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(s.aboutCommunity),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _open('https://chat.whatsapp.com/Bj2HhVMXtWB9qi2wnHn80u'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.public_outlined),
                  title: Text(s.aboutWebsite),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _open('https://fahglobe.duckdns.org'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(s.aboutMadeWith,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ),
        ],
      ),
    );
  }

  List<String> _featureLines(dynamic s) => [
        s.aboutFeature1,
        s.aboutFeature2,
        s.aboutFeature3,
        s.aboutFeature4,
        s.aboutFeature5,
        s.aboutFeature6,
      ];
}
