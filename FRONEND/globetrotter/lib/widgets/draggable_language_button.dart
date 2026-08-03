import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

/// Bulle flottante et déplaçable pour changer de langue — remplace
/// l'ancien sélecteur FR/EN fixé en haut à droite, qui se retrouvait
/// souvent coincé sous l'encoche/la barre d'état sur mobile et devenait
/// difficile à toucher précisément (deux petits boutons côte à côte).
///
/// Comportement :
/// - Appui simple (sans déplacement) → bascule FR ⇄ EN
/// - Glisser → déplace la bulle n'importe où à l'écran, comme la bulle
///   de l'assistant IA
class DraggableLanguageButton extends StatefulWidget {
  /// Position de départ (coin haut-droit par défaut, sous la zone sûre).
  final Offset initialOffset;
  const DraggableLanguageButton({super.key, this.initialOffset = const Offset(-1, 16)});

  @override
  State<DraggableLanguageButton> createState() => _DraggableLanguageButtonState();
}

class _DraggableLanguageButtonState extends State<DraggableLanguageButton> {
  Offset? _position; // null tant qu'on n'a pas encore mesuré l'écran
  Offset _dragAccum = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const bubbleSize = 52.0;

    // Position initiale calculée une seule fois (coin haut-droit, sous
    // la zone sûre) — dx négatif dans initialOffset signifie "depuis la
    // droite".
    _position ??= Offset(
      widget.initialOffset.dx < 0
          ? size.width + widget.initialOffset.dx - bubbleSize
          : widget.initialOffset.dx,
      widget.initialOffset.dy + MediaQuery.of(context).padding.top,
    );

    final settings = context.watch<SettingsProvider>();
    final isFr = settings.languageCode == 'fr';

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanStart: (_) => _dragAccum = Offset.zero,
        onPanUpdate: (details) {
          setState(() {
            _dragAccum += details.delta;
            var next = _position! + details.delta;
            // Reste dans les limites de l'écran (avec une petite marge).
            next = Offset(
              next.dx.clamp(4.0, size.width - bubbleSize - 4),
              next.dy.clamp(4.0, size.height - bubbleSize - 4),
            );
            _position = next;
          });
        },
        onPanEnd: (_) {
          // Si le doigt a très peu bougé, on considère que c'était un
          // appui simple plutôt qu'un glissement — bascule la langue.
          if (_dragAccum.distance < 6) {
            settings.setLanguage(isFr ? 'en' : 'fr');
          }
        },
        child: Material(
          color: Colors.white.withValues(alpha: 0.14),
          shape: const CircleBorder(),
          elevation: 4,
          child: Container(
            width: bubbleSize,
            height: bubbleSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Text(
              isFr ? 'FR' : 'EN',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
