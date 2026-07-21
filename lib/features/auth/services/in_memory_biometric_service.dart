import 'biometric_service.dart';

class InMemoryBiometricService implements BiometricService {
  @override
  Future<bool> authenticate() async {
    return true;
  }

  @override
  Future<bool> canAuthenticate() async {
    return true;
  }
}