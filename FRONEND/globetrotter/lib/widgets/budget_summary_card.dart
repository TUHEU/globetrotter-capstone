import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/itinerary.dart';
import '../providers/destination_provider.dart';
import '../providers/settings_provider.dart';

/// Résumé budgétaire d'une sortie : coût estimé (somme des avg_price_fcfa
/// des destinations dans les arrêts) comparé au budget prévu par
/// l'utilisateur, avec un statut visuel 🟢/🟠/🔴.
///
/// C'est une ESTIMATION, pas un total exact - les prix du catalogue
/// (avg_price_fcfa) sont eux-mêmes des moyennes ; utile comme indication,
/// pas comme devis. N'affiche rien du tout si ni le budget ni le coût
/// estimé ne sont disponibles (ex: sortie sans arrêt encore, ou créée
/// avant l'ajout de ce champ).
class BudgetSummaryCard extends StatelessWidget {
  final Itinerary itinerary;
  const BudgetSummaryCard({super.key, required this.itinerary});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final s = settings.s;
    final destProvider = context.watch<DestinationProvider>();
    final theme = Theme.of(context);

    int? estimated;
    var anyMissing = false;
    for (final stop in itinerary.stops) {
      final dest = destProvider.byId(stop.destinationId);
      if (dest == null) {
        anyMissing = true;
        continue;
      }
      estimated = (estimated ?? 0) + dest.avgPriceFcfa;
    }

    if (itinerary.budgetFcfa == null && estimated == null) {
      return const SizedBox.shrink();
    }

    Color? statusColor;
    String? statusText;
    if (itinerary.budgetFcfa != null && itinerary.budgetFcfa! > 0 && estimated != null) {
      final ratio = estimated / itinerary.budgetFcfa!;
      if (ratio <= 0.9) {
        statusColor = Colors.green;
        statusText = s.budgetWithinBudget;
      } else if (ratio <= 1.05) {
        statusColor = Colors.orange;
        statusText = s.budgetNearBudget;
      } else {
        statusColor = Colors.red;
        statusText = s.budgetOverBudget;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.savings_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  s.budgetSummaryTitle,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (statusText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (estimated != null)
              Text(
                s.budgetEstimated(formatPrice(estimated, currency: settings.currency, isFr: s.isFr)),
                style: theme.textTheme.bodyMedium,
              ),
            if (anyMissing)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  s.budgetNoPriceData,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ),
            if (itinerary.budgetFcfa != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  s.budgetPlanned(formatPrice(itinerary.budgetFcfa!, currency: settings.currency, isFr: s.isFr)),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
