import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (Platform.isIOS) {
      return ios;
    } else if (Platform.isAndroid) {
      return android;
    } else if (Platform.isLinux || Platform.isWindows) {
      throw UnsupportedError('Linux and Windows are not supported platforms.');
    }
    return web;
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDsX0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'lifeos-ai-production',
    storageBucket: 'lifeos-ai-production.appspot.com',
    iosClientId: '000000000000-0000000000000000000000000000000.apps.googleusercontent.com',
    iosBundleId: 'com.lifeosai.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDsX0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'lifeos-ai-production',
    storageBucket: 'lifeos-ai-production.appspot.com',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDsX0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'lifeos-ai-production',
    storageBucket: 'lifeos-ai-production.appspot.com',
    authDomain: 'lifeos-ai-production.firebaseapp.com',
  );
}