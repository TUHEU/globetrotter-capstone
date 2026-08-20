import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/app_strings.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/destination_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/messages_provider.dart';
import '../providers/settings_provider.dart';
import '../services/deep_link_service.dart';
import '../services/share_service.dart';
import '../widgets/achievement_badges.dart';
import '../widgets/travel_stats_card.dart';
import '../widgets/destination_card.dart';
import '../widgets/like_comment_bar.dart';
import 'create_itinerary_screen.dart';
import 'assistant_screen.dart';
import 'destination_detail_screen.dart';
import 'favorites_screen.dart';
import 'friends_feed_screen.dart';
import 'friends_screen.dart';
import 'inbox_screen.dart';
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
  // Cache la bulle IA pendant un défilement vers le bas (elle flotte
  // au-dessus du contenu et le cachait en fin de liste) - remonte via
  // NotificationListener<UserScrollNotification>, qui capte le scroll de
  // N'IMPORTE QUEL ListView descendant (Explore, Trips, Profil...) sans
  // que chaque onglet ait besoin de son propre ScrollController branché
  // manuellement au parent.
  bool _hideBubble = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<DestinationProvider>().search(q: '');
      context.read<DestinationProvider>().loadRecommendations();
      context.read<ItineraryProvider>().load();
      context.read<FavoritesProvider>().load();
      context.read<MessagesProvider>().loadInbox();
      _handleDeepLink();
    });
  }

  /// Si l'app a été ouverte via un lien partagé (voir DeepLinkService),
  /// va chercher la destination/sortie visée et l'ouvre directement -
  /// après un court délai pour laisser le premier écran finir de
  /// s'afficher (sinon Navigator.push trop tôt peut être ignoré pendant
  /// la toute première frame).
  Future<void> _handleDeepLink() async {
    final link = DeepLinkService.consumePending();
    if (link == null || !mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (link.type == 'destination') {
      final dest = await context.read<DestinationProvider>().fetchById(link.id);
      if (dest != null && mounted) {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DestinationDetailScreen(destination: dest)));
      }
    } else if (link.type == 'itinerary') {
      final it = await context.read<ItineraryProvider>().fetchById(link.id);
      if (it != null && mounted) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => ItineraryMapScreen(itinerary: it)));
      }
    }
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
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.reverse && !_hideBubble) {
            setState(() => _hideBubble = true);
          } else if (notification.direction == ScrollDirection.forward && _hideBubble) {
            setState(() => _hideBubble = false);
          }
          // false = laisse la notification continuer à remonter (au cas où
          // un ancêtre plus haut voudrait aussi la lire un jour).
          return false;
        },
        child: Stack(
          children: [
            Row(children: [
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
            // Bulle IA flottante, visible sur TOUS les onglets (pas seulement
            // dans le profil) — accès direct à l'assistant en un tap, où que
            // l'utilisateur se trouve dans l'app. Disparaît pendant un
            // défilement actif vers le bas (voir _hideBubble ci-dessus) pour
            // ne jamais rester plaquée sur du contenu qu'on essaie de lire.
            Positioned(
              right: 16,
              bottom: 16,
              child: IgnorePointer(
                ignoring: _hideBubble,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  offset: _hideBubble ? const Offset(0, 0.4) : Offset.zero,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _hideBubble ? 0 : 1,
                    child: _AssistantBubble(
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const AssistantScreen())),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
          ? Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: Text(s.newTrip),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const CreateItineraryScreen())),
              ),
            )
          : null,
    );
  }
}

