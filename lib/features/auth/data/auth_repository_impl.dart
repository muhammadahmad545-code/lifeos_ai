import 'dart:async';

import '../../../core/services/settings_service.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import '../services/biometric_service.dart';
import '../services/session_store.dart';
import '../services/social_auth_service.dart';
import 'datasources/local_auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required LocalAuthRemoteDataSource localAuth,
    required SessionStore sessionStore,
    required BiometricService biometricService,
    required SettingsService settingsService,
    required SocialAuthService socialAuthService,
  })  : _localAuth = localAuth,
        _sessionStore = sessionStore,
        _biometricService = biometricService,
        _settings = settingsService,
        _socialAuth = socialAuthService;

  final LocalAuthRemoteDataSource _localAuth;
  final SessionStore _sessionStore;
  final BiometricService _biometricService;
  final SettingsService _settings;
  final SocialAuthService _socialAuth;

  final StreamController<AuthUser?> _sessionController = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;
  bool _restored = false;

  @override
  Stream<AuthUser?> watchSession() {
    return Stream<AuthUser?>.multi((MultiStreamController<AuthUser?> controller) {
      controller.add(_currentUser);
      final StreamSubscription<AuthUser?> subscription = _sessionController.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> restoreSession() async {
    if (_restored) {
      return;
    }
    _restored = true;
    final AuthUser? stored = await _sessionStore.readUser();
    if (stored != null) {
      _currentUser = stored;
      await _settings.setCurrentUserId(stored.id);
      _sessionController.add(stored);
    } else {
      _sessionController.add(null);
    }
  }

  @override
  Future<AuthUser?> currentUser() async => _currentUser;

  @override
  Future<AuthUser> signInWithEmail({required String email, required String password}) async {
    final AuthUser user = await _localAuth.signInWithEmail(email: email, password: password);
    await _setCurrentUser(user);
    return user;
  }

  @override
  Future<AuthUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final AuthUser user = await _localAuth.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    await _setCurrentUser(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final SocialAuthProfile profile = await _socialAuth.signInWithGoogle();
    final AuthUser user = await _localAuth.upsertSocialUser(
      provider: profile.provider,
      email: profile.email,
      displayName: profile.displayName,
      photoUrl: profile.photoUrl,
      providerUserId: profile.providerUserId,
    );
    await _setCurrentUser(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithApple() async {
    final SocialAuthProfile profile = await _socialAuth.signInWithApple();
    final AuthUser user = await _localAuth.upsertSocialUser(
      provider: profile.provider,
      email: profile.email,
      displayName: profile.displayName,
      photoUrl: profile.photoUrl,
      providerUserId: profile.providerUserId,
    );
    await _setCurrentUser(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithOtp({required String email, required String code}) async {
    final AuthUser user = await _localAuth.signInWithOtp(email: email, code: code);
    await _setCurrentUser(user);
    return user;
  }

  @override
  Future<String> requestOtp({required String email}) {
    return _localAuth.requestOtp(email: email);
  }

  @override
  Future<String> sendPasswordReset({required String email}) async {
    return _localAuth.sendPasswordReset(email: email);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
    required String code,
  }) async {
    await _localAuth.verifyResetCode(email: email, code: code);
    await _localAuth.resetPassword(email: email, newPassword: newPassword);
  }

  @override
  Future<void> signOut() async {
    await _socialAuth.signOutGoogle();
    await _sessionStore.clear();
    await _settings.setCurrentUserId(null);
    _currentUser = null;
    _sessionController.add(null);
  }

  @override
  Future<void> verifyOtp({required String code}) async {
    await _localAuth.verifyOtp(code: code);
  }

  @override
  Future<AuthUser> enableTwoFactor({required bool enabled}) async {
    final AuthUser user = _requireUser();
    final AuthUser updated = await _localAuth.updateSecurityFlags(userId: user.id, twoFactor: enabled);
    await _settings.setTwoFactorEnabled(enabled);
    await _setCurrentUser(updated);
    return updated;
  }

  @override
  Future<AuthUser> enableBiometricLogin({required bool enabled}) async {
    final AuthUser user = _requireUser();
    if (enabled) {
      final bool canAuthenticate = await _biometricService.canAuthenticate();
      if (!canAuthenticate) {
        throw StateError('Biometric authentication is not available on this device.');
      }
      final bool authenticated = await _biometricService.authenticate();
      if (!authenticated) {
        throw StateError('Biometric authentication failed.');
      }
    }
    final AuthUser updated = await _localAuth.updateSecurityFlags(userId: user.id, biometric: enabled);
    await _settings.setBiometricEnabled(enabled);
    if (enabled) {
      await _sessionStore.saveBiometricUser(updated);
    } else {
      await _sessionStore.clearBiometricUser();
    }
    await _setCurrentUser(updated);
    return updated;
  }

  @override
  Future<AuthUser> unlockWithBiometrics() async {
    final AuthUser? biometricUser = await _sessionStore.readBiometricUser();
    if (biometricUser == null || !biometricUser.isBiometricEnabled) {
      throw StateError('Biometric login is not enabled. Sign in and turn it on in Security settings.');
    }

    final bool canAuthenticate = await _biometricService.canAuthenticate();
    if (!canAuthenticate) {
      throw StateError('Biometric authentication is not available on this device.');
    }

    final bool authenticated = await _biometricService.authenticate();
    if (!authenticated) {
      throw StateError('Biometric authentication failed.');
    }

    await _setCurrentUser(biometricUser);
    return biometricUser;
  }

  @override
  Future<AuthUser> updateProfile({required String displayName, String? photoUrl}) async {
    final AuthUser user = _requireUser();
    final AuthUser updated = await _localAuth.updateProfile(
      userId: user.id,
      displayName: displayName,
      photoUrl: photoUrl,
    );
    await _setCurrentUser(updated);
    return updated;
  }

  AuthUser _requireUser() {
    final AuthUser? user = _currentUser;
    if (user == null) {
      throw StateError('You must be signed in.');
    }
    return user;
  }

  Future<void> _setCurrentUser(AuthUser user) async {
    _currentUser = user;
    await _sessionStore.saveUser(user);
    await _settings.setCurrentUserId(user.id);
    _sessionController.add(user);
  }
}
