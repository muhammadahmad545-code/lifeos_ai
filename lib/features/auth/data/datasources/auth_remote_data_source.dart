import '../../domain/auth_user.dart';

abstract class AuthRemoteDataSource {
  Future<AuthUser> signInWithEmail({required String email, required String password});

  Future<AuthUser> signInWithGoogle();

  Future<AuthUser> signInWithApple();

  Future<String> sendPasswordReset({required String email});

  Future<void> verifyOtp({required String code});

  Future<void> enableTwoFactor();

  Future<void> enableBiometricLogin();
}