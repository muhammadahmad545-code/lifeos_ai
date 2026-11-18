import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Optional app lock using the device's own unlock (fingerprint, face, PIN, pattern or password).
abstract final class AppLock {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// True when the device has a screen lock the prompt can fall back to.
  static Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('app lock availability check failed: $e');
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock LifeOS',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
    } on PlatformException catch (e) {
      debugPrint('app lock authenticate failed: ${e.code} ${e.message}');
      return false;
    }
  }
}
