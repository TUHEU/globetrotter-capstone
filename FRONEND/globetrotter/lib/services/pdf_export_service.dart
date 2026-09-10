import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/destination.dart';
import '../models/itinerary.dart';

/// Génère une fiche PDF imprimable/partageable d'un itinéraire : titre,
/// dates, budget, et chaque arrêt regroupé par jour avec son prix moyen
/// et ses notes éventuelles.
///
/// NOTE dépendances : nécessite les packages `pdf` et `printing` dans
/// pubspec.yaml (aucun des deux n'était présent avant cet ajout) :
///   pdf: ^3.11.1
///   printing: ^5.13.4
class PdfExportService {
  PdfExportService._();

  static Future<void> exportAndShare({
    required Itinerary itinerary,
    required List<MapEntry<ItineraryStop, Destination>> stops,
  }) async {
    final doc = pw.Document();

    final byDay = <int, List<MapEntry<ItineraryStop, Destination>>>{};
    for (final entry in stops) {
      byDay.putIfAbsent(entry.key.day, () => []).add(entry);
    }
    final days = byDay.keys.toList()..sort();

    final totalPrice = stops.fold<int>(0, (sum, e) => sum + e.value.avgPriceFcfa);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(itinerary.title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          ),
          if (itinerary.description != null && itinerary.description!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(itinerary.description!, style: const pw.TextStyle(fontSize: 11)),
            ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (itinerary.startDate != null)
                pw.Text('Dates : ${itinerary.startDate}${itinerary.endDate != null ? ' → ${itinerary.endDate}' : ''}',
                    style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Organisé par ${itinerary.ownerName}', style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Budget estimé : ${totalPrice.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ')} FCFA'
            '${itinerary.budgetFcfa != null ? ' (budget prévu : ${itinerary.budgetFcfa} FCFA)' : ''}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          for (final day in days) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
              child: pw.Text('Jour $day', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell('Lieu', bold: true),
                    _cell('Quartier', bold: true),
                    _cell('Prix moy.', bold: true),
                    _cell('Notes', bold: true),
                  ],
                ),
                for (final entry in byDay[day]!)
                  pw.TableRow(children: [
                    _cell(entry.value.name),
                    _cell(entry.value.quartier),
                    _cell('${entry.value.avgPriceFcfa} FCFA'),
                    _cell(entry.key.notes ?? ''),
                  ]),
              ],
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Text(
            'Généré depuis GlobeTrotter Yaoundé',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    // Printing.sharePdf ouvre le partage natif (mobile) / téléchargement
    // (web) selon la plateforme - même bibliothèque que layoutPdf mais
    // sans passer par le dialogue d'impression, plus direct pour "exporter".
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${_slug(itinerary.title)}.pdf',
    );
  }

  static pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : null)),
      );

  static String _slug(String s) {
    final lower = s.toLowerCase().trim();
    final ascii = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return ascii.replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  }
}
