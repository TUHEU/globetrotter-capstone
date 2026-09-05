import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/app_strings.dart';
import '../core/avatars.dart';
import '../core/constants.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/destination_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/messages_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/settings_provider.dart';
import '../services/deep_link_service.dart';
import '../services/share_service.dart';
import '../widgets/achievement_badges.dart';
import '../widgets/draggable_assistant_button.dart';
import '../widgets/travel_stats_card.dart';
import '../widgets/destination_card.dart';
import '../widgets/like_comment_bar.dart';
import 'create_itinerary_screen.dart';
import 'assistant_screen.dart';
import 'destination_detail_screen.dart';
import 'explore_map_screen.dart';
import 'submit_place_screen.dart';
import 'favorites_screen.dart';
import 'friends_feed_screen.dart';
import 'friends_screen.dart';
import 'inbox_screen.dart';
import 'notifications_screen.dart';
import 'itinerary_map_screen.dart';
import 'login_screen.dart';
import 'reviews_screen.dart';
import 'settings_screen.dart';
import 'chat_hub_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const _kSidebarWidth = 220.0;
const _kSidebarCollapsedWidth = 72.0;
const _kWideBreak = 760.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _hideBubble = false;
  bool _hideMobileNav = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<DestinationProvider>().search(q: '');
      context.read<DestinationProvider>().loadRecommendations();
      context.read<ItineraryProvider>().load();
      context.read<FavoritesProvider>().load();
      context.read<FriendsProvider>().loadFollowLists();
      context.read<MessagesProvider>().loadInbox();
      context.read<NotificationsProvider>().load();
      _handleDeepLink();
    });
  }


  Future<void> _refreshSocial() async {
    if (!mounted) return;
    await Future.wait([
      context.read<FriendsProvider>().loadFollowLists(),
      context.read<NotificationsProvider>().load(),
      context.read<MessagesProvider>().loadInbox(),
    ]);
  }

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
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= _kWideBreak;

    final pages = [
      const _ExploreTab(),
      const _RecommendationsTab(),
      const _TripsTab(),
      const ChatHubScreen(),
      const _ProfileTab(),
    ];

    // Nav items
    final navItems = [
      _NavItem(icon: Icons.explore_outlined, activeIcon: Icons.explore, label: s.navExplore),
      _NavItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome, label: s.navForYou),
      _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: s.navTrips),
      _NavItem(icon: Icons.forum_outlined, activeIcon: Icons.forum_rounded,
          label: s.isFr ? 'Chat' : 'Chat'),
      _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: s.navProfile),
    ];

    return Scaffold(
      drawer: isWide ? null : Drawer(
        width: 330,
        child: _TripIoDrawer(
          items: navItems,
          selectedIndex: _index,
          onSelect: (i) {
            Navigator.of(context).pop();
            setState(() => _index = i);
          },
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NotificationListener<UserScrollNotification>(
        onNotification: (n) {
          if (n.direction == ScrollDirection.reverse) {
            if (!_hideBubble || (!isWide && !_hideMobileNav)) {
              setState(() {
                _hideBubble = true;
                if (!isWide) _hideMobileNav = true;
              });
            }
          } else if (n.direction == ScrollDirection.forward) {
            if (_hideBubble || (!isWide && _hideMobileNav)) {
              setState(() {
                _hideBubble = false;
                if (!isWide) _hideMobileNav = false;
              });
            }
          }
          return false;
        },
        child: Stack(children: [
          Row(children: [
            // ── Wide sidebar ──────────────────────────────────────────────
            if (isWide)
              _DesktopSidebar(
                items: navItems,
                selectedIndex: _index,
                onTap: (i) => setState(() => _index = i),
              ),
            // ── Main content ──────────────────────────────────────────────
            Expanded(child: pages[_index]),
          ]),

          // ── Floating AI bubble (draggable, like the language button) ───
          DraggableAssistantButton(
            hidden: _hideBubble,
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AssistantScreen())),
          ),
        ]),
      ),
      // Mobile bottom nav
      bottomNavigationBar: isWide
          ? null
          : AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: _hideMobileNav ? 0 : 80,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: 0,
                  maxHeight: 80,
                  child: NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() {
                      _index = i;
                      _hideMobileNav = false;
                      _hideBubble = false;
                    }),
                    destinations: navItems
                        .map((e) => NavigationDestination(
                            icon: Icon(e.icon),
                            selectedIcon: Icon(e.activeIcon),
                            label: e.label))
                        .toList(),
                  ),
                ),
              ),
            ),
      // FABs
      floatingActionButton: isWide
          ? null
          : _index == 0
              ? FloatingActionButton.extended(
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: Text(s.submitPlaceTitle),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const SubmitPlaceScreen())),
                )
              : _index == 2
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 64),
                      child: FloatingActionButton.extended(
                        icon: const Icon(Icons.add),
                        label: Text(s.newTrip),
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CreateItineraryScreen())),
                      ),
                    )
                  : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop sidebar  (trip_io-style: icon + label, full width)
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

