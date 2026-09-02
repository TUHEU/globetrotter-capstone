import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Écran/indicateur de chargement "voiture qui fait le tour du globe" -
/// dessiné entièrement en CustomPainter (aucune image externe nécessaire),
/// remplace l'ancien GallopingHorseLoader. Le globe est un cercle avec
/// quelques méridiens/parallèles simplifiés pour suggérer une planète sans
/// avoir besoin d'une vraie carte, et la voiture orbite autour en suivant
/// un cercle légèrement plus grand, inclinée dans le sens du mouvement.
class GlobeCarLoader extends StatefulWidget {
  final String? message;
  final double size;
  const GlobeCarLoader({super.key, this.message, this.size = 120});

  @override
  State<GlobeCarLoader> createState() => _GlobeCarLoaderState();
}

class _GlobeCarLoaderState extends State<GlobeCarLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _GlobeCarPainter(
                progress: _controller.value,
                globeColor: theme.colorScheme.primary,
                carColor: theme.colorScheme.secondary,
              ),
            ),
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 14),
          Text(widget.message!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _GlobeCarPainter extends CustomPainter {
  final double progress; // 0..1, un tour complet du globe
  final Color globeColor;
  final Color carColor;
  _GlobeCarPainter({required this.progress, required this.globeColor, required this.carColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final globeRadius = size.width * 0.32;
    final orbitRadius = size.width * 0.44;

    // --- Globe ---
    final globePaint = Paint()
      ..color = globeColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, globeRadius, globePaint);

    final linePaint = Paint()
      ..color = globeColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.012;
    canvas.drawCircle(center, globeRadius, linePaint);

    // Deux méridiens (ellipses aplaties) + un parallèle - suffisant pour
    // suggérer un globe sans avoir besoin d'une vraie carte du monde.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (final squeeze in [0.32, 0.68]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: globeRadius * 2 * squeeze, height: globeRadius * 2),
        linePaint,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: globeRadius * 2, height: globeRadius * 2 * 0.34),
      linePaint,
    );
    canvas.restore();

    // --- Voiture en orbite ---
    // Angle de départ en haut (-90°) pour un mouvement horaire naturel.
    final angle = -math.pi / 2 + progress * 2 * math.pi;
    final carCenter = Offset(
      center.dx + orbitRadius * math.cos(angle),
      center.dy + orbitRadius * math.sin(angle) * 0.55, // orbite aplatie (perspective)
    );
    // La voiture passe "derrière" le globe sur la moitié haute de l'orbite
    // aplatie - on l'assombrit légèrement pour suggérer la profondeur.
    final behindGlobe = math.sin(angle) < 0;
    final carPaintColor = behindGlobe ? carColor.withValues(alpha: 0.45) : carColor;

    canvas.save();
    canvas.translate(carCenter.dx, carCenter.dy);
    // Incline la voiture dans le sens du mouvement (tangente à l'orbite).
    final tangent = angle + math.pi / 2;
    canvas.rotate(math.atan2(math.sin(tangent) * 0.55, math.cos(tangent)));
    _drawCar(canvas, size.width * 0.16, carPaintColor);
    canvas.restore();
  }

  void _drawCar(Canvas canvas, double carWidth, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final h = carWidth * 0.42;

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: carWidth, height: h),
      Radius.circular(h * 0.4),
    );
    canvas.drawRRect(body, paint);

    final cabin = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(-carWidth * 0.05, -h * 0.55), width: carWidth * 0.5, height: h * 0.55),
      Radius.circular(h * 0.25),
    );
    canvas.drawRRect(cabin, paint);

    final wheelPaint = Paint()..color = color.withValues(alpha: 0.9);
    final wheelR = h * 0.22;
    canvas.drawCircle(Offset(-carWidth * 0.28, h * 0.5), wheelR, wheelPaint);
    canvas.drawCircle(Offset(carWidth * 0.28, h * 0.5), wheelR, wheelPaint);
  }

  @override
  bool shouldRepaint(covariant _GlobeCarPainter oldDelegate) => oldDelegate.progress != progress;
}
