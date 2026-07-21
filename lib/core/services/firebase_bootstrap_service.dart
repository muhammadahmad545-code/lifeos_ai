import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import 'app_logger.dart';

class FirebaseBootstrapService {
  static bool isAvailable = false;

  Future<void> initialize() async {
    if (_isPlaceholderConfig()) {
      AppLogger.info('Firebase placeholder detected — running in local offline mode.');
      isAvailable = false;
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      isAvailable = true;
      AppLogger.info('Firebase initialized successfully.');
    } catch (error, stackTrace) {
      isAvailable = false;
      AppLogger.error('Firebase init failed — falling back to local mode.', error, stackTrace);
    }
  }

  bool _isPlaceholderConfig() {
    final FirebaseOptions options = DefaultFirebaseOptions.currentPlatform;
    return options.apiKey.contains('Z0Z0Z0') ||
        options.projectId.contains('lifeos-ai-production') && options.appId.contains('000000000000');
  }
}
