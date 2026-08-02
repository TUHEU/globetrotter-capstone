import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/destination.dart';
import '../providers/destination_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/destination_card.dart';
import 'destination_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Destination> _destinations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final favIds = context.read<FavoritesProvider>().ids;
    final destProvider = context.read<DestinationProvider>();
    final resolved = <Destination>[];
    for (final id in favIds) {
      final d = await destProvider.fetchById(id);
      if (d != null) resolved.add(d);
    }
    if (!mounted) return;
    setState(() {
      _destinations = resolved;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Se recharge automatiquement si l'utilisateur retire un favori depuis
    // cet écran (le coeur sur la carte reste actif ici aussi).
    context.watch<FavoritesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Favoris')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _destinations.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Icon(Icons.favorite_border, size: 56, color: Colors.grey),
                      SizedBox(height: 16),
                      Center(
                        child: Text('Aucun favori pour le moment',
                            style: TextStyle(fontSize: 16)),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Appuyez sur le coeur d\'une destination pour\nl\'ajouter ici.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: _destinations.length,
                    itemBuilder: (context, i) {
                      final d = _destinations[i];
                      return DestinationCard(
                        destination: d,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => DestinationDetailScreen(destination: d))),
                      );
                    },
                  ),
      ),
    );
  }
}
