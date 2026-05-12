// features/encryption/encryption_session.dart
// Short-lived session object tying together the session key and nonce
// for one file transfer. Nonce is refreshed per-chunk (AEAD requirement).

import 'dart:typed_data';
import 'dart:math';

class EncryptionSession {
  final String sessionId;
  final Uint8List sessionKey;
  Uint8List nonce;
  final String algorithm;
  final DateTime createdAt;
  bool isActive;

  EncryptionSession({
    required this.sessionId,
    required this.sessionKey,
    required this.nonce,
    this.algorithm = 'ChaCha20-Poly1305',
    DateTime? createdAt,
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Generates a new random 12-byte nonce. Must be called between every chunk
  /// to prevent nonce reuse (catastrophic for ChaCha20-Poly1305 security).
  void refreshNonce() {
    final rng = Random.secure();
    nonce = Uint8List.fromList(
      List<int>.generate(12, (_) => rng.nextInt(256)),
    );
  }

  /// Marks the session as invalid. Called after transfer completes or fails.
  void invalidate() => isActive = false;
}
