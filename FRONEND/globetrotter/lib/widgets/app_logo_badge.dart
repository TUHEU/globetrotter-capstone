import 'package:flutter/material.dart';

/// The app's own logo in a circular badge, used everywhere a "brand slot"
/// icon is needed (chat headers, drawer, the floating menu button) instead
/// of a generic Flutter icon standing in for GlobeTrotter itself.
class AppLogoBadge extends StatelessWidget {
  final double size;
  final Color? background;

  const AppLogoBadge({super.key, this.size = 42, this.background});

  @override
  Widget build(BuildContext context) {
    final bg = background ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: ClipOval(
        child: Image.asset(
          'assets/icon/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.public_rounded, color: Colors.white, size: size * 0.55),
        ),
      ),
    );
  }
}
