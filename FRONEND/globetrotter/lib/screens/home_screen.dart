import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/destination_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/destination_card.dart';
import 'create_itinerary_screen.dart';
import 'assistant_screen.dart';
import 'destination_detail_screen.dart';
import 'itinerary_map_screen.dart';
import 'login_screen.dart';
import 'reviews_screen.dart';
import 'settings_screen.dart';

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
    final s = context.watch<SettingsProvider>().s;
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
            destinations: [
              NavigationRailDestination(
                  icon: const Icon(Icons.explore_outlined), label: Text(s.navExplore)),
              NavigationRailDestination(
                  icon: const Icon(Icons.auto_awesome_outlined), label: Text(s.navForYou)),
              NavigationRailDestination(
                  icon: const Icon(Icons.map_outlined), label: Text(s.navTrips)),
              NavigationRailDestination(
                  icon: const Icon(Icons.person_outline), label: Text(s.navProfile)),
            ],
          ),
        Expanded(child: pages[_index]),
      ]),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                NavigationDestination(
                    icon: const Icon(Icons.explore_outlined), label: s.navExplore),
                NavigationDestination(
                    icon: const Icon(Icons.auto_awesome_outlined), label: s.navForYou),
                NavigationDestination(
                    icon: const Icon(Icons.map_outlined), label: s.navTrips),
                NavigationDestination(
                    icon: const Icon(Icons.person_outline), label: s.navProfile),
              ],
            ),
      floatingActionButton: _index == 2
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(s.newTrip),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CreateItineraryScreen())),
            )
          : null,
    );
  }
}

// ---------------- Dashboard header (Explore tab) ----------------
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final s = context.watch<SettingsProvider>().s;
    final user = context.watch<AuthProvider>().user;
    final destCount = context.watch<DestinationProvider>().destinations.length;
    final tripCount = context.watch<ItineraryProvider>().itineraries.length;
    final firstName = (user?.fullName ?? '').split(' ').first;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF15351F), const Color(0xFF0F2418)]
              : [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.85)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.greeting(firstName.isEmpty ? '' : firstName),
                      style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      s.dashSubtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                child: Text(
                  user?.fullName.isNotEmpty == true
                      ? user!.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _StatPill(icon: Icons.place_outlined, value: '$destCount', label: s.statPlaces),
              const SizedBox(width: 10),
              _StatPill(
                  icon: Icons.category_outlined,
                  value: '${PlaceCategories.all.length}',
                  label: s.statCategories),
              const SizedBox(width: 10),
              _StatPill(icon: Icons.map_outlined, value: '$tripCount', label: s.statTrips),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatPill({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            Text(label,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 10.5)),
          ],
        ),
      ),
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
    final s = context.watch<SettingsProvider>().s;
    return SafeArea(
      child: Column(children: [
        const _DashboardHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: SearchBar(
            controller: _search,
            hintText: s.searchHint,
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
              : p.hasError
                  ? _ErrorView(message: p.errorMessage(s)!, onRetry: () => p.search(q: ''))
                  : p.destinations.isEmpty
                      ? Center(child: Text(s.noResults))
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
    final s = context.watch<SettingsProvider>().s;
    return SafeArea(
      child: p.loadingRecos
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => p.loadRecommendations(),
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Text(s.madeFor(user?.fullName.split(' ').first ?? ''),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(s.recoSubtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const SizedBox(height: 8),
                  if (p.recommendations.isEmpty)
                    Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(child: Text(s.noRecos))),
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
    final s = context.watch<SettingsProvider>().s;
    return SafeArea(
      child: p.loading
          ? const Center(child: CircularProgressIndicator())
          : p.itineraries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(s.tripsEmpty, textAlign: TextAlign.center),
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
                            s.stops(it.stops.length),
                            if (it.sharedWith.isNotEmpty)
                              s.sharedWith(it.sharedWith.length),
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
                            ...it.stops.map((stop) {
                              final d = destProvider.byId(stop.destinationId);
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                    radius: 13, child: Text('${stop.day}')),
                                title: Text(d?.name ?? stop.destinationId),
                                subtitle:
                                    stop.notes != null ? Text(stop.notes!) : null,
                              );
                            }),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (it.stops.isNotEmpty)
                                  TextButton.icon(
                                    icon: const Icon(Icons.map_outlined),
                                    label: const Text('Voir sur la carte'),
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => ItineraryMapScreen(itinerary: it))),
                                  ),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_outline),
                                  label: Text(s.delete),
                                  onPressed: () async {
                                    final err = await p.delete(it.id);
                                    if (err != null && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(ApiClient.errorMessage(err, s))));
                                    }
                                  },
                                ),
                              ],
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
    final s = context.watch<SettingsProvider>().s;
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              user?.fullName.isNotEmpty == true
                  ? user!.fullName[0].toUpperCase()
                  : '?',
              style: TextStyle(fontSize: 32, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(user?.fullName ?? '',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text(user?.email ?? '',
              textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          Text(s.interests, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (user?.preferences ?? [])
                .map((t) => Chip(label: Text(t)))
                .toList(),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(s.settings),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Assistant IA'),
              subtitle: const Text('Discutez et obtenez des suggestions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const AssistantScreen())),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('Noter l\'application'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ReviewsScreen())),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: Text(s.logout),
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
    final s = context.watch<SettingsProvider>().s;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off, size: 48),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(message, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: Text(s.retry)),
      ]),
    );
  }
}
