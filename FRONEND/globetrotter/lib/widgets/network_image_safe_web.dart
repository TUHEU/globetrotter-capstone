/// Implémentation Web de NetworkImageSafe - extraite dans son PROPRE
/// fichier, importé conditionnellement uniquement quand on compile pour
/// le Web (voir network_image_safe.dart, import conditionnel en haut).
///
/// Pourquoi cette séparation est OBLIGATOIRE : ce fichier importe
/// `dart:js_util`, une bibliothèque qui n'existe QUE dans le SDK Dart
/// compilé pour le Web - elle n'existe pas du tout pour Android/iOS/
/// Windows. Avant cette séparation, `dart:js_util` était importé
/// directement en haut de network_image_safe.dart (utilisé sur TOUTES
/// les plateformes), ce qui cassait la compilation sur mobile/desktop
/// avec `Target of URI doesn't exist: 'dart:js_util'` - même si le code
/// qui l'utilise n'est en pratique jamais exécuté hors Web (protégé par
/// `if (kIsWeb)` à l'exécution). Un `kIsWeb` est une vérification
/// D'EXÉCUTION, pas une exclusion à la COMPILATION : Dart doit pouvoir
/// résoudre CHAQUE import du fichier pour CHAQUE plateforme ciblée, que
/// ce chemin de code soit atteint ou non à l'exécution. Même schéma déjà
/// utilisé dans ce projet pour le bouton Google Sign-In Web (voir
/// services/google_web_button_web.dart + google_web_button_stub.dart).
library;

import 'dart:async';
import 'dart:js_util' as js_util;

import 'package:flutter/material.dart';

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
  dynamic _imgElement;
  Timer? _stuckTimer;

  void _applySrc() {
    if (_imgElement == null) return;
    // Cache-buster sur les réessais pour éviter une réponse d'erreur mise
    // en cache par le navigateur.
    final src = _retryCount == 0
        ? widget.url
        : '${widget.url}${widget.url.contains('?') ? '&' : '?'}_retry=$_retryCount';
    _imgElement.src = src;

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
        if (!_loaded)
          widget.placeholder?.call(context) ??
              Container(color: Colors.grey.shade200),
        HtmlElementView.fromTagName(
          tagName: 'img',
          onElementCreated: (Object element) {
            // `dynamic` ici est volontaire : on évite un import conditionnel
            // dart:html / package:web séparé juste pour poser 3 propriétés
            // CSS + deux écouteurs. Ce code ne s'exécute que sur le Web.
            final img = element as dynamic;
            _imgElement = img;
            img.style.width = '100%';
            img.style.height = '100%';
            img.style.objectFit = widget.fit == BoxFit.cover
                ? 'cover'
                : 'contain';
            // js_util.allowInterop() est OBLIGATOIRE ici : les conventions
            // d'appel Dart→Web diffèrent de JS, donc assigner directement
            // une closure Dart à `.onload`/`.onerror` (ex: `img.onload =
            // (e) {...}`) plante à CHAQUE déclenchement par le navigateur -
            // exactement ce qui provoquait les "Uncaught Error" répétées
            // (une par image chargée) et empêchait toute image de
            // s'afficher correctement sur le Web. allowInterop() enveloppe
            // la closure dans un vrai wrapper JS-appelable.
            js_util.setProperty(
              img,
              'onload',
              js_util.allowInterop((dynamic _) {
                _stuckTimer?.cancel();
                if (mounted) setState(() => _loaded = true);
              }),
            );
            js_util.setProperty(
              img,
              'onerror',
              js_util.allowInterop((dynamic _) {
                if (mounted) {
                  // Un seul réessai automatique (réseau lent/transitoire) avant
                  // de basculer sur le placeholder "appuyer pour réessayer".
                  if (_retryCount == 0) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _retryCount = 1);
                      Future.delayed(
                        const Duration(milliseconds: 800),
                        _applySrc,
                      );
                    });
                  } else {
                    _stuckTimer?.cancel();
                    setState(() => _failed = true);
                  }
                }
              }),
            );
            _applySrc();
          },
        ),
      ],
    );
  }
}
