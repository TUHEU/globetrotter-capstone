import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/destination_provider.dart';
import '../services/location_service.dart';

/// Filtres avancés de recherche : fourchette de prix, distance (nécessite
/// la position GPS), et "ouvert maintenant" (heuristique côté client sur
/// le champ best_time - voir Destination.isLikelyOpenNow, aucune donnée
/// d'horaires réelle n'existe dans le catalogue).
///
/// "Ouvert maintenant" filtre uniquement l'affichage local (pas un
/// paramètre backend) puisque c'est calculé à partir de l'heure actuelle
/// du téléphone, pas d'une donnée que le serveur connaît.
Future<void> showSearchFiltersSheet(BuildContext context) async {
  final provider = context.read<DestinationProvider>();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SearchFiltersSheet(),
  );
}

class _SearchFiltersSheet extends StatefulWidget {
  const _SearchFiltersSheet();

  @override
  State<_SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<_SearchFiltersSheet> {
  late RangeValues _priceRange;
  double? _distanceKm;
  bool _openNow = false;
  bool _locating = false;
  bool _locationAvailable = false;

  static const double _maxPrice = 50000;

  @override
  void initState() {
    super.initState();
    final p = context.read<DestinationProvider>();
    _priceRange = RangeValues(
      (p.minPrice ?? 0).toDouble(),
      (p.maxPrice ?? _maxPrice).toDouble(),
    );
    _distanceKm = p.maxDistanceKm;
  }

  Future<void> _enableDistanceFilter() async {
    setState(() => _locating = true);
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos != null) {
        context.read<DestinationProvider>().setUserLocation(pos.latitude, pos.longitude);
        _locationAvailable = true;
        _distanceKm = 5;
      } else {
        _locationAvailable = false;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Position indisponible - vérifiez que la localisation est activée."),
        ));
      }
    });
  }

  void _apply() {
    final provider = context.read<DestinationProvider>();
    provider.search(
      minPrice: _priceRange.start.round(),
      maxPrice: _priceRange.end.round(),
      maxDistanceKm: _locationAvailable ? _distanceKm : null,
      resetDistanceFilter: !_locationAvailable,
    );
    Navigator.of(context).pop();
  }

  void _reset() {
    final provider = context.read<DestinationProvider>();
    setState(() {
      _priceRange = const RangeValues(0, _maxPrice);
      _distanceKm = null;
      _locationAvailable = false;
      _openNow = false;
    });
    provider.search(resetPriceFilter: true, resetDistanceFilter: true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Filtres', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),

          Text('Prix (FCFA)', style: Theme.of(context).textTheme.titleSmall),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: _maxPrice,
            divisions: 50,
            labels: RangeLabels(
              _priceRange.start.round().toString(),
              _priceRange.end >= _maxPrice ? '${_maxPrice.round()}+' : _priceRange.end.round().toString(),
            ),
            onChanged: (v) => setState(() => _priceRange = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_priceRange.start.round()} FCFA'),
              Text(_priceRange.end >= _maxPrice
                  ? '${_maxPrice.round()}+ FCFA'
                  : '${_priceRange.end.round()} FCFA'),
            ],
          ),
          const SizedBox(height: 12),

          Text('Distance', style: Theme.of(context).textTheme.titleSmall),
          if (!_locationAvailable)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _enableDistanceFilter,
                icon: _locating
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location, size: 18),
                label: Text(_locating ? 'Localisation...' : 'Filtrer par distance depuis moi'),
              ),
            )
          else ...[
            Slider(
              value: _distanceKm ?? 5,
              min: 0.5,
              max: 20,
              divisions: 39,
              label: LocationService.formatKm(_distanceKm ?? 5),
              onChanged: (v) => setState(() => _distanceKm = v),
            ),
            Text('Dans un rayon de ${LocationService.formatKm(_distanceKm ?? 5)}'),
          ],
          const SizedBox(height: 8),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ouvert maintenant'),
            subtitle: const Text(
              'Estimation à partir des horaires indiqués - pas une garantie',
              style: TextStyle(fontSize: 11.5),
            ),
            value: _openNow,
            onChanged: (v) => setState(() => _openNow = v),
          ),
          if (_openNow)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                "Ce filtre s'applique directement sur la liste affichée.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  child: const Text('Réinitialiser'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (_openNow) {
                      context.read<DestinationProvider>().clientOpenNowFilter = true;
                    } else {
                      context.read<DestinationProvider>().clientOpenNowFilter = false;
                    }
                    _apply();
                  },
                  child: const Text('Appliquer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
