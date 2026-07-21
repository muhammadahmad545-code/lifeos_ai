import '../../domain/auth_user.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheSession(AuthUser? user);

  Future<AuthUser?> readCachedSession();
}