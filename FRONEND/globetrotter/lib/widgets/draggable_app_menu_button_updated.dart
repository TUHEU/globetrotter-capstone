import 'package:flutter/material.dart';

/// Bulle flottante et déplaçable pour accéder au menu général — style similaire
/// à DraggableLanguageButton avec le logo de l'app, plutôt qu'un simple bouton
/// menu fixe avec une icône hamburger.
///
/// Comportement :
/// - Appui simple (sans déplacement) → ouvre le menu de navigation
/// - Glisser → déplace la bulle n'importe où à l'écran
class DraggableAppMenuButton extends StatefulWidget {
  final Function()? onMenuPressed;
  final Offset initialOffset;
  final bool hidden;

  const DraggableAppMenuButton({
    Key? key,
    this.onMenuPressed,
    this.initialOffset = const Offset(24, 80),
    this.hidden = false,
  }) : super(key: key);

  @override
  State<DraggableAppMenuButton> createState() => _DraggableAppMenuButtonState();
}

class _DraggableAppMenuButtonState extends State<DraggableAppMenuButton> {
  Offset? _position; // null tant qu'on n'a pas encore mesuré l'écran
  Offset _dragAccum = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const bubbleSize = 52.0;
    const hitPadding = 12.0;

    // Position initiale calculée une seule fois
    _position ??= Offset(
      widget.initialOffset.dx < 0
          ? size.width + widget.initialOffset.dx - bubbleSize
          : widget.initialOffset.dx,
      widget.initialOffset.dy + MediaQuery.of(context).padding.top,
    );

    if (widget.hidden) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _position!.dx - hitPadding,
      top: _position!.dy - hitPadding,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _dragAccum = Offset.zero,
        onPointerMove: (event) {
          setState(() {
            _dragAccum += event.delta;
            var next = _position! + event.delta;
            // Reste dans les limites de l'écran
            next = Offset(
              next.dx.clamp(4.0, size.width - bubbleSize - 4),
              next.dy.clamp(4.0, size.height - bubbleSize - 4),
            );
            _position = next;
          });
        },
        onPointerUp: (_) {
          // Seuil généreux pour distinguer tap et glisser
          if (_dragAccum.distance < 18) {
            widget.onMenuPressed?.call();
          }
        },
        child: Padding(
          padding: EdgeInsets.all(hitPadding),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            elevation: 6,
            child: Container(
              width: bubbleSize,
              height: bubbleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.4,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  )
                ],
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
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFF0F2418),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.menu,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  // Badge menu en bas de la bulle
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF0F2418),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DraggableMenuStack extends StatefulWidget {
  final Widget child;
  final Function()? onMenuPressed;
  final bool showMenu;

  const DraggableMenuStack({
    Key? key,
    required this.child,
    this.onMenuPressed,
    this.showMenu = true,
  }) : super(key: key);

  @override
  State<DraggableMenuStack> createState() => _DraggableMenuStackState();
}

class _DraggableMenuStackState extends State<DraggableMenuStack> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.showMenu)
          DraggableAppMenuButton(
            onMenuPressed: widget.onMenuPressed,
          ),
      ],
    );
  }
}
