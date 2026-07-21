import '../../domain/auth_user.dart';

class AuthUserModel extends AuthUser {
  const AuthUserModel({
    required super.id,
    required super.email,
    required super.displayName,
    super.photoUrl,
    super.isTwoFactorEnabled,
    super.isBiometricEnabled,
  });

  factory AuthUserModel.fromUser(AuthUser user) {
    return AuthUserModel(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
      isTwoFactorEnabled: user.isTwoFactorEnabled,
      isBiometricEnabled: user.isBiometricEnabled,
    );
  }
}