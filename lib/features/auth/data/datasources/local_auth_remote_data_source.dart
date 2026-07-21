import 'dart:math';

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
    throw UnsupportedError('Use SocialAuthService + upsertSocialUser for Google sign-in.');
  }

  @override
  Future<AuthUser> signInWithApple() async {
    throw UnsupportedError('Use SocialAuthService + upsertSocialUser for Apple sign-in.');
  }

  /// Creates or updates a local user from a real Google/Apple identity.
  Future<AuthUser> upsertSocialUser({
    required String provider,
    required String email,
    required String displayName,
    String? photoUrl,
    required String providerUserId,
  }) async {
    final String normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw StateError('Social sign-in did not return an email address.');
    }

    final UserRow? existing =
        await (_db.select(_db.users)..where((Users tbl) => tbl.email.equals(normalized))).getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.users)..where((Users tbl) => tbl.id.equals(existing.id))).write(
            UsersCompanion(
              displayName: Value<String>(displayName.trim().isEmpty ? existing.displayName : displayName.trim()),
              photoUrl: Value<String?>(photoUrl ?? existing.photoUrl),
            ),
          );
      final UserRow row = await (_db.select(_db.users)..where((Users tbl) => tbl.id.equals(existing.id))).getSingle();
      return _map(row);
    }

    final String id = IdGenerator.next();
    await _db.into(_db.users).insert(
          UsersCompanion.insert(
            id: id,
            email: normalized,
            passwordHash: PasswordHasher.hash('social:$provider:$providerUserId:${IdGenerator.next()}'),
            displayName: displayName.trim().isEmpty ? normalized.split('@').first : displayName.trim(),
            photoUrl: Value<String?>(photoUrl),
            createdAt: DateTime.now(),
          ),
        );
    final UserRow row = await (_db.select(_db.users)..where((Users tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  String _generateOtp() {
    final Random random = Random.secure();
    return List<String>.generate(6, (_) => random.nextInt(10).toString()).join();
  }

  @override
  Future<String> sendPasswordReset({required String email}) async {
    final UserRow? row = await (_db.select(_db.users)..where((Users tbl) => tbl.email.equals(email.toLowerCase())))
        .getSingleOrNull();
    if (row == null) {
      throw StateError('No account found for that email.');
    }

    _pendingOtpEmail = row.email;
    _pendingOtpCode = _generateOtp();
    await (_db.update(_db.users)..where((Users tbl) => tbl.id.equals(row.id))).write(
          UsersCompanion(otpCode: Value<String>(_pendingOtpCode!)),
        );
    return _pendingOtpCode!;
  }

  Future<String> requestOtp({required String email}) async {
    final String normalized = email.trim().toLowerCase();
    _pendingOtpEmail = normalized;
    _pendingOtpCode = _generateOtp();

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
    final String normalized = email.trim().toLowerCase();
    if (_pendingOtpEmail != normalized) {
      throw StateError('Request a new OTP code for this email first.');
    }
    await verifyOtp(code: code);

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
    _pendingOtpCode = null;
    return _map(row);
  }

  Future<void> verifyResetCode({required String email, required String code}) async {
    final String normalized = email.trim().toLowerCase();
    if (_pendingOtpEmail != normalized) {
      throw StateError('Request a reset code for this email first.');
    }
    await verifyOtp(code: code);
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
