import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Écran d'accueil au tout premier lancement, montré une seule fois avant
/// LoginScreen (voir main.dart:_Bootstrap) - pas juste un slideshow de
/// bienvenue générique, mais un aperçu concret des fonctionnalités clés
/// de l'app pour que le premier écran de connexion ne tombe pas "à froid".
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  static const _seenKey = 'onboarding_seen_v1';

  static Future<bool> hasBeenSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String body;
  const _OnboardingSlide({required this.icon, required this.title, required this.body});
}

const _slides = [
  _OnboardingSlide(
    icon: Icons.explore_outlined,
    title: 'Découvrez Yaoundé',
    body: 'Des dizaines de lieux référencés - attractions, restaurants, marchés - '
        'avec prix moyens en FCFA et recommandations personnalisées.',
  ),
  _OnboardingSlide(
    icon: Icons.map_outlined,
    title: 'Planifiez vos sorties',
    body: 'Créez un itinéraire jour par jour, visualisez-le sur une carte 3D et '
        "laissez l'app optimiser le trajet entre vos arrêts.",
  ),
  _OnboardingSlide(
    icon: Icons.groups_outlined,
    title: 'Sortez entre amis',
    body: "Chat, appels audio/vidéo, partage d'itinéraire et partage du coût - "
        'organisez la sortie ensemble, du début à la fin.',
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    widget.onDone();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Passer'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(slide.icon, size: 96, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 32),
                        Text(
                          slide.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide.body,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLast
                      ? _finish
                      : () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                  child: Text(isLast ? 'Commencer' : 'Suivant'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
