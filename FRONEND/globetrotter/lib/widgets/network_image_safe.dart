import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Image réseau qui fonctionne même quand le serveur distant (ex: Wikimedia
/// Commons) n'envoie pas d'en-têtes CORS.
///
/// Pourquoi c'est nécessaire : sur Flutter Web, le moteur de rendu
/// (CanvasKit/Skwasm) dessine tout sur un <canvas>, ce qui exige un accès
/// direct aux pixels de l'image — et le navigateur bloque cet accès sans
/// CORS explicite côté serveur. Résultat : Image.network échoue
/// silencieusement (déclenche errorBuilder) même si l'URL est valide et
/// s'ouvre très bien dans un onglet du navigateur.
///
/// La solution recommandée par la doc Flutter elle-même
/// (https://docs.flutter.dev/platform-integration/web/web-images) est de
/// contourner le canvas et d'insérer une vraie balise HTML <img> - ce que
/// fait ce widget via HtmlElementView, UNIQUEMENT sur le Web. Sur
/// Android/Windows, ce problème n'existe pas du tout (pas de canvas, pas de
/// CORS), donc on garde simplement Image.network normal.
class NetworkImageSafe extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext context)? placeholder;

  const NetworkImageSafe({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return HtmlElementView.fromTagName(
        tagName: 'img',
        onElementCreated: (Object element) {
          // `dynamic` ici est volontaire : on évite un import conditionnel
          // dart:html / package:web séparé juste pour poser 3 propriétés
          // CSS. Ce code ne s'exécute de toute façon que sur le Web.
          final img = element as dynamic;
          img.src = url;
          img.style.width = '100%';
          img.style.height = '100%';
          img.style.objectFit = fit == BoxFit.cover ? 'cover' : 'contain';
        },
      );
    }
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder?.call(context) ?? const SizedBox.shrink(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : (placeholder?.call(context) ?? Container(color: Colors.grey.shade200)),
    );
  }
}
