import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void info(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[INFO] $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[ERROR] $message');
      if (error != null) {
        // ignore: avoid_print
        print(error);
      }
      if (stackTrace != null) {
        // ignore: avoid_print
        print(stackTrace);
      }
    }
  }
}
