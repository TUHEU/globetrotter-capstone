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
      child: Listener(
        // IMPORTANT : `Listener` reçoit les événements de pointeur bruts et
        // NE PASSE PAS par l'arène de gestes Flutter (GestureArenaManager).
        // `GestureDetector.onPan*` en revanche doit *gagner* cette arène
        // face à tout ancêtre concurrent — ici, le `SingleChildScrollView`
        // plein écran d'AuthScaffold, qui a lui aussi un reconnaisseur de
        // glissement vertical sous toute la zone où flotte la bulle.
        //
        // À la souris (PC), un simple clic ne déclenche jamais le
        // glissement vertical du ScrollView (il faut la molette), donc le
        // pan du bouton gagnait l'arène par défaut → ça marchait. Au doigt
        // (téléphone), TOUT contact-glissement est un candidat valide pour
        // le ScrollView, qui gagnait souvent l'arène à la place du bouton
        // → le bouton restait figé. `Listener` élimine ce problème : il
        // reçoit chaque `onPointerMove` qui le touche, peu importe ce que
        // fait l'arène de gestes en parallèle.
        onPointerDown: (_) => _dragAccum = Offset.zero,
        onPointerMove: (event) {
          setState(() {
            _dragAccum += event.delta;
            var next = _position! + event.delta;
            // Reste dans les limites de l'écran (avec une petite marge).
            next = Offset(
              next.dx.clamp(4.0, size.width - bubbleSize - 4),
              next.dy.clamp(4.0, size.height - bubbleSize - 4),
            );
            _position = next;
          });
        },
        onPointerUp: (_) {
          // Seuil généreux : sur un écran tactile, même un simple tap du
          // doigt bouge naturellement de quelques pixels (contact plus
          // large qu'un curseur de souris).
          if (_dragAccum.distance < 18) {
            settings.setLanguage(isFr ? 'en' : 'fr');
          }
        },
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          elevation: 6,
          child: Container(
            width: bubbleSize,
            height: bubbleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.4),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: bubbleSize,
                    height: bubbleSize,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF0F2418),
                      alignment: Alignment.center,
                      child: const Icon(Icons.public, color: Colors.white70, size: 24),
                    ),
                  ),
                ),
                // Petit badge FR/EN superposé en bas du globe, plutôt que du
                // texte brut plein cadre — garde l'icône reconnaissable.
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCD116),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0F2418), width: 1.2),
                    ),
                    child: Text(
                      isFr ? 'FR' : 'EN',
                      style: const TextStyle(
                        color: Color(0xFF0F2418),
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
