/// Minimal public profile - what /users/search, /follow/following and
/// /follow/followers return. Never contains anything private (no password,
/// no preferences) since these come from OTHER people's accounts.
class Friend {
  final String id;
  final String fullName;
  final String email;

  Friend({required this.id, required this.fullName, required this.email});

  factory Friend.fromJson(Map<String, dynamic> j) => Friend(
        id: j['id'],
        fullName: j['full_name'] ?? '',
        email: j['email'] ?? '',
      );
}
