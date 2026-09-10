import 'package:flutter/material.dart';

/// Fixed draggable menu button that stays visible with original theme
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
  State<DraggableAppMenuButton> createState() =>
      _DraggableAppMenuButtonState();
}

class _DraggableAppMenuButtonState extends State<DraggableAppMenuButton>
    with SingleTickerProviderStateMixin {
  late Offset position;
  late Offset dragStart;
  late Offset dragOffset;
  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    position = widget.initialOffset;
    dragOffset = Offset.zero;
    _snapController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _snapToEdge() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final centerX = position.dx + 28;

    Offset targetPosition;
    if (centerX < screenWidth / 2) {
      targetPosition = Offset(24, position.dy);
    } else {
      targetPosition = Offset(screenWidth - 80, position.dy);
    }

    final minY = 8.0;
    final maxY = screenHeight - 80;
    targetPosition = Offset(
      targetPosition.dx,
      targetPosition.dy.clamp(minY, maxY),
    );

    _snapAnimation = Tween<Offset>(
      begin: position,
      end: targetPosition,
    ).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeInOut),
    );

    _snapAnimation.addListener(() {
      setState(() {
        position = _snapAnimation.value;
      });
    });

    _snapController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hidden) return const SizedBox.shrink();
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
            dragStart = details.globalPosition;
            dragOffset = position;
          });
          _snapController.stop();
        },
        onPanUpdate: (details) {
          final delta = details.globalPosition - dragStart;
          final newPosition = dragOffset + delta;

          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;

          setState(() {
            position = Offset(
              newPosition.dx.clamp(24.0, screenWidth - 80),
              newPosition.dy.clamp(8.0, screenHeight - 80),
            );
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isDragging = false;
          });
          _snapToEdge();
        },
        child: Material(
          color: Colors.transparent,
          child: Tooltip(
            message: 'Menu',
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.onMenuPressed?.call(),
                  borderRadius: BorderRadius.circular(28),
                  child: Center(
                    child: Icon(
                      Icons.menu,
                      color: Colors.white,
                      size: 28,
                    ),
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
