import 'dart:convert';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  PasswordHasher._();

  static String hash(String password) {
    final Digest digest = sha256.convert(utf8.encode(password));
    return digest.toString();
  }

  static bool verify(String password, String hash) {
    return PasswordHasher.hash(password) == hash;
  }
}
