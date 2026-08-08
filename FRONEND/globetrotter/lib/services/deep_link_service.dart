import 'package:flutter/foundation.dart' show kIsWeb;

/// Lien profond en attente, extrait de l'URL au démarrage de l'app Web.
///
/// Pourquoi un lien "#" (fragment) plutôt qu'un vrai chemin (`/d/abc123`) :
/// tout ce qui suit un `#` dans une URL n'est JAMAIS envoyé au serveur par
/// le navigateur - donc `fahglobe.duckdns.org/app/#/d/abc123` fonctionne
/// avec la config Nginx actuelle SANS AUCUN changement serveur, alors qu'un
/// vrai chemin `/app/d/abc123` demanderait à Nginx de savoir rediriger
/// n'importe quel sous-chemin vers `index.html` (règle de fallback SPA
/// qu'on n'a pas confirmée être en place). Le compromis : ça ne fonctionne
/// que si le lien est ouvert dans un navigateur (Web) - sur mobile, il
/// s'ouvre dans le navigateur du téléphone plutôt que directement dans
/// l'appli installée. Un vrai "App Link" natif qui ouvre l'appli
/// installée directement demande une configuration Android/iOS
/// supplémentaire (empreinte de signature, fichier .well-known côté
/// serveur) qui n'a pas été mise en place ici - voir la conversation.
class DeepLinkTarget {
  final String type; // 'destination' | 'itinerary'
  final String id;
  DeepLinkTarget(this.type, this.id);
}

class DeepLinkService {
  DeepLinkService._();

  static bool _consumed = false;

  /// À appeler UNE SEULE FOIS, au démarrage (HomeScreen.initState) - renvoie
  /// le lien visé s'il y en a un, puis ne renvoie plus jamais rien pour le
  /// reste de la session (évite de re-déclencher la navigation à chaque
  /// hot-reload en dev, ou si HomeScreen se reconstruit pour une autre
  /// raison).
  static DeepLinkTarget? consumePending() {
    if (!kIsWeb || _consumed) return null;
    _consumed = true;

    final frag = Uri.base.fragment; // ex: "/d/abc123" ou "d/abc123"
    if (frag.isEmpty) return null;
    final cleaned = frag.startsWith('/') ? frag.substring(1) : frag;
    final parts = cleaned.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length < 2) return null;

    switch (parts[0]) {
      case 'd':
        return DeepLinkTarget('destination', parts[1]);
      case 'i':
        return DeepLinkTarget('itinerary', parts[1]);
      default:
        return null;
    }
  }
}
