class User {
  final String id;
  final String fullName;
  final String email;
  final List<String> preferences;

  User({required this.id, required this.fullName, required this.email, required this.preferences});

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        fullName: j['full_name'],
        email: j['email'],
        preferences: List<String>.from(j['preferences'] ?? []),
      );
}
