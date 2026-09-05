class User {
  final String id;
  final String fullName;
  final String email;
  final List<String> preferences;
  final String? avatar;

  User({required this.id, required this.fullName, required this.email, required this.preferences, this.avatar});

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        fullName: j['full_name'],
        email: j['email'],
        preferences: List<String>.from(j['preferences'] ?? []),
        avatar: j['avatar'] as String?,
      );
}