/// Bulle IA flottante (façon "chat widget") — icône ronde toujours visible,
/// ouvre l'écran de l'assistant en un tap.
class _AssistantBubble extends StatelessWidget {
  final VoidCallback onTap;
  const _AssistantBubble({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondary,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(Icons.smart_toy_outlined, color: scheme.onSecondary, size: 26),
        ),
      ),
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
  // Rétrécit/masque le bandeau d'accueil ("Bonjour, ..." + statistiques)
  // pendant un défilement actif vers le bas dans la liste des lieux, pour
  // libérer de la place à l'écran - séparé de _hideBubble dans HomeScreen
  // (qui masque la bulle IA flottante) : deux préoccupations différentes,
  // donc deux `NotificationListener` distincts plutôt qu'un état partagé
  // entre widgets qui n'ont pas de raison de se connaître.
  bool _hideHeader = false;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DestinationProvider>();
    final s = context.watch<SettingsProvider>().s;
    return SafeArea(
      child: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.reverse && !_hideHeader) {
            setState(() => _hideHeader = true);
          } else if (notification.direction == ScrollDirection.forward && _hideHeader) {
            setState(() => _hideHeader = false);
          }
          return false;
        },
        child: Column(children: [
          // AnimatedSize (pas juste AnimatedOpacity) : l'espace qu'occupait
          // le bandeau doit vraiment se libérer pour la liste en dessous,
          // pas juste devenir invisible en gardant sa hauteur réservée.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _hideHeader ? 0 : 1,
              child: _hideHeader ? const SizedBox(width: double.infinity) : const _DashboardHeader(),
            ),
          ),
          Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: SearchBar(
            controller: _search,
            hintText: s.searchHint,
            leading: const Icon(Icons.search),
            onSubmitted: (q) => p.search(q: q),
            trailing: [
              IconButton(
                icon: Icon(
                  Icons.tune,
                  color: (p.minPrice != null || p.maxPrice != null) ? Theme.of(context).colorScheme.primary : null,
                ),
                tooltip: s.priceFilter,
                onPressed: () => _showPriceFilterSheet(context, p, s),
              ),
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
                            // 96 = assez pour dégager la bulle IA flottante
                            // (bottom:16 + ~56 de diamètre + marge) qui vit
                            // au-dessus de ce contenu dans le Stack parent -
                            // sans ça, la dernière carte reste coincée
                            // derrière elle en fin de liste.
                            padding: const EdgeInsets.only(bottom: 96),
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
      ),
    );
  }

  void _showPriceFilterSheet(BuildContext context, DestinationProvider p, AppStrings s) {
    final minCtrl = TextEditingController(text: p.minPrice?.toString() ?? '');
    final maxCtrl = TextEditingController(text: p.maxPrice?.toString() ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        // viewInsets.bottom pousse la feuille au-dessus du clavier - sans
        // ça, les champs de saisie se retrouvent cachés derrière lui.
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.priceFilter, style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: s.priceMin, suffixText: 'FCFA'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: maxCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: s.priceMax, suffixText: 'FCFA'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    p.search(q: _search.text, resetPriceFilter: true);
                  },
                  child: Text(s.clearFilter),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    p.search(
                      q: _search.text,
                      minPrice: minCtrl.text.isEmpty ? null : int.tryParse(minCtrl.text),
                      maxPrice: maxCtrl.text.isEmpty ? null : int.tryParse(maxCtrl.text),
                    );
                  },
                  child: Text(s.applyFilter),
                ),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      minCtrl.dispose();
      maxCtrl.dispose();
    });
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
                padding: const EdgeInsets.only(bottom: 96),
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
    final unread = context.watch<MessagesProvider>().totalUnread;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(s.navTrips,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip: s.friendsFeed,
                  icon: const Icon(Icons.dynamic_feed_outlined),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FriendsFeedScreen())),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: s.messages,
                      icon: const Icon(Icons.mail_outline),
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const InboxScreen())),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(color: Colors.white, fontSize: 9),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  tooltip: s.friends,
                  icon: const Icon(Icons.people_outline),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const FriendsScreen())),
                ),
              ],
            ),
          ),
          Expanded(
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
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
                    itemCount: p.itineraries.length,
                    itemBuilder: (_, i) {
                      final it = p.itineraries[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ExpansionTile(
                          leading: const Icon(Icons.map_outlined),
                          title: Row(children: [
                            Expanded(
                              child: Text(it.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            if (it.isPublic)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Chip(
                                  label: Text(s.publicTripBadge),
                                  avatar: const Icon(Icons.public, size: 14),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                          ]),
                          subtitle: Text([
                            if (it.startDate != null)
                              '${it.startDate} → ${it.endDate ?? "?"}',
                            s.stops(it.stops.length),
                            if (it.sharedWith.isNotEmpty)
                              s.sharedWith(it.sharedWith.length),
                          ].join(' · ')),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: LikeCommentBar(
                                itinerary: it,
                                onChanged: (updated) => p.updateLocal(updated),
                              ),
                            ),
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
                                IconButton(
                                  tooltip: it.isPublic ? s.makePrivate : s.makePublic,
                                  icon: Icon(it.isPublic ? Icons.public : Icons.public_off_outlined),
                                  onPressed: () async {
                                    final err = await p.setVisibility(it.id, !it.isPublic);
                                    if (err != null && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(s.visibilityUpdateFailed)));
                                    }
                                  },
                                ),
                                IconButton(
                                  tooltip: s.share,
                                  icon: const Icon(Icons.share_outlined),
                                  onPressed: () => ShareService.shareText(s.shareItineraryText(
                                      it.title, it.stops.length,
                                      ApiConstants.itineraryLink(it.id))),
                                ),
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
          ),
        ],
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
        // Fusion de l'ancien padding (20 partout) avec la marge basse ajoutée
        // pour dégager la bulle IA flottante (voir les autres onglets).
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
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
          const SizedBox(height: 20),
          Row(
            children: [
              _ProfileStat(
                icon: Icons.map_outlined,
                value: '${context.watch<ItineraryProvider>().itineraries.length}',
                label: 'Itinéraires',
              ),
              _ProfileStat(
                icon: Icons.place_outlined,
                value: 'Yaoundé',
                label: 'Région',
              ),
              _ProfileStat(
                icon: Icons.favorite_outline,
                value: '${context.watch<FavoritesProvider>().count}',
                label: 'Favoris',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const TravelStatsCard(),
          const SizedBox(height: 20),
          const AchievementBadges(),
          const SizedBox(height: 20),
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
              leading: const Icon(Icons.people_outline),
              title: Text(s.friends),
              subtitle: Text(s.friendsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const FriendsScreen())),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite_outline),
              title: const Text('Favoris'),
              subtitle: const Text('Destinations sauvegardées'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const FavoritesScreen())),
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
                context.read<FavoritesProvider>().clear();
                context.read<FriendsProvider>().clear();
                context.read<MessagesProvider>().clear();
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

class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _ProfileStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.secondary),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