class _DesktopSidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _DesktopSidebar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C1E13) : Colors.white;
    final selectedBg = isDark
        ? const Color(0xFF1B7A3D).withValues(alpha: 0.18)
        : const Color(0xFF1B7A3D).withValues(alpha: 0.08);
    final selectedColor = const Color(0xFF1B7A3D);
    final unselectedColor = isDark ? Colors.white54 : Colors.black45;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.07);

    return Container(
      width: _kSidebarWidth,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo / app name
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selectedColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.explore, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GlobeTrotter',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isDark ? Colors.white : const Color(0xFF0C1E13))),
                    Text('Yaoundé',
                        style: TextStyle(
                            fontSize: 11,
                            color: selectedColor,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ]),
          ),

          const SizedBox(height: 4),

          // Nav items
          ...List.generate(items.length, (i) {
            final item = items[i];
            final selected = selectedIndex == i;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Material(
                color: selected ? selectedBg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    child: Row(children: [
                      Icon(
                        selected ? item.activeIcon : item.icon,
                        size: 20,
                        color: selected ? selectedColor : unselectedColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? selectedColor : unselectedColor,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          }),

          const Spacer(),

          // Bottom: Global Chat button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Material(
              color: const Color(0xFF1B7A3D).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatHubScreen())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(children: [
                    Icon(Icons.forum_rounded, size: 20, color: selectedColor),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Chat Global 🌍',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: selectedColor))),
                  ]),
                ),
              ),
            ),
          ),
          // Submit place button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            child: Builder(builder: (ctx) {
              final s = context.watch<SettingsProvider>().s;
              return Material(
                color: const Color(0xFF1B7A3D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const SubmitPlaceScreen())),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    child: Row(children: [
                      Icon(Icons.add_location_alt_outlined,
                          size: 20, color: selectedColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.submitPlaceTitle,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selectedColor)),
                      ),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Explore Tab
