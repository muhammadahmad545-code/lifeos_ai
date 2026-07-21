abstract class BiometricService {
  Future<bool> canAuthenticate();

  Future<bool> authenticate();
}