import 'auth_user.dart';

abstract class AuthRepository {
  Stream<AuthUser?> watchSession();

  Future<void> restoreSession();

  Future<AuthUser> signInWithEmail({required String email, required String password});

  Future<AuthUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthUser> signInWithGoogle();

  Future<AuthUser> signInWithApple();

  Future<AuthUser> signInWithOtp({required String email, required String code});

  Future<String> requestOtp({required String email});

  Future<String> sendPasswordReset({required String email});

  Future<void> resetPassword({
    required String email,
    required String newPassword,
    required String code,
  });

  Future<void> signOut();

  Future<void> verifyOtp({required String code});

  Future<AuthUser> enableTwoFactor({required bool enabled});

  Future<AuthUser> enableBiometricLogin({required bool enabled});

  Future<AuthUser> unlockWithBiometrics();

  Future<AuthUser> updateProfile({required String displayName, String? photoUrl});

  Future<AuthUser?> currentUser();
}
