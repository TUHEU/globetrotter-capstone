import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Écran/indicateur de chargement "cheval au galop" - silhouette dessinée
/// entièrement en CustomPainter (aucune image externe nécessaire) : les 4
/// jambes sont animées à des phases différentes du cycle pour simuler un
/// vrai mouvement de galop, avec un rebond vertical du corps synchronisé
/// (2 "temps" par cycle, comme un galop réel) plutôt qu'un simple spinner
/// générique.
class GallopingHorseLoader extends StatefulWidget {
  final String? message;
  final double size;
  const GallopingHorseLoader({super.key, this.message, this.size = 120});

  @override
  State<GallopingHorseLoader> createState() => _GallopingHorseLoaderState();
}

class _GallopingHorseLoaderState extends State<GallopingHorseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
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
            height: widget.size * 0.7,
            child: CustomPaint(
              painter: _HorsePainter(progress: _controller.value, color: theme.colorScheme.primary),
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

class _LegSpec {
  final double x;
  final double phaseOffset;
  _LegSpec({required this.x, required this.phaseOffset});
}

class _HorsePainter extends CustomPainter {
  final double progress; // 0..1, un cycle de galop complet
  final Color color;
  _HorsePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Rebond vertical (2 impacts par cycle, comme un vrai galop).
    final bounce = math.sin(progress * 2 * math.pi * 2).abs() * size.height * 0.06;
    final bodyTop = size.height * 0.25 - bounce;
    final bodyBottom = size.height * 0.55 - bounce;
    final bodyLeft = size.width * 0.15;
    final bodyRight = size.width * 0.75;

    final bodyRect = Rect.fromLTRB(bodyLeft, bodyTop, bodyRight, bodyBottom);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(size.height * 0.15)), paint);

    final neckPath = Path()
      ..moveTo(bodyRight - size.width * 0.05, bodyTop + size.height * 0.05)
      ..lineTo(size.width * 0.95, bodyTop - size.height * 0.15 - bounce)
      ..lineTo(size.width * 0.98, bodyTop - size.height * 0.02 - bounce)
      ..lineTo(bodyRight, bodyTop + size.height * 0.15)
      ..close();
    canvas.drawPath(neckPath, paint);
    canvas.drawCircle(Offset(size.width * 0.96, bodyTop - size.height * 0.12 - bounce), size.height * 0.06, paint);

    final tailSwing = math.sin(progress * 2 * math.pi * 2) * 8;
    final tailPath = Path()
      ..moveTo(bodyLeft + size.width * 0.02, bodyTop + size.height * 0.1)
      ..lineTo(bodyLeft - size.width * 0.12 + tailSwing, bodyTop + size.height * 0.3)
      ..lineTo(bodyLeft + size.width * 0.02, bodyTop + size.height * 0.2)
      ..close();
    canvas.drawPath(tailPath, paint);

    // 4 jambes à des phases différentes du cycle - pas synchronisées entre
    // elles, exactement ce qui distingue une animation de galop crédible
    // d'un simple aller-retour répété.
    final legWidth = size.width * 0.045;
    final legLength = size.height * 0.35;
    final legs = [
      _LegSpec(x: bodyLeft + size.width * 0.08, phaseOffset: 0.0),
      _LegSpec(x: bodyLeft + size.width * 0.18, phaseOffset: 0.15),
      _LegSpec(x: bodyRight - size.width * 0.22, phaseOffset: 0.5),
      _LegSpec(x: bodyRight - size.width * 0.1, phaseOffset: 0.65),
    ];

    final legPaint = Paint()
      ..color = color
      ..strokeWidth = legWidth
      ..strokeCap = StrokeCap.round;

    for (final leg in legs) {
      final legPhase = (progress + leg.phaseOffset) % 1.0;
      final swing = math.sin(legPhase * 2 * math.pi) * 0.5;
      final legTopY = bodyBottom - size.height * 0.02;
      final legBottomX = leg.x + swing * size.width * 0.08;
      final legBottomY = legTopY + legLength;
      canvas.drawLine(Offset(leg.x, legTopY), Offset(legBottomX, legBottomY), legPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HorsePainter oldDelegate) => oldDelegate.progress != progress;
}
