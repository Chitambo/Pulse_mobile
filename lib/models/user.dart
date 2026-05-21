class Role {
  final int id;
  final String name;
  final String slug;

  Role({required this.id, required this.name, required this.slug});

  factory Role.fromJson(Map<String, dynamic> j) =>
      Role(id: j['id'], name: j['name'], slug: j['slug']);
}

class UserEmployee {
  final int id;
  final String firstName;
  final String lastName;
  final String? photo;

  UserEmployee({required this.id, required this.firstName, required this.lastName, this.photo});

  String get fullName => '$firstName $lastName';

  factory UserEmployee.fromJson(Map<String, dynamic> j) => UserEmployee(
        id: j['id'],
        firstName: j['firstName'],
        lastName: j['lastName'],
        photo: j['photo'],
      );
}

class AuthUser {
  final int id;
  final String username;
  final String email;
  final Role role;
  final UserEmployee? employee;
  final bool mustChangePassword;

  AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.employee,
    this.mustChangePassword = false,
  });

  bool get isAdmin => role.slug == 'ceo' || role.slug == 'admin';
  bool get isCeo => role.slug == 'ceo';
  bool get isSupport => role.slug == 'support_officer';
  bool get isDeveloper => role.slug == 'developer';
  bool get isAccounts => role.slug == 'accounts';

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'],
        username: j['username'],
        email: j['email'],
        role: Role.fromJson(j['role']),
        employee: j['employee'] != null ? UserEmployee.fromJson(j['employee']) : null,
        mustChangePassword: j['mustChangePassword'] ?? false,
      );
}
