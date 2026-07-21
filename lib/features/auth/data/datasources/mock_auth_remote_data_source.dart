import '../../domain/auth_user.dart';
import 'auth_remote_data_source.dart';

class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  @override
  Future<AuthUser> signInWithApple() async {
    return const AuthUser(id: 'apple_user', email: 'user@icloud.com', displayName: 'Apple User');
  }

  @override
  Future<AuthUser> signInWithEmail({required String email, required String password}) async {
    return AuthUser(id: 'user_01', email: email, displayName: 'LifeOS User');
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    return const AuthUser(id: 'google_user', email: 'user@gmail.com', displayName: 'Google User');
  }

  @override
  Future<void> enableBiometricLogin() async {}

  @override
  Future<void> enableTwoFactor() async {}

  @override
  Future<void> sendPasswordReset({required String email}) async {}

  @override
  Future<void> verifyOtp({required String code}) async {}
}