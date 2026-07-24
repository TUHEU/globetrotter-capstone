import 'dart:ui';
import 'package:flutter/material.dart';

/// Shared premium background + glass card used by Login and Register screens.
/// - Mobile: single column, glass card over the scenery
/// - Web/Desktop (>= 900px): branding panel on the left, form on the right
class AuthScaffold extends StatelessWidget {
  final Widget form;
  final String title;
  final String subtitle;

  const AuthScaffold({
    super.key,
    required this.form,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      body: Stack(
        children: [
          // Gradient sky
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0E5428),
                  Color(0xFF123B24),
                  Color(0xFF0F2418),
                ],
              ),
            ),
          ),
          // Soft decorative glows
          const Positioned(
            top: -90,
            right: -60,
            child: _Glow(color: Color(0xFFFCD116), size: 320),
          ),
          const Positioned(
            bottom: 120,
            left: -80,
            child: _Glow(color: Color(0xFFCE1126), size: 260),
          ),
          // Yaoundé hills silhouette
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 180),
              painter: _HillsPainter(),
            ),
          ),
          SafeArea(
            child: wide
                ? Row(
                    children: [
                      Expanded(
                        child: _BrandPanel(
                          title: title,
                          subtitle: subtitle,
                          large: true,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(32),
                            child: _GlassCard(child: form),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BrandPanel(
                            title: title,
                            subtitle: subtitle,
                            large: false,
                          ),
                          const SizedBox(height: 28),
                          _GlassCard(child: form),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool large;
  const _BrandPanel({
    required this.title,
    required this.subtitle,
    required this.large,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: child,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo badge
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFCD116), Color(0xFFF0A500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFCD116).withValues(alpha: 0.45),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.travel_explore,
              size: large ? 64 : 48,
              color: const Color(0xFF0F2418),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: large ? 44 : 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: large ? 17 : 14.5,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ),
          if (large) ...[
            const SizedBox(height: 28),
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: const [
                _FeaturePill(
                  icon: Icons.place_outlined,
                  label: "26+ lieux à Yaoundé",
                ),
                _FeaturePill(
                  icon: Icons.auto_awesome,
                  label: "Recos personnalisées",
                ),
                _FeaturePill(
                  icon: Icons.map_outlined,
                  label: "Sorties partagées",
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFCD116)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 32 * (1 - t)), child: c),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 36,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.35),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _HillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final back = Paint()
      ..color = const Color(0xFF1B7A3D).withValues(alpha: 0.35);
    final front = Paint()
      ..color = const Color(0xFF0A1A10).withValues(alpha: 0.9);

    final p1 = Path()
      ..moveTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.15, h * 0.15, w * 0.32, h * 0.5)
      ..quadraticBezierTo(w * 0.5, h * 0.9, w * 0.66, h * 0.4)
      ..quadraticBezierTo(w * 0.82, h * 0.05, w, h * 0.5)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(p1, back);

    final p2 = Path()
      ..moveTo(0, h * 0.8)
      ..quadraticBezierTo(w * 0.22, h * 0.45, w * 0.45, h * 0.78)
      ..quadraticBezierTo(w * 0.68, h * 1.05, w * 0.85, h * 0.7)
      ..quadraticBezierTo(w * 0.94, h * 0.55, w, h * 0.68)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(p2, front);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shared glass-style input decoration for auth forms.
InputDecoration glassInput(
  BuildContext context, {
  required String label,
  required IconData icon,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
    prefixIcon: Icon(icon, color: const Color(0xFFFCD116), size: 22),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.08),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFFCD116), width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFFF8A80)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFFF8A80), width: 1.6),
    ),
    errorStyle: const TextStyle(color: Color(0xFFFFB4AB)),
  );
}

/// Gradient primary button used across auth screens.
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final String label;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFCD116), Color(0xFFF0A500)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFCD116).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: const Color(0xFF0F2418),
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Color(0xFF0F2418),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}
