import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/itinerary.dart';
import '../providers/destination_provider.dart';
import '../providers/settings_provider.dart';
import 'itinerary_map_screen.dart';

class FriendsFeedScreen extends StatefulWidget {
  const FriendsFeedScreen({super.key});

  @override
  State<FriendsFeedScreen> createState() => _FriendsFeedScreenState();
}

class _FriendsFeedScreenState extends State<FriendsFeedScreen> {
  List<Itinerary> _items = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.dio.get('/itineraries/feed');
      _items = (res.data['results'] as List).map((j) => Itinerary.fromJson(j)).toList();
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    final destProvider = context.watch<DestinationProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(s.friendsFeed)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 100),
                      Center(child: Text(ApiClient.errorMessage(_error!, s))),
                      const SizedBox(height: 12),
                      Center(child: OutlinedButton(onPressed: _load, child: Text(s.retry))),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 100),
                          const Icon(Icons.dynamic_feed_outlined, size: 56, color: Colors.grey),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(s.friendsFeedEmpty,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey)),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final it = _items[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                child: Text(
                                  it.ownerName.isNotEmpty ? it.ownerName[0].toUpperCase() : '?',
                                ),
                              ),
                              title: Text(it.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${it.ownerName} · ${s.stops(it.stops.length)}'),
                              children: [
                                if (it.description != null)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(it.description!),
                                    ),
                                  ),
                                ...it.stops.map((stop) {
                                  final d = destProvider.byId(stop.destinationId);
                                  return ListTile(
                                    dense: true,
                                    leading:
                                        CircleAvatar(radius: 13, child: Text('${stop.day}')),
                                    title: Text(d?.name ?? stop.destinationId),
                                  );
                                }),
                                if (it.stops.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8, right: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          icon: const Icon(Icons.map_outlined),
                                          label: const Text('Voir sur la carte'),
                                          onPressed: () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      ItineraryMapScreen(itinerary: it))),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
