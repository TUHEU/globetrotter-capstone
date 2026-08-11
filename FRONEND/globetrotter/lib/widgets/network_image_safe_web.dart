/// Implémentation Web de NetworkImageSafe - extraite dans son PROPRE
/// fichier, importé conditionnellement uniquement quand on compile pour
/// le Web (voir network_image_safe.dart, import conditionnel en haut).
///
/// Pourquoi cette séparation est OBLIGATOIRE : ce fichier importe des
/// bibliothèques qui n'existent QUE dans le SDK Dart compilé pour le Web
/// (`package:web`, qui s'appuie sur `dart:js_interop`) - elles n'existent
/// pas du tout pour Android/iOS/Windows. Un `kIsWeb` est une vérification
/// D'EXÉCUTION, pas une exclusion à la COMPILATION : Dart doit pouvoir
/// résoudre CHAQUE import du fichier pour CHAQUE plateforme ciblée, que ce
/// chemin de code soit atteint ou non à l'exécution. Même schéma déjà
/// utilisé dans ce projet pour le bouton Google Sign-In Web (voir
/// services/google_web_button_web.dart + google_web_button_stub.dart).
///
/// Pourquoi `dart:js_interop` + `package:web` plutôt que l'ancien
/// `dart:js_util` : `js_util`/`allowInterop` est l'ANCIENNE API
/// d'interopérabilité JS, progressivement retirée des SDK Dart récents
/// (`Target of URI doesn't exist: 'dart:js_util'` sur un SDK
/// suffisamment récent). `dart:js_interop` + `package:web` est le
/// remplacement actuel, officiellement recommandé - c'est exactement le
/// même schéma que celui documenté par Flutter lui-même pour intégrer du
/// contenu HTML (`video as web.HTMLVideoElement`) :
/// https://docs.flutter.dev/platform-integration/web/web-content-in-flutter
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Rendu Web via une vraie balise <img>, avec gestion de l'échec (onerror)
/// et réessai automatique — HtmlElementView seul n'exposait aucun des deux.
class WebImg extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext context)? placeholder;

  const WebImg({required this.url, required this.fit, this.placeholder});

  @override
  State<WebImg> createState() => WebImgState();
}

class WebImgState extends State<WebImg> {
  bool _failed = false;
  bool _loaded = false;
  int _retryCount = 0;
  web.HTMLImageElement? _imgElement;
  Timer? _stuckTimer;

  void _applySrc() {
    final img = _imgElement;
    if (img == null) return;
    // Cache-buster sur les réessais pour éviter une réponse d'erreur mise
    // en cache par le navigateur.
    final src = _retryCount == 0
        ? widget.url
        : '${widget.url}${widget.url.contains('?') ? '&' : '?'}_retry=$_retryCount';
    img.src = src;

    // Filet de sécurité : si ni onload ni onerror ne se déclenchent dans un
    // délai raisonnable (requête bloquée/qui traîne indéfiniment - DNS,
    // CDN très lent, etc.), on bascule sur le placeholder "appuyer pour
    // réessayer" au lieu de laisser l'image bloquée sur du vide pour
    // toujours. Sans ça, une image qui ne charge JAMAIS (contrairement à
    // une qui échoue proprement) restait invisible indéfiniment, sans
    // aucun recours pour l'utilisateur autre que rafraîchir toute la page.
    _stuckTimer?.cancel();
    _stuckTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_loaded && !_failed) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _stuckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _failed = false;
            _loaded = false;
            _retryCount++;
          });
          _applySrc();
        },
        child: widget.placeholder?.call(context) ?? const SizedBox.shrink(),
      );
    }

    // Stack plutôt qu'un seul widget : SANS ça, pendant que l'image charge
    // (potentiellement plusieurs secondes sur une connexion lente), rien
    // n'était affiché du tout - ni le placeholder, ni aucun indicateur -
    // juste un espace vide qui donnait l'impression que "l'image ne
    // s'affiche pas", alors qu'elle était en réalité encore en train de
    // charger en arrière-plan. Le placeholder reste visible EN DESSOUS
    // jusqu'à ce que `onload` confirme que l'image est prête à l'écran.
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_loaded) widget.placeholder?.call(context) ?? Container(color: Colors.grey.shade200),
        HtmlElementView.fromTagName(
          tagName: 'img',
          onElementCreated: (Object element) {
            // Cast typé (pas `dynamic`) - c'est exactement le schéma
            // documenté par Flutter pour HtmlElementView.fromTagName avec
            // package:web (voir le lien dans le commentaire de fichier).
            final img = element as web.HTMLImageElement;
            _imgElement = img;
            img.style.width = '100%';
            img.style.height = '100%';
            img.style.objectFit = widget.fit == BoxFit.cover ? 'cover' : 'contain';
            // `.toJS` (extension de dart:js_interop) convertit une closure
            // Dart en une vraie fonction appelable par le navigateur - le
            // remplacement direct de js_util.allowInterop(), en plus léger
            // et sans dépendre d'une bibliothèque en cours de retrait des
            // SDK Dart récents.
            //
            // addEventListener plutôt que `img.onload = ...` / `img.onerror
            // = ...` : la propriété `onerror` du DOM a une signature JS
            // ambiguë (spec historique acceptant soit un seul Event, soit
            // 5 arguments positionnels séparés) qui peut ne pas matcher
            // proprement le type strict généré par package:web.
            // addEventListener a une signature uniforme et sans ambiguïté
            // pour N'IMPORTE QUEL type d'évènement - plus sûr ici.
            img.addEventListener(
              'load',
              ((web.Event event) {
                _stuckTimer?.cancel();
                if (mounted) setState(() => _loaded = true);
              }).toJS,
            );
            img.addEventListener(
              'error',
              ((web.Event event) {
                if (mounted) {
                  // Un seul réessai automatique (réseau lent/transitoire) avant
                  // de basculer sur le placeholder "appuyer pour réessayer".
                  if (_retryCount == 0) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _retryCount = 1);
                      Future.delayed(const Duration(milliseconds: 800), _applySrc);
                    });
                  } else {
                    _stuckTimer?.cancel();
                    setState(() => _failed = true);
                  }
                }
              }).toJS,
            );
            _applySrc();
          },
        ),
      ],
    );
  }
}
