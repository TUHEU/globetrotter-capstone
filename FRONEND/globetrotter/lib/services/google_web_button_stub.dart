import 'package:flutter/material.dart';

/// Version "stub" utilisée sur toutes les plateformes SAUF le Web
/// (Android, Windows, iOS...). Le vrai bouton Google (web_only.dart) ne
/// doit JAMAIS être importé directement dans un fichier compilé pour
/// toutes les plateformes - cela casse la compilation sur Android/Windows,
/// qui n'ont pas accès aux bibliothèques web dont dépend ce paquet.
///
/// Cette fonction n'est en pratique jamais appelée en dehors du Web
/// (voir isGoogleSignInAvailable / supportsGoogleButtonTap dans
/// auth_provider.dart), mais elle doit exister pour que le code compile.
Widget renderGoogleWebButton() => const SizedBox.shrink();
