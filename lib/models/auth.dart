class AuthUser {
  const AuthUser({required this.email, required this.name, required this.token, this.role = ''});

  final String email;
  final String name;
  final String token;
  final String role;
}