// ─────────────────────────────────────────────────────────────────────────────
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
    final user = context.watch<AuthProvider>().user;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= _kWideBreak;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Column(children: [
        _TripIoHeader(title: s.navExplore),
        // ── Hero banner (desktop only) ─────────────────────────────────
        if (isWide) _HeroBanner(user: user, s: s, isDark: isDark),

        // ── Search bar ────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, isWide ? 16 : 14, isWide ? 24 : 16, 4),
          child: Row(children: [
            Expanded(
              child: SearchBar(
                controller: _search,
                hintText: s.searchHint,
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
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
            const SizedBox(width: 8),
            // Map button
            _ToolButton(
              icon: Icons.map_outlined,
              tooltip: s.exploreMapTitle,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ExploreMapScreen())),
            ),
            const SizedBox(width: 6),
            // Filter button
            _ToolButton(
              icon: Icons.tune,
              tooltip: s.priceFilter,
              active: p.minPrice != null || p.maxPrice != null,
              onTap: () => _showPriceFilterSheet(context, p, s),
            ),
          ]),
        ),

        // ── Category chips ────────────────────────────────────────────
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
                horizontal: isWide ? 24 : 16, vertical: 6),
            children: [
              // "All" chip
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s.isFr ? 'Tout' : 'All'),
                  selected: p.activeCategory == null,
                  onSelected: (_) => p.search(q: _search.text, category: null),
                ),
              ),
              ...PlaceCategories.all.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(e.value, size: 15),
                      label: Text(PlaceCategories.labels[e.key] ?? e.key),
                      selected: p.activeCategory == e.key,
                      onSelected: (sel) =>
                          p.search(q: _search.text, category: sel ? e.key : null),
                    ),
                  )),
            ],
          ),
        ),

        // ── Result count bar (desktop) ────────────────────────────────
        if (isWide && !p.loading && !p.hasError && p.destinations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Row(children: [
              Text(
                s.isFr
                    ? '${p.destinations.length} lieux trouvés'
                    : '${p.destinations.length} places found',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              const Spacer(),
            ]),
          ),

        // ── Destination grid / list ───────────────────────────────────
        Expanded(
          child: p.loading
              ? const Center(child: CircularProgressIndicator())
              : p.hasError
                  ? _ErrorView(message: p.errorMessage(s)!, onRetry: () => p.search(q: ''))
                  : p.destinations.isEmpty
                      ? Center(child: Text(s.noResults))
                      : RefreshIndicator(
                          onRefresh: () => p.search(),
                          child: LayoutBuilder(builder: (ctx, constraints) {
                            // Responsive columns matching trip_io
                            final cols = constraints.maxWidth >= 1100
                                ? 4
                                : constraints.maxWidth >= 800
                                    ? 3
                                    : constraints.maxWidth >= 560
                                        ? 2
                                        : 1;

                            if (cols == 1) {
                              return ListView.builder(
                                padding: const EdgeInsets.only(bottom: 96),
                                itemCount: p.destinations.length,
                                itemBuilder: (_, i) => DestinationCard(
                                  destination: p.destinations[i],
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) =>
                                          DestinationDetailScreen(destination: p.destinations[i]))),
                                ),
                              );
                            }

                            return GridView.builder(
                              padding: EdgeInsets.fromLTRB(
                                  isWide ? 24 : 12, 8, isWide ? 24 : 12, 96),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 0.68,
                              ),
                              itemCount: p.destinations.length,
                              itemBuilder: (_, i) => _DesktopDestCard(
                                destination: p.destinations[i],
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) =>
                                        DestinationDetailScreen(destination: p.destinations[i]))),
                              ),
                            );
                          }),
                        ),
        ),
      ]),
    );
  }

  void _showPriceFilterSheet(BuildContext context, DestinationProvider p, AppStrings s) {
    final minCtrl = TextEditingController(text: p.minPrice?.toString() ?? '');
    final maxCtrl = TextEditingController(text: p.maxPrice?.toString() ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.priceFilter,
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(children: [
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
            ]),
            const SizedBox(height: 20),
            Row(children: [
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
            ]),
          ],
        ),
      ),
    ).whenComplete(() {
      minCtrl.dispose();
      maxCtrl.dispose();
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero banner (desktop explore header)
// ─────────────────────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final dynamic user;
  final AppStrings s;
  final bool isDark;

  const _HeroBanner({required this.user, required this.s, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final firstName = (user?.fullName ?? '').split(' ').first;
    final destCount = context.watch<DestinationProvider>().destinations.length;
    final tripCount = context.watch<ItineraryProvider>().itineraries.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      height: 160,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF143D21), const Color(0xFF0B2316)]
              : [const Color(0xFF1B7A3D), const Color(0xFF0F5229)],
        ),
      ),
      child: Stack(children: [
        // Decorative dots pattern
        Positioned(
          right: -30,
          top: -30,
          child: Opacity(
            opacity: 0.08,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          right: 80,
          bottom: -60,
          child: Opacity(
            opacity: 0.06,
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
        // World map dots icon top-right
        Positioned(
          right: 28,
          top: 0,
          bottom: 0,
          child: Opacity(
            opacity: 0.15,
            child: Icon(Icons.language, size: 120, color: Colors.white),
          ),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 180, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Eyebrow
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s.isFr ? 'ASSISTANT DE VOYAGE · CAMEROUN 🇨🇲' : 'TRAVEL ASSISTANT · CAMEROON 🇨🇲',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700,
                      letterSpacing: 0.8),
                ),
              ),
              const SizedBox(height: 10),
              // Greeting
              Text(
                firstName.isNotEmpty
                    ? (s.isFr ? 'Bonjour, $firstName 👋' : 'Hello, $firstName 👋')
                    : (s.isFr ? 'Bonjour, Explorateur 👋' : 'Hello, Explorer 👋'),
                style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                s.dashSubtitle,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
              ),
              const SizedBox(height: 14),
              // Mini stats row
              Row(children: [
                _MiniStat(value: '$destCount', label: s.statPlaces),
                const SizedBox(width: 20),
                _MiniStat(value: '${PlaceCategories.all.length}', label: s.statCategories),
                const SizedBox(width: 20),
                _MiniStat(value: '$tripCount', label: s.statTrips),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small square tool button (map / filter)
// ─────────────────────────────────────────────────────────────────────────────
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : (isDark ? const Color(0xFF122A1B) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon,
                size: 22,
                color: active ? theme.colorScheme.primary : theme.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop destination card  (trip_io style — image top, info bottom)
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopDestCard extends StatelessWidget {
  final dynamic destination;
  final VoidCallback? onTap;

  const _DesktopDestCard({required this.destination, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final favorites = context.watch<FavoritesProvider>();
    final isFav = favorites.isFavorite(destination.id);
    final catIcon =
        PlaceCategories.all[destination.category] ?? Icons.place_outlined;
    final s = context.watch<SettingsProvider>();

    return Material(
      color: isDark ? const Color(0xFF122A1B) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ─────────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Stack(fit: StackFit.expand, children: [
                // Image
                _DestImage(destination: destination, catIcon: catIcon),

                // Gradient overlay at bottom
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Price badge — bottom left on image
                Positioned(
                  bottom: 8, left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      formatPrice(destination.avgPriceFcfa,
                          currency: s.currency, isFr: s.s.isFr),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                // Fav button — top right
                Positioned(
                  top: 8, right: 8,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => favorites.toggle(destination.id),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isFav ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Share button — top right -1
                Positioned(
                  top: 8, right: 44,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => ShareService.shareText(
                        s.s.shareDestinationText(destination.name,
                            destination.quartier,
                            ApiConstants.destinationLink(destination.id)),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child:
                            Icon(Icons.share_outlined, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ]),
            ),

            // ── Info ──────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      destination.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 3),
                    // Location
                    Row(children: [
                      Icon(Icons.place_outlined,
                          size: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          destination.quartier,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    // Description
                    Expanded(
                      child: Text(
                        destination.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Category chip + best time
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(children: [
                          Icon(catIcon,
                              size: 11, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            PlaceCategories.labels[destination.category] ??
                                destination.category,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary),
                          ),
                        ]),
                      ),
                      const Spacer(),
                      Icon(Icons.schedule_outlined,
                          size: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 3),
                      Text(
                        destination.bestTime,
                        style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Small helper for destination image with fallback
class _DestImage extends StatelessWidget {
  final dynamic destination;
  final IconData catIcon;
  const _DestImage({required this.destination, required this.catIcon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = ApiConstants.resolveImageUrl(destination.image);
    if (url.isEmpty) {
      return Container(
        color: theme.colorScheme.primaryContainer,
        child: Center(child: Icon(catIcon, size: 40, color: theme.colorScheme.primary)),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: theme.colorScheme.primaryContainer,
        child: Center(child: Icon(catIcon, size: 40, color: theme.colorScheme.primary)),
      ),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          color: theme.colorScheme.primaryContainer,
          child: Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recommendations Tab
// ─────────────────────────────────────────────────────────────────────────────
class _RecommendationsTab extends StatelessWidget {
  const _RecommendationsTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DestinationProvider>();
    final user = context.watch<AuthProvider>().user;
    final s = context.watch<SettingsProvider>().s;
    final isWide = MediaQuery.of(context).size.width >= _kWideBreak;
    return SafeArea(
      child: p.loadingRecos
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => p.loadRecommendations(),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _TripIoHeader(title: s.navForYou)),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(isWide ? 24 : 20, 20, isWide ? 24 : 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.madeFor(user?.fullName.split(' ').first ?? ''),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(s.recoSubtitle,
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                  ),
                  if (p.recommendations.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                          child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(s.noRecos))),
                    )
                  else if (isWide)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.68,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _DesktopDestCard(
                            destination: p.recommendations[i],
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => DestinationDetailScreen(
                                    destination: p.recommendations[i]))),
                          ),
                          childCount: p.recommendations.length,
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => DestinationCard(
                          destination: p.recommendations[i],
                          showReasons: true,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  DestinationDetailScreen(destination: p.recommendations[i]))),
                        ),
                        childCount: p.recommendations.length,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trips Tab
// ─────────────────────────────────────────────────────────────────────────────
class _TripsTab extends StatelessWidget {
  const _TripsTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ItineraryProvider>();
    final destProvider = context.watch<DestinationProvider>();
    final s = context.watch<SettingsProvider>().s;
    final unread = context.watch<MessagesProvider>().totalUnread;
    final isWide = MediaQuery.of(context).size.width >= _kWideBreak;

    return SafeArea(
      child: Column(children: [
        _TripIoHeader(title: s.navTrips),
        Padding(
          padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 10, 8, 4),
          child: Row(children: [
            const Expanded(child: SizedBox()),
            if (isWide)
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(s.newTrip),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateItineraryScreen())),
              ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: s.friendsFeed,
              icon: const Icon(Icons.dynamic_feed_outlined),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const FriendsFeedScreen())),
            ),
            Consumer<NotificationsProvider>(
              builder: (context, np, _) => Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: s.isFr ? 'Notifications' : 'Notifications',
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                  ),
                  if (np.unreadCount > 0)
                    Positioned(
                      right: 6, top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          shape: BoxShape.circle),
                        child: Text(np.unreadCount > 9 ? '9+' : '${np.unreadCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 9),
                          textAlign: TextAlign.center),
                      ),
                    ),
                ],
              ),
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
                    right: 6, top: 6,
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
          ]),
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
                        padding: EdgeInsets.fromLTRB(
                            isWide ? 24 : 0, 8, isWide ? 24 : 0, 96),
                        itemCount: p.itineraries.length,
                        itemBuilder: (_, i) {
                          final it = p.itineraries[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
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
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                    child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(it.description!)),
                                  ),
                                ...it.stops.map((stop) {
                                  final d = destProvider.byId(stop.destinationId);
                                  return ListTile(
                                    dense: true,
                                    leading:
                                        CircleAvatar(radius: 13, child: Text('${stop.day}')),
                                    title: Text(d?.name ?? stop.destinationId),
                                    subtitle: stop.notes != null ? Text(stop.notes!) : null,
                                  );
                                }),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      tooltip: it.isPublic ? s.makePrivate : s.makePublic,
                                      icon: Icon(it.isPublic
                                          ? Icons.public
                                          : Icons.public_off_outlined),
                                      onPressed: () async {
                                        final err =
                                            await p.setVisibility(it.id, !it.isPublic);
                                        if (err != null && context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                  content:
                                                      Text(s.visibilityUpdateFailed)));
                                        }
                                      },
                                    ),
                                    IconButton(
                                      tooltip: s.share,
                                      icon: const Icon(Icons.share_outlined),
                                      onPressed: () => ShareService.shareText(
                                          s.shareItineraryText(it.title, it.stops.length,
                                              ApiConstants.itineraryLink(it.id))),
                                    ),
                                    if (it.stops.isNotEmpty)
                                      TextButton.icon(
                                        icon: const Icon(Icons.map_outlined),
                                        label: const Text('Voir sur la carte'),
                                        onPressed: () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    ItineraryMapScreen(itinerary: it))),
                                      ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete_outline),
                                      label: Text(s.delete),
                                      onPressed: () async {
                                        final err = await p.delete(it.id);
                                        if (err != null && context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                              content: Text(
                                                  ApiClient.errorMessage(err, s))));
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
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Tab
// ─────────────────────────────────────────────────────────────────────────────
void _openAvatarPicker(BuildContext context, User? user) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _AvatarPickerSheet(currentAvatar: user?.avatar),
  );
}

class _AvatarPickerSheet extends StatefulWidget {
  final String? currentAvatar;
  const _AvatarPickerSheet({required this.currentAvatar});

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  bool _saving = false;

  Future<void> _pick(String key) async {
    setState(() => _saving = true);
    final ok = await context.read<AuthProvider>().updateAvatar(key);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.read<SettingsProvider>().s.isFr
              ? 'Échec de la mise à jour de l\'avatar'
              : 'Failed to update avatar')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.isFr ? 'Choisir un avatar' : 'Choose an avatar',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              s.isFr
                  ? 'Visible par tout le monde (chat, profil, amis).'
                  : 'Visible to everyone (chat, profile, friends).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: kAvatarOptions.map((a) {
                final selected = a.key == widget.currentAvatar;
                return GestureDetector(
                  onTap: _saving ? null : () => _pick(a.key),
                  child: Container(
                    width: 76,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                      color: selected
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(a.emoji, style: const TextStyle(fontSize: 30)),
                        const SizedBox(height: 4),
                        Text(s.isFr ? a.labelFr : a.labelEn,
                            style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_saving) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final s = context.watch<SettingsProvider>().s;
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= _kWideBreak;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 96),
        children: [
          _TripIoHeader(title: s.navProfile),
          Padding(
            padding: EdgeInsets.fromLTRB(isWide ? 48 : 20, 20, isWide ? 48 : 20, 0),
            child: GestureDetector(
              onTap: () => _openAvatarPicker(context, user),
              child: Stack(
                children: [
                  UserAvatar(
                    name: user?.fullName ?? '',
                    avatar: user?.avatar,
                    color: theme.colorScheme.primary,
                    radius: 44,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                      ),
                      child: const Icon(Icons.edit, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user?.fullName ?? '—',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          Text(
            user?.email ?? '',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Stats row
          Card(
            margin: EdgeInsets.symmetric(horizontal: isWide ? 48 : 20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(children: [
            _ProfileStat(
              icon: Icons.map_outlined,
              value: '${context.watch<ItineraryProvider>().itineraries.length}',
              label: s.statTrips,
            ),
            _ProfileStat(
              icon: Icons.favorite_outline,
              value: '${context.watch<FavoritesProvider>().count}',
              label: s.isFr ? 'Favoris' : 'Favorites',
            ),
            _ProfileStat(
              icon: Icons.people_outline,
              value: '${context.watch<FriendsProvider>().followers.length}',
              label: s.isFr ? 'Abonnés' : 'Followers',
            ),
            _ProfileStat(
              icon: Icons.person_add_alt_1_outlined,
              value: '${context.watch<FriendsProvider>().following.length}',
              label: s.isFr ? 'Suivis' : 'Following',
            ),
              ],),
            ),
          ),
          const SizedBox(height: 24),
          // Preferences
          if (user?.preferences.isNotEmpty == true) ...[
            Text(s.isFr ? 'Vos intérêts' : 'Your interests',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: user!.preferences
                  .map((p) => Chip(label: Text(p), visualDensity: VisualDensity.compact))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],
          // Achievement badges
          const AchievementBadges(),
          const SizedBox(height: 12),
          const TravelStatsCard(),
          const SizedBox(height: 16),
          // Menu items
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.forum_rounded),
                title: Text(s.isFr ? 'Chat Global 🌍' : 'Global Chat 🌍'),
                subtitle: Text(s.isFr ? 'Discuter avec toute la communauté' : 'Chat with the whole community'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const ChatHubScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(s.isFr ? 'Paramètres' : 'Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text(s.isFr ? 'Amis' : 'Friends'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const FriendsScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.favorite_outline),
                title: Text(s.isFr ? 'Favoris' : 'Favorites'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const FavoritesScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: Text(s.isFr ? 'Assistant IA' : 'AI Assistant'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const AssistantScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: Text(s.isFr ? 'Noter l\'application' : 'Rate the app'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const ReviewsScreen())),
              ),
            ]),
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

// ─────────────────────────────────────────────────────────────────────────────
// trip_io-inspired mobile shell (layout only): green header + notification badge + drawer
// ─────────────────────────────────────────────────────────────────────────────
class _TripIoHeader extends StatelessWidget {
  final String title;
  const _TripIoHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final np = context.watch<NotificationsProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Vert de la marque (voir AppTheme._green), pas le turquoise/bleu de la
    // maquette "trip_io" - ce dégradé reprenait par erreur les couleurs
    // d'une référence de design distincte au lieu du thème réel de l'app.
    return Container(
      height: 76,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            isDark ? const Color(0xFF0F5229) : const Color(0xFF2FA35C),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          Builder(builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 30),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          )),
          Expanded(
            child: Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w700)),
          ),
          Stack(children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 30),
              tooltip: 'Notifications',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
            if (np.unreadCount > 0)
              Positioned(
                right: 7, top: 6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
                  child: Text(np.unreadCount > 9 ? '9+' : '${np.unreadCount}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
          const SizedBox(width: 6),
        ]),
      ),
    );
  }
}

class _TripIoDrawer extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _TripIoDrawer({required this.items, required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: theme.brightness == Brightness.dark
              ? [const Color(0xFF202B34), const Color(0xFF111820)]
              : [const Color(0xFFF5F7F8), const Color(0xFFD8DEE2)],
        ),
      ),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 20, 20),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.public_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('GlobeTrotter', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
          ),
          Divider(color: Colors.black.withValues(alpha: .12), height: 1),
          Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 10), children: [
            for (int i = 0; i < items.length; i++)
              _DrawerEntry(item: items[i], selected: i == selectedIndex, onTap: () => onSelect(i)),
            _DrawerEntry(
              item: const _NavItem(icon: Icons.add_location_alt_outlined, activeIcon: Icons.add_location_alt, label: 'Suggest a destination'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubmitPlaceScreen()));
              },
            ),
            _DrawerEntry(
              item: const _NavItem(icon: Icons.favorite_border_rounded, activeIcon: Icons.favorite_rounded, label: 'Favorites'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavoritesScreen()));
              },
            ),
            _DrawerEntry(
              item: const _NavItem(icon: Icons.notifications_none_rounded, activeIcon: Icons.notifications_rounded, label: 'Notifications'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
            ),
            _DrawerEntry(
              item: const _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map_rounded, label: 'Map'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreMapScreen()));
              },
            ),
          ])),
        ]),
      ),
    );
  }
}

class _DrawerEntry extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _DrawerEntry({required this.item, required this.onTap, this.selected = false});
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final color = selected ? primary : Theme.of(context).textTheme.bodyLarge?.color;
    return ListTile(
      dense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 2),
      leading: Icon(selected ? item.activeIcon : item.icon, size: 29, color: color),
      title: Text(item.label, style: TextStyle(fontSize: 17, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: color)),
      selected: selected,
      selectedTileColor: primary.withValues(alpha: .10),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared utility widgets
// ─────────────────────────────────────────────────────────────────────────────
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
      child: Column(children: [
        Icon(icon, color: theme.colorScheme.secondary),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: theme.textTheme.labelSmall),
      ]),
    );
  }
}
