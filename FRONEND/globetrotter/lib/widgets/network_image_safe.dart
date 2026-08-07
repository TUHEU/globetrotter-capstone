import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Image réseau qui fonctionne même quand le serveur distant (ex: Wikimedia
/// Commons) n'envoie pas d'en-têtes CORS, ET qui reste utilisable sur une
/// connexion lente/instable (courant sur mobile au Cameroun).
///
/// Pourquoi c'est nécessaire (Web) : sur Flutter Web, le moteur de rendu
/// (CanvasKit/Skwasm) dessine tout sur un <canvas>, ce qui exige un accès
/// direct aux pixels de l'image — et le navigateur bloque cet accès sans
/// CORS explicite côté serveur. Résultat : Image.network échoue
/// silencieusement (déclenche errorBuilder) même si l'URL est valide et
/// s'ouvre très bien dans un onglet du navigateur. La solution recommandée
/// par la doc Flutter elle-même
/// (https://docs.flutter.dev/platform-integration/web/web-images) est de
/// contourner le canvas et d'insérer une vraie balise HTML <img>.
///
/// Pourquoi c'est nécessaire (Mobile) : `Image.network` seul n'a AUCUN
/// timeout et AUCUNE tentative de réessai. Sur une connexion à 1-6 Ko/s
/// (vu en test), une photo de ~100 Ko peut mettre 30-100+ secondes à
/// charger ; sans timeout, elle reste bloquée en "chargement" indéfiniment
/// et, visuellement, on ne peut pas distinguer "en cours de chargement" de
/// "a échoué" — les deux affichent le même placeholder. On charge donc
/// nous-mêmes les octets via Dio avec un timeout + 2 réessais (backoff),
/// et on affiche un placeholder "appuyer pour réessayer" en cas d'échec
/// définitif plutôt que de rester bloqué silencieusement.
class NetworkImageSafe extends StatefulWidget {
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
  State<NetworkImageSafe> createState() => _NetworkImageSafeState();
}

enum _LoadState { loading, success, failed }

class _NetworkImageSafeState extends State<NetworkImageSafe> {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    // Wikimedia (et beaucoup de CDN) répondent parfois 403 à un User-Agent
    // vide/générique — on identifie l'app explicitement pour éviter ça.
    headers: const {
      'User-Agent': 'GlobeTrotterYaounde/1.0 (+https://fahglobe.duckdns.org)'
    },
  ));

  _LoadState _state = _LoadState.loading;
  Uint8List? _bytes;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _load();
  }

  @override
  void didUpdateWidget(covariant NetworkImageSafe old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _attempt = 0;
      _state = _LoadState.loading;
      _bytes = null;
      if (!kIsWeb) _load();
    }
  }

  Future<void> _load() async {
    if (widget.url.isEmpty) {
      if (mounted) setState(() => _state = _LoadState.failed);
      return;
    }
    const maxAttempts = 3; // 1 essai initial + 2 réessais
    for (var i = _attempt; i < maxAttempts; i++) {
      try {
        final res = await _dio.get<List<int>>(
          widget.url,
          options: Options(responseType: ResponseType.bytes),
        );
        final data = res.data;
        if (data == null) throw Exception('empty body');
        if (!mounted) return;
        setState(() {
          _bytes = Uint8List.fromList(data);
          _state = _LoadState.success;
        });
        return;
      } catch (_) {
        _attempt = i + 1;
        if (i < maxAttempts - 1) {
          await Future.delayed(Duration(milliseconds: 600 * (i + 1)));
        }
      }
    }
    if (mounted) setState(() => _state = _LoadState.failed);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _WebImg(
        url: widget.url,
        fit: widget.fit,
        placeholder: widget.placeholder,
      );
    }

    switch (_state) {
      case _LoadState.success:
        return Image.memory(_bytes!, fit: widget.fit, gaplessPlayback: true);
      case _LoadState.loading:
        return widget.placeholder?.call(context) ??
            Container(color: Colors.grey.shade200);
      case _LoadState.failed:
        return GestureDetector(
          onTap: () {
            _attempt = 0;
            setState(() => _state = _LoadState.loading);
            _load();
          },
          child: widget.placeholder?.call(context) ?? const SizedBox.shrink(),
        );
    }
  }
}

/// Rendu Web via une vraie balise <img>, avec gestion de l'échec (onerror)
/// et réessai automatique — HtmlElementView seul n'exposait aucun des deux.
class _WebImg extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext context)? placeholder;

  const _WebImg({required this.url, required this.fit, this.placeholder});

  @override
  State<_WebImg> createState() => _WebImgState();
}

class _WebImgState extends State<_WebImg> {
  bool _failed = false;
  int _retryCount = 0;
  dynamic _imgElement;

  void _applySrc() {
    if (_imgElement == null) return;
    // Cache-buster sur les réessais pour éviter une réponse d'erreur mise
    // en cache par le navigateur.
    final src = _retryCount == 0
        ? widget.url
        : '${widget.url}${widget.url.contains('?') ? '&' : '?'}_retry=$_retryCount';
    _imgElement.src = src;
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _failed = false;
            _retryCount++;
          });
          _applySrc();
        },
        child: widget.placeholder?.call(context) ?? const SizedBox.shrink(),
      );
    }

    return HtmlElementView.fromTagName(
      tagName: 'img',
      onElementCreated: (Object element) {
        // `dynamic` ici est volontaire : on évite un import conditionnel
        // dart:html / package:web séparé juste pour poser 3 propriétés
        // CSS + un écouteur d'erreur. Ce code ne s'exécute que sur le Web.
        final img = element as dynamic;
        _imgElement = img;
        img.style.width = '100%';
        img.style.height = '100%';
        img.style.objectFit = widget.fit == BoxFit.cover ? 'cover' : 'contain';
        img.onerror = (dynamic _) {
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
              setState(() => _failed = true);
            }
          }
        };
        _applySrc();
      },
    );
  }
}
