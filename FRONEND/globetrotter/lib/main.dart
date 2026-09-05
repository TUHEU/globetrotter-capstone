import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/destination_provider.dart';
import 'providers/itinerary_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/review_provider.dart';
import 'providers/assistant_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/messages_provider.dart';
import 'providers/notifications_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'widgets/globe_car_loader.dart';

void main() {
  // Fire-and-forget: permission may not resolve until a later user gesture
  // (browsers require one for the prompt), so the app never waits on this.
  NotificationService.instance.init();
  runApp(const GlobeTrotterApp());
}

class GlobeTrotterApp extends StatelessWidget {
  const GlobeTrotterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DestinationProvider()),
        ChangeNotifierProvider(create: (_) => ItineraryProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => AssistantProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
        ChangeNotifierProvider(create: (_) => MessagesProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'GlobeTrotter Yaoundé',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.themeMode,
            home: const _Bootstrap(),
          );
        },
      ),
    );
  }
}

/// Charge les préférences (thème/langue) puis tente l'auto-login,
/// avant de décider de l'écran de départ.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<bool> _future;

  @override
  void initState() {
    super.initState();
    _future = _init();
  }

  Future<bool> _init() async {
    // The globe/car loading animation is otherwise so quick to finish (auto-
    // login is usually near-instant) that it just flickers by unseen. Keep
    // it on screen for at least 5s regardless of how fast the real work
    // finishes, without ever making startup slower than necessary — the
    // real work and the timer run in parallel, not one after the other.
    final minDelay = Future.delayed(const Duration(seconds: 5));
    final result = await _doInit();
    await minDelay;
    return result;
  }

  Future<bool> _doInit() async {
    await context.read<SettingsProvider>().load();
    if (!mounted) return false;
    final auth = context.read<AuthProvider>();
    // Lance l'initialisation du SDK Google tôt, sans bloquer le démarrage
    // dessus (le formulaire email/mot de passe doit rester utilisable même
    // si Google est lent/indisponible) - voir le commentaire de
    // ensureGoogleReady() dans auth_provider.dart pour pourquoi c'est
    // nécessaire spécifiquement pour que le bouton Web fonctionne un jour.
    if (auth.isGoogleSignInAvailable) {
      unawaited(auth.ensureGoogleReady());
    }
    return auth.tryAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          // Scaffold + Center nécessaires ici : sans eux, le widget est
          // rendu collé en haut à gauche de l'écran plutôt que centré, et
          // le fond ne suit pas le thème (clair/sombre).
          return Scaffold(
            body: Center(
              child: GlobeCarLoader(message: context.watch<SettingsProvider>().s.loadingMessage),
            ),
          );
        }
        return snap.data == true ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
