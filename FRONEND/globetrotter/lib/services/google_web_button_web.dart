import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Version RÉELLE, utilisée uniquement quand on compile pour le Web -
/// voir l'import conditionnel dans auth_provider.dart
/// (`if (dart.library.html)`), qui bascule vers ce fichier au lieu du
/// stub uniquement sur cette plateforme.
Widget renderGoogleWebButton() => web.renderButton();
