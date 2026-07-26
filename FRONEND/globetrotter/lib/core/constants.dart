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
  /// Laisse vide pour toujours utiliser prodUrl, même en dev.
  static const String lanIp = '';

  static String get baseUrl {
    // Builds de production (flutter build apk/web/windows --release)
    // -> tout le monde parle au MÊME backend en ligne.
    if (kReleaseMode) return prodUrl;

    // Mode développement (flutter run) :
    if (lanIp.isNotEmpty) return 'http://$lanIp:4200'; // backend local sur ton PC
    return prodUrl; // par défaut : dev tape aussi sur le VPS en ligne
  }
}

/// Interests used for personalized recommendations (registration + explore filters).
class PreferenceTags {
  static const List<String> all = [
    'food', 'culture', 'nature', 'history', 'art', 'shopping',
    'nightlife', 'family', 'relax', 'romance', 'photo', 'sport',
    'wildlife', 'hiking', 'luxury', 'events',
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
