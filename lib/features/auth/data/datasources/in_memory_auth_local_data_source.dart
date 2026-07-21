import '../../domain/auth_user.dart';
import 'auth_local_data_source.dart';

class InMemoryAuthLocalDataSource implements AuthLocalDataSource {
  AuthUser? _cachedUser;

  @override
  Future<void> cacheSession(AuthUser? user) async {
    _cachedUser = user;
  }

  @override
  Future<AuthUser?> readCachedSession() async {
    return _cachedUser;
  }
}