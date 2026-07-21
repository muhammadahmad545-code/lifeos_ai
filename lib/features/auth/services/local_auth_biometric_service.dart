import 'package:local_auth/local_auth.dart';

import 'biometric_service.dart';

class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService({LocalAuthentication? localAuthentication})
      : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<bool> authenticate() {
    return _localAuthentication.authenticate(
      localizedReason: 'Authenticate to unlock LIFEOS AI',
      options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
    );
  }

  @override
  Future<bool> canAuthenticate() {
    return _localAuthentication.canCheckBiometrics;
  }
}