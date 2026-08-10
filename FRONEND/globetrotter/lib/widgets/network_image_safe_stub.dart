/// Stub utilisé sur toutes les plateformes SAUF le Web (Android, iOS,
/// Windows...). N'est en pratique JAMAIS instancié en dehors du Web (voir
/// le `if (kIsWeb)` dans network_image_safe.dart), mais doit exister et
/// compiler pour que l'import conditionnel se résolve sur ces plateformes
/// - voir network_image_safe_web.dart pour l'explication complète.
library;

import 'package:flutter/material.dart';

class WebImg extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext context)? placeholder;

  const WebImg({super.key, required this.url, required this.fit, this.placeholder});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
