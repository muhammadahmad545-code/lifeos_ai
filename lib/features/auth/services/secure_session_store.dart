import 'dart:convert';

import '../../../core/services/secure_storage_service.dart';
import '../domain/auth_user.dart';
import 'session_store.dart';

class SecureSessionStore implements SessionStore {
  SecureSessionStore({SecureStorageService? secureStorage})
      : _secureStorage = secureStorage ?? SecureStorageService();

  static const String _sessionKey = 'lifeos_ai_session';
  static const String _biometricKey = 'lifeos_ai_biometric_user';
  final SecureStorageService _secureStorage;

  @override
  Future<void> clear() async {
    await _secureStorage.delete(key: _sessionKey);
  }

  @override
  Future<void> clearBiometricUser() async {
    await _secureStorage.delete(key: _biometricKey);
  }

  @override
  Future<AuthUser?> readUser() => _read(_sessionKey);

  @override
  Future<AuthUser?> readBiometricUser() => _read(_biometricKey);

  @override
  Future<void> saveUser(AuthUser? user) => _write(_sessionKey, user);

  @override
  Future<void> saveBiometricUser(AuthUser? user) => _write(_biometricKey, user);

  Future<AuthUser?> _read(String key) async {
    final String? encoded = await _secureStorage.read(key: key);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    final Map<String, dynamic> json = jsonDecode(encoded) as Map<String, dynamic>;
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      isTwoFactorEnabled: json['isTwoFactorEnabled'] as bool? ?? false,
      isBiometricEnabled: json['isBiometricEnabled'] as bool? ?? false,
    );
  }

  Future<void> _write(String key, AuthUser? user) async {
    if (user == null) {
      await _secureStorage.delete(key: key);
      return;
    }

    await _secureStorage.write(
      key: key,
      value: jsonEncode(<String, dynamic>{
        'id': user.id,
        'email': user.email,
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
        'isTwoFactorEnabled': user.isTwoFactorEnabled,
        'isBiometricEnabled': user.isBiometricEnabled,
      }),
    );
  }
}
