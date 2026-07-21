class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.isTwoFactorEnabled = false,
    this.isBiometricEnabled = false,
  });

  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool isTwoFactorEnabled;
  final bool isBiometricEnabled;
}