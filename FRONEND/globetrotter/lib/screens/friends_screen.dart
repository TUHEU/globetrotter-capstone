import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/friend.dart';
import '../providers/friends_provider.dart';
import '../providers/settings_provider.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      if (!mounted) return;
      context.read<FriendsProvider>().loadFollowLists();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    // Petit délai (300ms) pour éviter un appel réseau à chaque frappe.
    _debounce = Timer(const Duration(milliseconds: 300), () {
      context.read<FriendsProvider>().search(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>().s;
    final friendsProvider = context.watch<FriendsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.friends),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '${s.following} (${friendsProvider.following.length})'),
            Tab(text: '${s.followers} (${friendsProvider.followers.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: s.searchFriendsHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: friendsProvider.searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
            ),
          ),
          if (friendsProvider.searchResults.isNotEmpty || _searchController.text.isNotEmpty)
            Expanded(
              child: friendsProvider.searchResults.isEmpty && !friendsProvider.searching
                  ? Center(child: Text(s.noSearchResults))
                  : ListView.builder(
                      itemCount: friendsProvider.searchResults.length,
                      itemBuilder: (_, i) {
                        final user = friendsProvider.searchResults[i];
                        return _UserTile(
                          user: user,
                          isFollowing: friendsProvider.isFollowing(user.id),
                          onFollow: () => friendsProvider.follow(user),
                          onUnfollow: () => friendsProvider.unfollow(user.id),
                          s: s,
                        );
                      },
                    ),
            )
          else
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _FollowList(
                    users: friendsProvider.following,
                    emptyText: s.notFollowingAnyone,
                    loading: friendsProvider.loadingLists,
                    isFollowingTab: true,
                    friendsProvider: friendsProvider,
                    s: s,
                  ),
                  _FollowList(
                    users: friendsProvider.followers,
                    emptyText: s.noFollowersYet,
                    loading: friendsProvider.loadingLists,
                    isFollowingTab: false,
                    friendsProvider: friendsProvider,
                    s: s,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FollowList extends StatelessWidget {
  final List<Friend> users;
  final String emptyText;
  final bool loading;
  final bool isFollowingTab;
  final FriendsProvider friendsProvider;
  final dynamic s;

  const _FollowList({
    required this.users,
    required this.emptyText,
    required this.loading,
    required this.isFollowingTab,
    required this.friendsProvider,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(emptyText, textAlign: TextAlign.center),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => friendsProvider.loadFollowLists(),
      child: ListView.builder(
        itemCount: users.length,
        itemBuilder: (_, i) {
          final user = users[i];
          return _UserTile(
            user: user,
            // Dans l'onglet "Abonnés", on peut toujours suivre en retour même
            // si on ne le fait pas déjà - isFollowing() reste la seule source
            // de vérité, pas la liste affichée (following != followers).
            isFollowing: friendsProvider.isFollowing(user.id),
            onFollow: () => friendsProvider.follow(user),
            onUnfollow: () => friendsProvider.unfollow(user.id),
            s: s,
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Friend user;
  final bool isFollowing;
  final VoidCallback onFollow;
  final VoidCallback onUnfollow;
  final dynamic s;

  const _UserTile({
    required this.user,
    required this.isFollowing,
    required this.onFollow,
    required this.onUnfollow,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        child: Text(
          user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(user.fullName),
      subtitle: Text(user.email),
      trailing: isFollowing
          ? OutlinedButton(onPressed: onUnfollow, child: Text(s.unfollow))
          : FilledButton(onPressed: onFollow, child: Text(s.follow)),
    );
  }
}
