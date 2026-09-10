import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../providers/destination_provider.dart';
import 'destination_detail_screen.dart';

/// Scanne le QR code d'une destination (généré par
/// destination_qr_dialog.dart) et ouvre directement sa fiche.
///
/// Accepte deux formats de contenu scanné :
/// - un lien complet du type ".../app/#/d/{id}" (ce que le QR de l'app
///   encode réellement - voir deep_link_service.dart pour le même format)
/// - un id brut ("y001") si jamais quelqu'un scanne un QR fait à la main
///
/// NOTE dépendance : nécessite le package `mobile_scanner` dans
/// pubspec.yaml (pas présent avant cet ajout) : mobile_scanner: ^6.0.2
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _handled = false;
  bool _loading = false;
  String? _error;

  String? _extractDestinationId(String raw) {
    // Lien complet : "...#/d/{id}" ou "...#d/{id}"
    final hashIndex = raw.indexOf('#');
    final tail = hashIndex >= 0 ? raw.substring(hashIndex + 1) : raw;
    final cleaned = tail.startsWith('/') ? tail.substring(1) : tail;
    final parts = cleaned.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2 && parts[0] == 'd') return parts[1];
    // Sinon, on suppose que la chaîne scannée EST l'id.
    if (raw.isNotEmpty && !raw.contains('/') && !raw.contains(' ')) return raw;
    return null;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null) return;
    final id = _extractDestinationId(raw);
    if (id == null) {
      setState(() => _error = 'QR code non reconnu.');
      return;
    }
    setState(() {
      _handled = true;
      _loading = true;
      _error = null;
    });

    final dest = await context.read<DestinationProvider>().fetchById(id);
    if (!mounted) return;
    if (dest == null) {
      setState(() {
        _handled = false;
        _loading = false;
        _error = 'Destination introuvable.';
      });
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DestinationDetailScreen(destination: dest)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner un code QR')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(onDetect: _onDetect),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: CircularProgressIndicator(),
                  ),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
