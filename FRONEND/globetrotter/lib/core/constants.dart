import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

class ApiConstants {
  /// ======================= IMPORTANT =======================
  /// URL PUBLIQUE du backend hébergé (VPS + Nginx + HTTPS).
  /// C'est CETTE adresse que TOUTES les versions release
  /// (APK Android, App Web, exe Windows) utilisent —
  /// c'est ce qui fait que tout le monde partage les mêmes
  /// comptes, sorties et recommandations.
  /// PAS de "/" à la fin — sinon double-slash dans les requêtes.
  /// =========================================================
  static const String prodUrl = 'https://fahglobe.duckdns.org';

  /// Pour tester sur un téléphone physique en dev LOCAL
  /// (backend lancé sur ton PC, pas sur le VPS) :
  /// mets l'IP LAN de ton PC (ipconfig), ex: '192.168.1.20'
  /// Pour tester dans Chrome sur CE PC (flutter run -d chrome), mets 'localhost'.
  /// Laisse vide pour toujours utiliser prodUrl, même en dev.
  static const String lanIp = 'localhost';

  static String get baseUrl {
    // Builds de production (flutter build apk/web/windows --release)
    // -> tout le monde parle au MÊME backend en ligne.
    if (kReleaseMode) return prodUrl;

    // Mode développement (flutter run) :
    // Port 8000 = celui de l'api-gateway (docker compose), pas 4200.
    if (lanIp.isNotEmpty) return 'http://$lanIp:8000';
    return prodUrl; // par défaut : dev tape aussi sur le VPS en ligne
  }

  /// ======================= GOOGLE SIGN-IN =======================
  /// Le Client ID OAuth "Web" créé sur Google Cloud Console
  /// (console.cloud.google.com -> APIs & Services -> Identifiants).
  /// Nécessaire UNIQUEMENT pour la version Web (Android/iOS s'en passent).
  /// Format : "123456-abc.apps.googleusercontent.com"
  /// Laisse vide tant que tu n'as pas créé ce Client ID — le bouton
  /// "Continuer avec Google" reste alors désactivé proprement, sans crash.
  /// ================================================================
  static const String googleWebClientId =
      '73728796488-gqeqqmhbp26j8amg3m75lqkvi9h323a9.apps.googleusercontent.com';
}

/// Interests used for personalized recommendations (registration + explore filters).
class PreferenceTags {
  static const List<String> all = [
    'food',
    'culture',
    'nature',
    'history',
    'art',
    'shopping',
    'nightlife',
    'family',
    'relax',
    'romance',
    'photo',
    'sport',
    'wildlife',
    'hiking',
    'luxury',
    'events',
  ];
}

/// Place categories in Yaoundé.
class PlaceCategories {
  static const Map<String, IconData> all = {
    'attraction': Icons.account_balance,
    'museum': Icons.museum_outlined,
    'nature': Icons.park_outlined,
    'market': Icons.storefront_outlined,
    'restaurant': Icons.restaurant_outlined,
    'cafe': Icons.local_cafe_outlined,
    'hotel': Icons.hotel_outlined,
    'entertainment': Icons.celebration_outlined,
    'education': Icons.school_outlined,
    'sports': Icons.stadium_outlined,
    'supermarket': Icons.shopping_cart_outlined,
  };

  static const Map<String, String> labels = {
    'attraction': 'Attractions',
    'museum': 'Musées',
    'nature': 'Nature',
    'market': 'Marchés',
    'restaurant': 'Restaurants',
    'cafe': 'Cafés',
    'hotel': 'Hôtels',
    'entertainment': 'Sorties',
    'education': 'Écoles & Universités',
    'sports': 'Sport',
    'supermarket': 'Supermarchés',
  };
}

/// Formats 12000 -> "12 000 FCFA", 0 -> "Gratuit"
String formatFcfa(int amount) {
  if (amount == 0) return 'Gratuit';
  final s = amount.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '$buf FCFA';
}
