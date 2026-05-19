// features/encryption/crypto_manager.dart
// Stateful cryptographic engine for MeshDrop.
//
// Long-term keys:
//   - Ed25519 signing key pair  → proves identity across sessions
//   - X25519 exchange key pair  → fresh per pairing session
//
// Per-transfer:
//   - EncryptionSession with ChaCha20-Poly1305 AEAD
//
// ChaCha20-Poly1305 was chosen over AES because:
//   1. No hardware acceleration required → fast on low-end Android.
//   2. AEAD: built-in authentication tag detects any in-transit tampering.

import 'dart:math';
import 'dart:typed_data';



import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import 'encryption_session.dart';

class CryptoManager {
  SimpleKeyPair? _signingKeyPair;   // Ed25519 — long-term identity

  final _ed25519 = Ed25519();
  final _x25519 = X25519();
  final _chacha = Chacha20.poly1305Aead();
  final _uuid = const Uuid();

  // ── Key generation ──────────────────────────────────────────────────────────

  Future<SimpleKeyPair> generateEd25519KeyPair() async {
    _signingKeyPair = await _ed25519.newKeyPair();
    return _signingKeyPair!;
  }

  Future<SimpleKeyPair> generateX25519KeyPair() async {
    return await _x25519.newKeyPair();
  }

  // ── Key exchange ─────────────────────────────────────────────────────────────

  /// Derives a 32-byte shared secret from our X25519 private key and the
  /// remote device's public key. The secret is never transmitted.
  Future<Uint8List> deriveSharedSecret(SimpleKeyPair ourKeyPair, Uint8List remotePublicKeyBytes) async {
    final remotePublicKey = SimplePublicKey(
      remotePublicKeyBytes,
      type: KeyPairType.x25519,
    );
    final sharedSecretKey = await _x25519.sharedSecretKey(
      keyPair: ourKeyPair,
      remotePublicKey: remotePublicKey,
    );
    return Uint8List.fromList(await sharedSecretKey.extractBytes());
  }

  // ── Session creation ─────────────────────────────────────────────────────────

  /// Creates a fresh EncryptionSession derived from [sharedSecret].
  Future<EncryptionSession> createSession(Uint8List sharedSecret) async {
    final rng = Random.secure();
    final nonce = Uint8List.fromList(
      List<int>.generate(12, (_) => rng.nextInt(256)),
    );
    // Use the first 32 bytes of the shared secret as the session key.
    final sessionKey = sharedSecret.length >= 32
        ? sharedSecret.sublist(0, 32)
        : Uint8List.fromList([...sharedSecret, ...List.filled(32 - sharedSecret.length, 0)]);

    return EncryptionSession(
      sessionId: _uuid.v4(),
      sessionKey: sessionKey,
      nonce: nonce,
    );
  }

  // ── Encryption / Decryption ──────────────────────────────────────────────────

  /// Encrypts [plaintext] using ChaCha20-Poly1305 with the session's key+nonce.
  /// Automatically refreshes the nonce after encryption.
  Future<Uint8List> encrypt(
    Uint8List plaintext,
    EncryptionSession session,
  ) async {
    assert(session.isActive, 'Cannot encrypt with an invalidated session');
    final secretKey = SecretKey(session.sessionKey);
    final box = await _chacha.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: session.nonce,
    );
    session.refreshNonce();
    // Prepend nonce to ciphertext so the receiver can decrypt without state.
    return Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  /// Decrypts a chunk produced by [encrypt].
  Future<Uint8List> decrypt(
    Uint8List ciphertext,
    EncryptionSession session,
  ) async {
    assert(session.isActive, 'Cannot decrypt with an invalidated session');
    // Parse: [12-byte nonce][ciphertext][16-byte mac]
    final nonce = ciphertext.sublist(0, 12);
    final mac = Mac(ciphertext.sublist(ciphertext.length - 16));
    final ct = ciphertext.sublist(12, ciphertext.length - 16);

    final secretKey = SecretKey(session.sessionKey);
    final box = SecretBox(ct, nonce: nonce, mac: mac);
    return Uint8List.fromList(await _chacha.decrypt(box, secretKey: secretKey));
  }

  // ── Signing / Verification ───────────────────────────────────────────────────

  Future<Uint8List> sign(Uint8List data) async {
    assert(_signingKeyPair != null, 'Call generateEd25519KeyPair() first');
    final sig = await _ed25519.sign(data, keyPair: _signingKeyPair!);
    return Uint8List.fromList(sig.bytes);
  }

  Future<bool> verify(
    Uint8List data,
    Uint8List signatureBytes,
    SimplePublicKey publicKey,
  ) async {
    final sig = Signature(signatureBytes, publicKey: publicKey);
    return _ed25519.verify(data, signature: sig);
  }
}
