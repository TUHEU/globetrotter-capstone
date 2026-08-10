import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// Import conditionnel : sur le Web, bascule vers l'implémentation réelle
// (network_image_safe_web.dart, qui a besoin de dart:js_util - une
// bibliothèque qui n'existe QUE pour le Web). Sur toutes les autres
// plateformes (Android/iOS/Windows), utilise le stub à la place, qui ne
// fait jamais rien de réel mais permet au fichier de COMPILER - même
// schéma que le bouton Google Sign-In Web ailleurs dans ce projet
// (voir services/google_web_button_web.dart + _stub.dart).
import 'network_image_safe_stub.dart'
    if (dart.library.html) 'network_image_safe_web.dart';

/// Cache mémoire partagé entre TOUTES les instances de [NetworkImageSafe]
/// (mobile uniquement - le Web utilise déjà le cache HTTP natif du
/// navigateur via de vraies balises <img>, donc n'a besoin de rien de plus).
///
/// Pourquoi c'est nécessaire : sans lui, quitter un écran puis y revenir,
/// ou simplement faire défiler une longue liste (les cartes hors-écran
/// sont détruites et reconstruites par ListView), redéclenchait un
/// téléchargement complet de la MÊME image à chaque fois - lent sur une
/// connexion faible, et un gaspillage de données à chaque fois. Avec ce
/// cache, une image déjà vue s'affiche instantanément la fois suivante.
///
/// LRU simple (LinkedHashMap conserve l'ordre d'insertion ; on retire et
/// réinsère une entrée consultée pour la ramener en fin de liste = "la
/// plus récemment utilisée"). Plafonné pour ne pas grossir indéfiniment
/// sur une session avec beaucoup d'images différentes.
class _ImageByteCache {
  static const int _maxEntries = 150;
  static final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();

  static Uint8List? get(String url) {
    final bytes = _cache.remove(url);
    if (bytes != null) _cache[url] = bytes; // ré-insérer = "toucher" (LRU)
    return bytes;
  }

  static void put(String url, Uint8List bytes) {
    _cache.remove(url);
    _cache[url] = bytes;
    if (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first); // évince la moins récemment utilisée
    }
  }
}

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
  CancelToken? _cancelToken;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      // Réponse instantanée si on a déjà vu cette image durant la session -
      // pas d'appel réseau du tout dans ce cas.
      final cached = _ImageByteCache.get(widget.url);
      if (cached != null) {
        _bytes = cached;
        _state = _LoadState.success;
      } else {
        _load();
      }
    }
  }

  @override
  void didUpdateWidget(covariant NetworkImageSafe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      // Une nouvelle URL arrive (ex: recyclage de la carte dans une liste) -
      // on annule tout ce qui était en cours pour l'ancienne avant de
      // repartir, sinon une réponse tardive pourrait écraser le nouvel état.
      _cancelToken?.cancel('url changed');
      _retryTimer?.cancel();
      _attempt = 0;
      final cached = _ImageByteCache.get(widget.url);
      if (cached != null) {
        _bytes = cached;
        _state = _LoadState.success;
      } else {
        _state = _LoadState.loading;
        _bytes = null;
        if (!kIsWeb) _load();
      }
    }
  }

  @override
  void dispose() {
    // Sans ça, une requête Dio ou un minuteur de réessai encore en vol au
    // moment où le widget disparaît (l'utilisateur quitte l'écran, ou la
    // carte sort de la liste) continue de tourner en arrière-plan pour
    // rien - gaspillage de données, et c'est exactement ce qui faisait
    // échouer les tests widgets ("A Timer is still pending even after the
    // widget tree was disposed") : Dio programme un minuteur de timeout en
    // interne dès l'appel _dio.get(...), qui restait actif après la fin du
    // test faute d'annulation explicite.
    _cancelToken?.cancel('disposed');
    _retryTimer?.cancel();
    super.dispose();
  }

  /// Délai annulable (contrairement à `await Future.delayed(...)`, dont le
  /// minuteur interne ne peut pas être arrêté une fois lancé).
  Future<void> _cancellableDelay(Duration d) {
    final completer = Completer<void>();
    _retryTimer = Timer(d, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> _load() async {
    if (widget.url.isEmpty) {
      if (mounted) setState(() => _state = _LoadState.failed);
      return;
    }
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    const maxAttempts = 3; // 1 essai initial + 2 réessais
    for (var i = _attempt; i < maxAttempts; i++) {
      try {
        final res = await _dio.get<List<int>>(
          widget.url,
          cancelToken: cancelToken,
          options: Options(responseType: ResponseType.bytes),
        );
        final data = res.data;
        if (data == null) throw Exception('empty body');
        final bytes = Uint8List.fromList(data);
        _ImageByteCache.put(widget.url, bytes);
        if (!mounted) return;
        setState(() {
          _bytes = bytes;
          _state = _LoadState.success;
        });
        return;
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) {
          return; // dispose()/nouvelle URL : on arrête là, sans retry ni setState
        }
        _attempt = i + 1;
        if (i < maxAttempts - 1) {
          await _cancellableDelay(Duration(milliseconds: 600 * (i + 1)));
          if (!mounted) return;
        }
      }
    }
    if (mounted) setState(() => _state = _LoadState.failed);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return WebImg(
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
