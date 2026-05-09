import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class MessageEncryption {
  static const String _saltPrefix = 'ANA_IFS_VOICE_SALT';
  static const int _iterations = 10000;
  static const int _keyLength = 32;

  static Uint8List _deriveKey(String uid) {
    final salt = utf8.encode(_saltPrefix);
    final key = _pbkdf2(uid, salt, _iterations, _keyLength);
    return Uint8List.fromList(key);
  }

  static String encryptMessage(String plainText, String uid) {
    try {
      if (plainText.isEmpty) return '';

      final key = _deriveKey(uid);
      final textBytes = utf8.encode(plainText);
      final encrypted = Uint8List(textBytes.length);

      for (int i = 0; i < textBytes.length; i++) {
        encrypted[i] = textBytes[i] ^ key[i % key.length];
      }

      final random = Random.secure();
      final salt = Uint8List(8);
      for (int i = 0; i < 8; i++) {
        salt[i] = random.nextInt(256);
      }

      final result = Uint8List(8 + encrypted.length)
        ..setAll(0, salt)
        ..setAll(8, encrypted);

      return base64.encode(result);
    } catch (e) {
      print("Encryption error: $e");
      return 'FB:${base64.encode(utf8.encode(plainText))}';
    }
  }

  static String decryptMessage(String encryptedBase64, String uid) {
    try {
      if (encryptedBase64.isEmpty) return '';

      // Check for fallback encoding
      if (encryptedBase64.startsWith('FB:')) {
        return utf8.decode(base64.decode(encryptedBase64.substring(3)));
      }

      // ✅ NEW: Check if this is an old plain text message (not encrypted)
      // Old messages are stored as plain text, not base64, or are short
      final bool isLikelyPlainText =
          encryptedBase64.length < 16 ||
              !RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(encryptedBase64) ||
              (encryptedBase64.contains(' ') && encryptedBase64.length < 100);

      if (isLikelyPlainText) {
        print("Detected old plain text message, returning as-is: ${encryptedBase64.substring(0, encryptedBase64.length > 50 ? 50 : encryptedBase64.length)}");
        return encryptedBase64; // Return old plain text message as-is
      }

      // Try to decrypt as encrypted message
      final combined = base64.decode(encryptedBase64);
      if (combined.length < 8) return encryptedBase64; // Return as-is if too short

      final encrypted = combined.sublist(8);
      final key = _deriveKey(uid);
      final decrypted = Uint8List(encrypted.length);

      for (int i = 0; i < encrypted.length; i++) {
        decrypted[i] = encrypted[i] ^ key[i % key.length];
      }

      final result = utf8.decode(decrypted);
      print("Successfully decrypted message: ${result.substring(0, result.length > 50 ? 50 : result.length)}");
      return result;
    } catch (e) {
      print("Decryption error: $e, returning original as plain text");
      // If decryption fails, return the original (old plain text message)
      return encryptedBase64;
    }
  }

  // Helper function to check if a string is base64 encoded
  static bool isBase64(String str) {
    try {
      base64.decode(str);
      return true;
    } catch (_) {
      return false;
    }
  }

  static List<int> _pbkdf2(String password, List<int> salt, int iterations, int keyLength) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final derivedKey = <int>[];
    var block = 1;

    while (derivedKey.length < keyLength) {
      var blockData = <int>[];
      blockData.addAll(salt);
      blockData.addAll(_intToBytes(block));

      var u = hmac.convert(blockData).bytes;
      var t = List<int>.from(u);

      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < u.length; j++) {
          t[j] ^= u[j];
        }
      }

      derivedKey.addAll(t);
      block++;
    }

    return derivedKey.sublist(0, keyLength);
  }

  static List<int> _intToBytes(int value) {
    final bytes = <int>[];
    for (var i = 3; i >= 0; i--) {
      bytes.add((value >> (i * 8)) & 0xFF);
    }
    return bytes;
  }
}