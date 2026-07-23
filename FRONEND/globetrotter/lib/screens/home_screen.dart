import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/destination_provider.dart';
import '../providers/itinerary_provider.dart';
import '../widgets/destination_card.dart';
import 'create_itinerary_screen.dart';
import 'destination_detail_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<DestinationProvider>().search(q: '');
      context.read<DestinationProvider>().loadRecommendations();
      context.read<ItineraryProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [
      _ExploreTab(),
      _RecommendationsTab(),
      _TripsTab(),
      _ProfileTab(),
    ];
    final wide = MediaQuery.of(context).size.width >= 760;

    return Scaffold(
      body: Row(children: [
        if (wide)
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.explore_outlined), label: Text('Explore')),
              NavigationRailDestination(
                  icon: Icon(Icons.auto_awesome_outlined), label: Text('For you')),
              NavigationRailDestination(
                  icon: Icon(Icons.map_outlined), label: Text('My trips')),
              NavigationRailDestination(
                  icon: Icon(Icons.person_outline), label: Text('Profile')),
            ],
          ),
        Expanded(child: pages[_index]),
      ]),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.explore_outlined), label: 'Explore'),
                NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined), label: 'For you'),
                NavigationDestination(
                    icon: Icon(Icons.map_outlined), label: 'My trips'),
                NavigationDestination(
                    icon: Icon(Icons.person_outline), label: 'Profile'),
              ],
            ),
      floatingActionButton: _index == 2
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('New trip'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CreateItineraryScreen())),
            )
          : null,
    );
  }
}

// ---------------- Explore ----------------
class _ExploreTab extends StatefulWidget {
  const _ExploreTab();

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> {
  final _search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DestinationProvider>();
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SearchBar(
            controller: _search,
            hintText: 'Rechercher un lieu, un quartier...',
            leading: const Icon(Icons.search),
            onSubmitted: (q) => p.search(q: q),
            trailing: [
              if (_search.text.isNotEmpty)
                IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _search.clear();
                      p.search(q: '');
                    }),
            ],
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: PlaceCategories.all.entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(e.value, size: 16),
                        label: Text(PlaceCategories.labels[e.key] ?? e.key),
                        selected: p.activeCategory == e.key,
                        onSelected: (sel) => p.search(
                            q: _search.text, category: sel ? e.key : null),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: p.loading
              ? const Center(child: CircularProgressIndicator())
              : p.error != null
                  ? _ErrorView(message: p.error!, onRetry: () => p.search(q: ''))
                  : p.destinations.isEmpty
                      ? const Center(child: Text('No destinations found.'))
                      : RefreshIndicator(
                          onRefresh: () => p.search(),
                          child: ListView.builder(
                            itemCount: p.destinations.length,
                            itemBuilder: (_, i) => DestinationCard(
                              destination: p.destinations[i],
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => DestinationDetailScreen(
                                          destination: p.destinations[i]))),
                            ),
                          ),
                        ),
        ),
      ]),
    );
  }
}

// ------------- Recommendations -------------
class _RecommendationsTab extends StatelessWidget {
  const _RecommendationsTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DestinationProvider>();
    final user = context.watch<AuthProvider>().user;
    return SafeArea(
      child: p.loadingRecos
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => p.loadRecommendations(),
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Text('Made for you, ${user?.fullName.split(' ').first ?? ''} ✈️',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                        'Selon vos centres d\'intérêt, vos sorties passées et les lieux préférés des Yaoundéens.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const SizedBox(height: 8),
                  if (p.recommendations.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No recommendations yet.'))),
                  ...p.recommendations.map((d) => DestinationCard(
                        destination: d,
                        showReasons: true,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                DestinationDetailScreen(destination: d))),
                      )),
                ],
              ),
            ),
    );
  }
}

// ---------------- Trips ----------------
class _TripsTab extends StatelessWidget {
  const _TripsTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ItineraryProvider>();
    final destProvider = context.watch<DestinationProvider>();
    return SafeArea(
      child: p.loading
          ? const Center(child: CircularProgressIndicator())
          : p.itineraries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                        'Aucune sortie planifiée.\nAppuyez sur "New trip" pour organiser votre première visite de Yaoundé !',
                        textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => p.load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: p.itineraries.length,
                    itemBuilder: (_, i) {
                      final it = p.itineraries[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ExpansionTile(
                          leading: const Icon(Icons.map_outlined),
                          title: Text(it.title,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text([
                            if (it.startDate != null)
                              '${it.startDate} → ${it.endDate ?? "?"}',
                            '${it.stops.length} stop(s)',
                            if (it.sharedWith.isNotEmpty)
                              'shared with ${it.sharedWith.length}',
                          ].join(' · ')),
                          children: [
                            if (it.description != null)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(it.description!)),
                              ),
                            ...it.stops.map((s) {
                              final d = destProvider.byId(s.destinationId);
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                    radius: 13, child: Text('${s.day}')),
                                title: Text(d?.name ?? s.destinationId),
                                subtitle:
                                    s.notes != null ? Text(s.notes!) : null,
                              );
                            }),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                                onPressed: () async {
                                  final err = await p.delete(it.id);
                                  if (err != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(err)));
                                  }
                                },
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

// ---------------- Profile ----------------
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 44,
            child: Text(
              user?.fullName.isNotEmpty == true
                  ? user!.fullName[0].toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(height: 12),
          Text(user?.fullName ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(user?.email ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          Text('Travel interests', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (user?.preferences ?? [])
                .map((t) => Chip(label: Text(t)))
                .toList(),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off, size: 48),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(message, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    );
  }
}
