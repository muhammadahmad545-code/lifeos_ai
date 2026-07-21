import '../../domain/auth_user.dart';
import 'auth_remote_data_source.dart';

class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  @override
  Future<AuthUser> signInWithApple() async {
    throw UnsupportedError('Mock social sign-in is disabled. Use real SocialAuthService.');
  }

  @override
  Future<AuthUser> signInWithEmail({required String email, required String password}) async {
    return AuthUser(id: 'user_01', email: email, displayName: 'LifeOS User');
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    throw UnsupportedError('Mock social sign-in is disabled. Use real SocialAuthService.');
  }

  @override
  Future<void> enableBiometricLogin() async {}

  @override
  Future<void> enableTwoFactor() async {}

  @override
  Future<String> sendPasswordReset({required String email}) async => '000000';

  @override
  Future<void> verifyOtp({required String code}) async {}
}
