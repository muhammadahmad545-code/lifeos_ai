import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'backup.dart';

/// Thrown when an encrypted backup cannot be opened with the passphrase given.
class BackupPassphraseException implements Exception {
  const BackupPassphraseException([this.message = 'Wrong passphrase. Nothing was imported.']);
  final String message;
  @override
  String toString() => message;
}

/// Passphrase protection for backup files.
///
/// The JSON backup is encrypted with AES-256-GCM. The key comes from the passphrase through
/// PBKDF2-HMAC-SHA256 with a random 16-byte salt and [defaultIterations] rounds. GCM's tag
/// authenticates the data, so a wrong passphrase (or a damaged file) fails cleanly before
/// anything is imported. The file stays JSON, so the app can recognise it:
///
/// `{"app":"lifeos","encrypted":true,"format":2,"cipher":"AES-256-GCM","kdf":"PBKDF2-HMAC-SHA256",
///   "iterations":210000,"salt":"…","nonce":"…","data":"…","mac":"…"}` (binary fields in base64).
abstract final class BackupCrypto {
  static const int defaultIterations = 210000;
  static const int minPassphraseLength = 6;

  // Bound into the GCM tag, so the header cannot be swapped onto other data.
  static const String _aad = 'plania-backup-v2';

  /// True when [text] is a Plania backup protected with a passphrase.
  static bool isEncrypted(String text) {
    // Cheap check first: plain backups can be large.
    if (!text.contains('"encrypted"')) return false;
    try {
      final data = jsonDecode(text);
      return data is Map && data['app'] == 'lifeos' && data['encrypted'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<SecretKey> _deriveKey(String passphrase, List<int> salt, int iterations) {
    final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);
    return kdf.deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  /// Encrypts a plain JSON backup. Slow on purpose (key stretching): run it off the UI thread.
  static Future<String> encrypt(String plainJson, String passphrase, {int iterations = defaultIterations}) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _deriveKey(passphrase, salt, iterations);
    final aes = AesGcm.with256bits();
    final box = await aes.encrypt(
      utf8.encode(plainJson),
      secretKey: key,
      nonce: aes.newNonce(),
      aad: utf8.encode(_aad),
    );
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'lifeos',
      'encrypted': true,
      'format': Backup.formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'cipher': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'data': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  static ({List<int> salt, List<int> nonce, List<int> cipherText, List<int> mac, int iterations}) _parse(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const BackupFormatException('This file is not valid JSON.');
    }
    if (decoded is! Map || decoded['app'] != 'lifeos' || decoded['encrypted'] != true) {
      throw const BackupFormatException('This file is not an encrypted Plania backup.');
    }
    if (decoded['cipher'] != 'AES-256-GCM' || decoded['kdf'] != 'PBKDF2-HMAC-SHA256') {
      throw const BackupFormatException('This backup was made by a newer version of Plania.');
    }
    final it = decoded['iterations'];
    if (it is! int || it < 1 || it > 10000000) throw const BackupFormatException('This backup is damaged.');
    try {
      return (
        salt: base64Decode(decoded['salt'] as String),
        nonce: base64Decode(decoded['nonce'] as String),
        cipherText: base64Decode(decoded['data'] as String),
        mac: base64Decode(decoded['mac'] as String),
        iterations: it,
      );
    } catch (_) {
      throw const BackupFormatException('This backup is damaged.');
    }
  }

  /// Decrypts an encrypted backup back to the plain JSON. Throws [BackupPassphraseException]
  /// for a wrong passphrase and [BackupFormatException] for a damaged or unknown file.
  static Future<String> decrypt(String encryptedJson, String passphrase) async {
    final (:salt, :nonce, :cipherText, :mac, :iterations) = _parse(encryptedJson);
    final key = await _deriveKey(passphrase, salt, iterations);
    try {
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
        aad: utf8.encode(_aad),
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const BackupPassphraseException();
    } on FormatException {
      throw const BackupPassphraseException();
    }
  }
}

/// Runs the slow key stretching on a background isolate so the screen stays responsive.
/// Top-level so the closures capture only the strings they need.
Future<String> encryptBackupInBackground(String plainJson, String passphrase) =>
    Isolate.run(() => BackupCrypto.encrypt(plainJson, passphrase));

Future<String> decryptBackupInBackground(String encryptedJson, String passphrase) =>
    Isolate.run(() => BackupCrypto.decrypt(encryptedJson, passphrase));
