class UserProfile {
  const UserProfile(
      {required this.id,
      required this.email,
      required this.name,
      required this.role});
  final String id;
  final String email;
  final String name;
  final String role;
  // Presentation capability only. The server authorizes each operation.
  bool get canManageUsers => role == 'admin';

  factory UserProfile.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        json['email'] is! String ||
        (json['email'] as String).isEmpty ||
        json['name'] is! String ||
        !['admin', 'user'].contains(json['role']) ||
        json['active'] != true) {
      throw const FormatException('Invalid user profile');
    }
    return UserProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        role: json['role'] as String);
  }
}
