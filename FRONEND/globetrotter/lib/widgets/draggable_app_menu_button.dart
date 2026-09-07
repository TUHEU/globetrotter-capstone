import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../screens/assistant_screen.dart';
import '../screens/global_chat_screen.dart';
import '../screens/submit_place_screen.dart';
import 'app_logo_badge.dart';

/// Replaces the separate AI bubble and language bubble with ONE draggable
/// button: tap it to fan out four quick actions (Language, AI, Calls, and
/// — phone only — Add a place), tap again/tap an action/tap elsewhere to
/// collapse. Still fully draggable when collapsed, same as both bubbles
/// were individually before.
class DraggableAppMenuButton extends StatefulWidget {
  final bool hidden;
  final Offset initialOffset;

  const DraggableAppMenuButton({
    super.key,
    this.hidden = false,
    this.initialOffset = const Offset(-1, -1),
  });

  @override
  State<DraggableAppMenuButton> createState() => _DraggableAppMenuButtonState();
}

class _DraggableAppMenuButtonState extends State<DraggableAppMenuButton> {
  Offset? _position;
  Offset _dragAccum = Offset.zero;
  bool _open = false;

  static const _bubbleSize = 56.0;
  static const _hitPadding = 10.0;

  void _toggleOpen() => setState(() => _open = !_open);

  void _closeAnd(VoidCallback action) {
    setState(() => _open = false);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    _position ??= Offset(
      widget.initialOffset.dx < 0
          ? size.width + widget.initialOffset.dx - _bubbleSize - 20
          : widget.initialOffset.dx,
      widget.initialOffset.dy < 0
          ? size.height + widget.initialOffset.dy - _bubbleSize - 90 - bottomInset
          : widget.initialOffset.dy,
    );

    final settings = context.watch<SettingsProvider>();
    final s = settings.s;

    // Fan the menu upward if the button sits in the lower half of the
    // screen (the common case, bottom-right start position), downward
    // otherwise - so it never tries to render off-screen.
    final fanUp = _position!.dy > size.height / 2;

    final actions = <_MenuAction>[
      _MenuAction(
        icon: Icons.smart_toy_outlined,
        label: s.isFr ? 'Assistant IA' : 'AI Assistant',
        onTap: () => _closeAnd(() => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AssistantScreen()))),
      ),
      _MenuAction(
        icon: Icons.videocam_outlined,
        label: s.isFr ? 'Appels' : 'Calls',
        onTap: () => _closeAnd(() => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const GlobalChatScreen()))),
      ),
      _MenuAction(
        icon: settings.languageCode == 'fr' ? Icons.g_translate : Icons.translate,
        label: settings.languageCode == 'fr' ? 'Français (FR)' : 'English (EN)',
        onTap: () => _closeAnd(() => settings.setLanguage(settings.languageCode == 'fr' ? 'en' : 'fr')),
      ),
      // Phone-only: adding a place (photo + GPS pin) needs a camera and
      // live GPS in-hand, which is a phone thing, not a desktop-browser
      // thing - matches how this option was scoped when asked for.
      if (!kIsWeb)
        _MenuAction(
          icon: Icons.add_location_alt_outlined,
          label: s.isFr ? 'Ajouter un lieu' : 'Add a place',
          onTap: () => _closeAnd(() => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SubmitPlaceScreen()))),
        ),
    ];

    return Stack(
      children: [
        // Full-screen transparent tap-catcher to close the menu when
        // tapping anywhere outside it - only present while open, so it
        // never intercepts normal touches otherwise.
        if (_open)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open = false),
              child: Container(color: Colors.black.withValues(alpha: 0.15)),
            ),
          ),
        Positioned(
          left: _position!.dx - _hitPadding,
          top: _position!.dy - _hitPadding,
          child: IgnorePointer(
            ignoring: widget.hidden,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              offset: widget.hidden ? const Offset(0, 0.4) : Offset.zero,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: widget.hidden ? 0 : 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  verticalDirection: fanUp ? VerticalDirection.up : VerticalDirection.down,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _mainButton(),
                    if (_open)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          verticalDirection: fanUp ? VerticalDirection.up : VerticalDirection.down,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final a in actions) _actionButton(a),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mainButton() {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _dragAccum = Offset.zero,
      onPointerMove: (event) {
        setState(() {
          _dragAccum += event.delta;
          final size = MediaQuery.of(context).size;
          var next = _position! + event.delta;
          next = Offset(
            next.dx.clamp(4.0, size.width - _bubbleSize - 4),
            next.dy.clamp(4.0, size.height - _bubbleSize - 4),
          );
          _position = next;
        });
      },
      onPointerUp: (_) {
        if (_dragAccum.distance < 18) _toggleOpen();
      },
      child: Padding(
        padding: const EdgeInsets.all(_hitPadding),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          elevation: 6,
          child: AppLogoBadge(size: _bubbleSize),
        ),
      ),
    );
  }

  Widget _actionButton(_MenuAction a) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: GestureDetector(
        onTap: a.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 4,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Theme.of(context).colorScheme.secondary,
              shape: const CircleBorder(),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(a.icon, color: Theme.of(context).colorScheme.onSecondary, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _MenuAction({required this.icon, required this.label, required this.onTap});
}
