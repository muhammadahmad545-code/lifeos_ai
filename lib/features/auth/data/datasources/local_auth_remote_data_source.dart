import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/password_hasher.dart';
import '../../domain/auth_user.dart';
import 'auth_remote_data_source.dart';

class LocalAuthRemoteDataSource implements AuthRemoteDataSource {
  LocalAuthRemoteDataSource(this._db);

  final AppDatabase _db;
  String? _pendingOtpEmail;
  String? _pendingOtpCode;

  @override
  Future<AuthUser> signInWithEmail({required String email, required String password}) async {
    final UserRow? row = await (_db.select(_db.users)..where((Users tbl) => tbl.email.equals(email.toLowerCase())))
        .getSingleOrNull();

    if (row == null || !PasswordHasher.verify(password, row.passwordHash)) {
      throw StateError('Invalid email or password.');
    }

    return _map(row);
  }

  Future<AuthUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final String normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || password.length < 6) {
      throw StateError('Enter a valid email and a password with at least 6 characters.');
    }

    final UserRow? existing = await (_db.select(_db.users)..where((Users tbl) => tbl.email.equals(normalized)))
        .getSingleOrNull();
    if (existing != null) {
      throw StateError('An account with this email already exists.');
    }

    final String id = IdGenerator.next();
    await _db.into(_db.users).insert(
          UsersCompanion.insert(
            id: id,
            email: normalized,
            passwordHash: PasswordHasher.hash(password),
            displayName: displayName.trim().isEmpty ? normalized.split('@').first : displayName.trim(),
            createdAt: DateTime.now(),
          ),
        );

    final UserRow row = await (_db.select(_db.users)..where((Users tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    return _socialSignIn(provider: 'google');
  }

  @override
  Future<AuthUser> signInWithApple() async {
    return _socialSignIn(provider: 'apple');
  }

  Future<AuthUser> _socialSignIn({required String provider}) async {
    final String email = '$provider.user@lifeos.local';
    final UserRow? existing = await (_db.select(_db.users)..where((Users tbl) => tbl.email.equals(email))).getSingleOrNull();
    if (existing != null) {
      return _map(existing);
    }

    final String id = IdGenerator.next();
    await _db.into(_db.users).insert(
          UsersCompanion.insert(
            id: id,
            email: email,
            passwordHash: PasswordHasher.hash(IdGenerator.next()),
            displayName: provider == 'google' ? 'Google User' : 'Apple User',
            createdAt: DateTime.now(),
          ),
        );
    final UserRow row = await (_db.select(_db.users)..where((Users tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    final UserRow? row = await (_db.select(_db.users)..where((Users tbl) => tbl.email.equals(email.toLowerCase())))
        .getSingleOrNull();
    if (row == null) {
      throw StateError('No account found for that email.');
    }

    _pendingOtpEmail = row.email;
    _pendingOtpCode = '123456';
    await (_db.update(_db.users)..where((Users tbl) => tbl.id.equals(row.id))).write(
          UsersCompanion(otpCode: Value<String>(_pendingOtpCode!)),
        );
  }

  Future<String> requestOtp({required String email}) async {
    final String normalized = email.trim().toLowerCase();
    _pendingOtpEmail = normalized;
    _pendingOtpCode = '123456';

    final UserRow? row = await (_db.select(_db.users)..where((Users tbl) => tbl.email.equals(normalized))).getSingleOrNull();
    if (row != null) {
      await (_db.update(_db.users)..where((Users tbl) => tbl.id.equals(row.id))).write(
            UsersCompanion(otpCode: Value<String>(_pendingOtpCode!)),
          );
    }
    return _pendingOtpCode!;
  }

  @override
  Future<void> verifyOtp({required String code}) async {
    if (_pendingOtpEmail == null || code.trim() != (_pendingOtpCode ?? '123456')) {
      throw StateError('Invalid OTP code.');
    }
  }

  Future<AuthUser> signInWithOtp({required String email, required String code}) async {
    await requestOtp(email: email);
    await verifyOtp(code: code);

    final String normalized = email.trim().toLowerCase();
    UserRow? row = await (_db.select(_db.users)..where((Users tbl) => tbl.email.equals(normalized))).getSingleOrNull();
    if (row == null) {
      final String id = IdGenerator.next();
      await _db.into(_db.users).insert(
            UsersCompanion.insert(
              id: id,
              email: normalized,
              passwordHash: PasswordHasher.hash(IdGenerator.next()),
              displayName: normalized.split('@').first,
              createdAt: DateTime.now(),
            ),
          );
      row = await (_db.select(_db.users)..where((Users tbl) => tbl.id.equals(id))).getSingle();
    }
    return _map(row);
  }

  @override
  Future<void> enableTwoFactor() async {}

  @override
  Future<void> enableBiometricLogin() async {}

  Future<AuthUser> updateProfile({
    required String userId,
    required String displayName,
    String? photoUrl,
  }) async {
    await (_db.update(_db.users)..where((Users tbl) => tbl.id.equals(userId))).write(
          UsersCompanion(
            displayName: Value<String>(displayName),
            photoUrl: Value<String?>(photoUrl),
          ),
        );
    final UserRow row = await (_db.select(_db.users)..where((Users tbl) => tbl.id.equals(userId))).getSingle();
    return _map(row);
  }

  Future<AuthUser> updateSecurityFlags({
    required String userId,
    bool? twoFactor,
    bool? biometric,
  }) async {
    await (_db.update(_db.users)..where((Users tbl) => tbl.id.equals(userId))).write(
          UsersCompanion(
            isTwoFactorEnabled: twoFactor == null ? const Value.absent() : Value<bool>(twoFactor),
            isBiometricEnabled: biometric == null ? const Value.absent() : Value<bool>(biometric),
          ),
        );
    final UserRow row = await (_db.select(_db.users)..where((Users tbl) => tbl.id.equals(userId))).getSingle();
    return _map(row);
  }

  Future<void> resetPassword({required String email, required String newPassword}) async {
    final UserRow? row = await (_db.select(_db.users)..where((Users tbl) => tbl.email.equals(email.toLowerCase())))
        .getSingleOrNull();
    if (row == null) {
      throw StateError('No account found for that email.');
    }
    await (_db.update(_db.users)..where((Users tbl) => tbl.id.equals(row.id))).write(
          UsersCompanion(passwordHash: Value<String>(PasswordHasher.hash(newPassword))),
        );
  }

  AuthUser _map(UserRow row) {
    return AuthUser(
      id: row.id,
      email: row.email,
      displayName: row.displayName,
      photoUrl: row.photoUrl,
      isTwoFactorEnabled: row.isTwoFactorEnabled,
      isBiometricEnabled: row.isBiometricEnabled,
    );
  }
}
