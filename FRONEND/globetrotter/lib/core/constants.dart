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
    // Port 4200 = celui de l'api-gateway en local (docker compose up --build,
    // sans fichier local séparé) - même port que la prod (Nginx sur le VPS),
    // donc un seul et même docker-compose.yml sert pour les deux.
    if (lanIp.isNotEmpty) return 'http://$lanIp:4200';
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

  /// Lien "profond" partageable (voir DeepLinkService pour le pourquoi du
  /// format en "#"). Toujours basé sur prodUrl, MÊME en dev - un lien
  /// partagé doit fonctionner pour la personne qui le reçoit, qui n'a pas
  /// ton backend local sur son téléphone.
  static String destinationLink(String id) => '$prodUrl/app/#/d/$id';
  static String itineraryLink(String id) => '$prodUrl/app/#/i/$id';

  /// Les photos des destinations viennent maintenant du backend lui-même
  /// (recommendation-service/static/images/*.jpg, servi via l'API Gateway
  /// sous /static/...) plutôt que d'URLs externes (Unsplash/Wikimedia).
  /// destinations.json ne contient donc plus qu'un CHEMIN relatif, ex:
  /// "/static/images/y001.jpg" - il faut le préfixer avec baseUrl avant
  /// de le passer à NetworkImageSafe. On garde la compatibilité avec une
  /// URL déjà absolue (http/https) au cas où une destination future
  /// pointerait encore vers une image externe.
  static String resolveImageUrl(String image) {
    if (image.isEmpty) return image;
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }
    return image.startsWith('/') ? '$baseUrl$image' : '$baseUrl/$image';
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
    'education': Icons.school_outlined,
    'sports': Icons.stadium_outlined,
    'supermarket': Icons.shopping_cart_outlined,
    'administrative': Icons.account_balance_outlined,
    'health': Icons.local_hospital_outlined,
    'transport': Icons.flight_outlined,
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
    'administrative': 'Administration',
    'health': 'Santé',
    'transport': 'Transport',
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

/// Taux approximatifs et FIXES (pas un taux de change en direct - aucune
/// API de conversion n'est intégrée). Volontairement affiché avec un "≈"
/// pour ne jamais laisser croire à une précision qu'on n'a pas. FCFA
/// (XAF) reste la devise native de toutes les données stockées - cette
/// fonction ne fait qu'un affichage converti à la volée, jamais persisté.
const Map<String, double> _fcfaConversionRates = {'USD': 1 / 610, 'EUR': 1 / 655};
const Map<String, String> _currencySymbols = {'USD': r'$', 'EUR': '€'};

String formatPrice(int fcfaAmount, {required String currency, required bool isFr}) {
  if (fcfaAmount == 0) return isFr ? 'Gratuit' : 'Free';
  if (currency == 'FCFA' || !_fcfaConversionRates.containsKey(currency)) {
    return formatFcfa(fcfaAmount);
  }
  final rate = _fcfaConversionRates[currency]!;
  final symbol = _currencySymbols[currency]!;
  final convertedValue = fcfaAmount * rate;
  // 2 décimales sous 10 unités (ex: "$3.42"), arrondi à l'entier au-dessus
  // (ex: "$142") - évite un faux sentiment de précision sur de gros montants.
  final decimals = convertedValue < 10 ? 2 : 0;
  return '≈ $symbol${convertedValue.toStringAsFixed(decimals)}';
}
