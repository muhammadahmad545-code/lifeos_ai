import '../domain/auth_user.dart';
import 'session_store.dart';

class InMemorySessionStore implements SessionStore {
  AuthUser? _user;
  AuthUser? _biometricUser;

  @override
  Future<void> clear() async {
    _user = null;
  }

  @override
  Future<void> clearBiometricUser() async {
    _biometricUser = null;
  }

  @override
  Future<AuthUser?> readUser() async => _user;

  @override
  Future<AuthUser?> readBiometricUser() async => _biometricUser;

  @override
  Future<void> saveUser(AuthUser? user) async {
    _user = user;
  }

  @override
  Future<void> saveBiometricUser(AuthUser? user) async {
    _biometricUser = user;
  }
}
