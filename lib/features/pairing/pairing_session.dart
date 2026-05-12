// features/pairing/pairing_session.dart
// Manages the full Diffie-Hellman key exchange + confirmation flow
// between two MeshDrop devices. Produces a TrustedDevice on success.
//
// Security properties:
//  - X25519 ECDH: shared secret never transmitted over the network.
//  - Confirmation code (6-digit): defends against MITM attacks.
//  - Keys stored via SecureStorage (platform Keychain/Keystore).

import 'dart:convert';


import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../discovery/models/device.dart';
import '../encryption/crypto_manager.dart';
import 'secure_storage/secure_storage.dart';
import 'trusted_device.dart';

class PairingSession {
  final CryptoManager _cryptoManager;
  final SecureStorage _secureStorage;

  SimpleKeyPair? _localKeyPair;
  Uint8List? _remotePublicKey;
  Uint8List? _sharedSecret;
  String? _confirmationCode;

  PairingSession({
    required CryptoManager cryptoManager,
    required SecureStorage secureStorage,
  })  : _cryptoManager = cryptoManager,
        _secureStorage = secureStorage;

  /// Step 1: Generate our X25519 key pair and initiate the exchange.
  Future<void> initiate(Device device) async {
    _localKeyPair = await _cryptoManager.generateX25519KeyPair();
    // TODO: Send local public key to [device] over a TCP socket.
  }

  /// Step 2: Compute the shared secret from our private key + their public key.
  /// Returns our public key bytes to send to the remote device.
  Future<Uint8List> performKeyExchange() async {
    assert(_localKeyPair != null, 'Call initiate() first');
    final publicKey = await _localKeyPair!.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }

  /// Step 3: Set the remote device's public key (received over the socket).
  void setRemotePublicKey(Uint8List remotePublicKey) {
    _remotePublicKey = remotePublicKey;
  }

  /// Step 4: Derive shared secret and generate the confirmation code.
  /// Both sides arrive at the same 6-digit code without transmitting it.
  Future<String> generateConfirmationCode() async {
    assert(_remotePublicKey != null, 'Call setRemotePublicKey() first');
    _sharedSecret = await _cryptoManager.deriveSharedSecret(_remotePublicKey!);
    _confirmationCode = _deriveCode(_sharedSecret!);
    return _confirmationCode!;
  }

  /// Generates a QR code image from the confirmation code for visual verification.
  /// Returns null if confirmation code hasn't been generated yet.
  // TODO: Integrate a QR code package (e.g. `qr_flutter`) here.
  dynamic generateQRCode() {
    if (_confirmationCode == null) return null;
    // TODO: return QrImage(data: _confirmationCode!);
    return null;
  }

  /// Step 5: User confirms the codes match on both screens.
  bool verifyPairing(String code) => code == _confirmationCode;

  /// Step 6: Persist the TrustedDevice and return it.
  Future<TrustedDevice> completePairing(Device device) async {
    assert(_sharedSecret != null, 'Confirmation must be generated first');
    final trusted = TrustedDevice(
      deviceId: device.id,
      deviceName: device.name,
      publicKey: _remotePublicKey!,
      pairingDate: DateTime.now(),
      lastSeen: DateTime.now(),
    );
    await _secureStorage.write(
      key: 'trusted_${device.id}',
      value: jsonEncode(trusted.toJson()),
    );
    return trusted;
  }

  /// Derives a deterministic 6-digit code from the shared secret.
  String _deriveCode(Uint8List secret) {
    // XOR-fold the first 4 bytes into a 6-digit integer.
    int value = 0;
    for (int i = 0; i < 4 && i < secret.length; i++) {
      value = (value * 256 + secret[i]) % 1000000;
    }
    return value.toString().padLeft(6, '0');
  }
}
