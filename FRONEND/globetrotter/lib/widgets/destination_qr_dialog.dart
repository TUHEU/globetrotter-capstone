import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/constants.dart';
import '../models/destination.dart';
import '../services/share_service.dart';

/// Affiche le QR code du lien profond d'une destination
/// (`ApiConstants.destinationLink`, le même format que le partage/lien
/// existant - voir deep_link_service.dart pour comment il est ouvert).
/// Scanner ce code avec N'IMPORTE QUEL scanner (pas seulement celui de
/// cette app) ouvre directement la fiche du lieu dans le navigateur.
///
/// NOTE dépendance : nécessite le package `qr_flutter` dans pubspec.yaml
/// (pas présent avant cet ajout) : qr_flutter: ^4.1.0
Future<void> showDestinationQrDialog(BuildContext context, Destination destination) {
  final link = ApiConstants.destinationLink(destination.id);
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(destination.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: link,
              version: QrVersions.auto,
              size: 220,
              gapless: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Scannez pour ouvrir ce lieu directement',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.share_outlined, size: 18),
          label: const Text('Partager le lien'),
          onPressed: () => ShareService.shareText('${destination.name} — $link'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );
}
