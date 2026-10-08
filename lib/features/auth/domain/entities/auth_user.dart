/// Domain-level user shape — deliberately not the same class as any JSON
/// model in `data/`, so a backend response shape change is a one-file fix
/// in the data layer, never a ripple into presentation.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roles,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final List<String> roles;

  bool get isAdmin => roles.contains('ADMIN');

  AuthUser copyWith({String? firstName, String? lastName}) {
    return AuthUser(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      roles: roles,
    );
  }
}
