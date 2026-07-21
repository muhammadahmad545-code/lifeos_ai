import '../domain/auth_user.dart';

abstract class SessionStore {
  Future<void> saveUser(AuthUser? user);

  Future<AuthUser?> readUser();

  Future<void> saveBiometricUser(AuthUser? user);

  Future<AuthUser?> readBiometricUser();

  Future<void> clear();

  Future<void> clearBiometricUser();
}
