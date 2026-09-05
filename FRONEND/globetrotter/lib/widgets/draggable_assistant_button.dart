import 'package:flutter/material.dart';

/// Floating, draggable AI assistant bubble — same drag mechanics as
/// [DraggableLanguageButton] (tap-vs-drag threshold, edge clamping), so it
/// can be moved out of the way instead of sitting fixed in one corner.
class DraggableAssistantButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool hidden;
  final Offset initialOffset;

  const DraggableAssistantButton({
    super.key,
    required this.onTap,
    this.hidden = false,
    this.initialOffset = const Offset(-1, -1), // -1 = "from the right/bottom edge"
  });

  @override
  State<DraggableAssistantButton> createState() => _DraggableAssistantButtonState();
}

class _DraggableAssistantButtonState extends State<DraggableAssistantButton> {
  Offset? _position;
  Offset _dragAccum = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const bubbleSize = 56.0;
    const hitPadding = 10.0;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    _position ??= Offset(
      widget.initialOffset.dx < 0
          ? size.width + widget.initialOffset.dx - bubbleSize - 20
          : widget.initialOffset.dx,
      widget.initialOffset.dy < 0
          ? size.height + widget.initialOffset.dy - bubbleSize - 90 - bottomInset
          : widget.initialOffset.dy,
    );

    final scheme = Theme.of(context).colorScheme;

    return Positioned(
      left: _position!.dx - hitPadding,
      top: _position!.dy - hitPadding,
      child: IgnorePointer(
        ignoring: widget.hidden,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          offset: widget.hidden ? const Offset(0, 0.4) : Offset.zero,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: widget.hidden ? 0 : 1,
            child: Listener(
              // Same reasoning as DraggableLanguageButton: raw pointer events
              // via Listener, not GestureDetector.onPan*, so dragging always
              // wins against the page's own vertical scroll gesture.
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _dragAccum = Offset.zero,
              onPointerMove: (event) {
                setState(() {
                  _dragAccum += event.delta;
                  var next = _position! + event.delta;
                  next = Offset(
                    next.dx.clamp(4.0, size.width - bubbleSize - 4),
                    next.dy.clamp(4.0, size.height - bubbleSize - 4),
                  );
                  _position = next;
                });
              },
              onPointerUp: (_) {
                if (_dragAccum.distance < 18) widget.onTap();
              },
              child: Padding(
                padding: const EdgeInsets.all(hitPadding),
                child: Material(
                  color: scheme.secondary,
                  shape: const CircleBorder(),
                  elevation: 6,
                  shadowColor: scheme.secondary.withValues(alpha: 0.4),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Icon(Icons.smart_toy_outlined, color: scheme.onSecondary, size: 26),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
