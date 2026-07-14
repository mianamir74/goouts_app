import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Hashes a PIN using SHA-256 with the user's UID as salt.
/// This means even if two users have the same PIN, their hashes differ.
class PinHasher {
  /// Returns a SHA-256 hex hash of [pin] salted with [uid].
  static String hash(String pin, String uid) {
    final salted = '$uid:$pin';
    final bytes = utf8.encode(salted);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Returns true if [enteredPin] matches [storedHash].
  static bool verify(String enteredPin, String storedHash, String uid) {
    return hash(enteredPin, uid) == storedHash;
  }
}
