import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../services/location_service.dart';

/// Flèche qui pointe TOUJOURS vers la destination, peu importe l'orientation
/// actuelle du téléphone dans la main de l'utilisateur - exactement comme
/// une boussole physique, mais qui vise un point GPS au lieu du nord.
///
/// Fonctionnement : `flutter_compass` donne le cap actuel du téléphone
/// (0-360°, 0 = nord magnétique) ; `LocationService.bearingBetween` donne
/// le cap absolu à suivre pour rejoindre la destination. La rotation
/// affichée est simplement la différence entre les deux - si elle vaut 0°,
/// la flèche pointe "droit devant" l'écran, ce qui veut dire qu'on marche
/// dans la bonne direction. Si elle vaut 90°, il faut tourner à droite, etc.
class DirectionArrow extends StatefulWidget {
  final double? myLat;
  final double? myLng;
  final double targetLat;
  final double targetLng;

  const DirectionArrow({
    super.key,
    required this.myLat,
    required this.myLng,
    required this.targetLat,
    required this.targetLng,
  });

  @override
  State<DirectionArrow> createState() => _DirectionArrowState();
}

class _DirectionArrowState extends State<DirectionArrow> {
  double? _deviceHeading;
  StreamSubscription<CompassEvent>? _sub;

  // Valeur CONTINUE (pas limitée à [0, 360)) pour que AnimatedRotation
  // tourne toujours par le chemin le plus court. Sans ça, un passage de
  // 359° à 1° s'anime comme un tour presque complet en arrière au lieu de
  // 2° en avant - le classique bug de "l'aiguille de boussole qui devient
  // folle" quand on ignore le rebouclage à 360°.
  double _turns = 0;
  double? _lastAngleDeg;

  @override
  void initState() {
    super.initState();
    _sub = FlutterCompass.events?.listen((event) {
      // event.heading est `null` sur certains appareils Android sans
      // magnétomètre - on garde alors la dernière valeur connue (ou le cap
      // brut vers la cible en secours, voir build()) plutôt que de planter.
      if (event.heading != null && mounted) {
        setState(() => _deviceHeading = event.heading);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _advanceTurns(double targetAngleDeg) {
    if (_lastAngleDeg == null) {
      _turns = targetAngleDeg / 360;
      _lastAngleDeg = targetAngleDeg;
      return;
    }
    var delta = targetAngleDeg - _lastAngleDeg!;
    delta = ((delta + 180) % 360 + 360) % 360 - 180; // ramène dans [-180, 180]
    _turns += delta / 360;
    _lastAngleDeg = targetAngleDeg;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.myLat == null || widget.myLng == null) {
      return const SizedBox.shrink();
    }

    final bearingToTarget = LocationService.bearingBetween(
        widget.myLat!, widget.myLng!, widget.targetLat, widget.targetLng);

    // Sans boussole (capteur absent), on affiche quand même la flèche -
    // orientée directement sur le cap brut, comme une carte "nord en haut" -
    // moins pratique en marchant mais toujours mieux que rien.
    final rotationDegrees =
        _deviceHeading != null ? (bearingToTarget - _deviceHeading!) : bearingToTarget;
    _advanceTurns(rotationDegrees);

    final normalized = ((rotationDegrees % 360) + 360) % 360;
    final String hint;
    final IconData icon;
    if (normalized < 20 || normalized > 340) {
      hint = 'Continuez tout droit';
      icon = Icons.straight;
    } else if (normalized >= 160 && normalized <= 200) {
      hint = 'Faites demi-tour';
      icon = Icons.u_turn_left;
    } else if (normalized < 180) {
      hint = 'Tournez à droite';
      icon = Icons.turn_right;
    } else {
      hint = 'Tournez à gauche';
      icon = Icons.turn_left;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primaryContainer,
            border: Border.all(color: theme.colorScheme.primary, width: 2),
          ),
          child: AnimatedRotation(
            turns: _turns,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: Icon(Icons.navigation, size: 40, color: theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(hint, style: theme.textTheme.bodySmall),
          ],
        ),
        if (_deviceHeading == null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Boussole indisponible - direction approximative',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
