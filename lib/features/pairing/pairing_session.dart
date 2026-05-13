// features/pairing/pairing_session.dart
// Manages the full Diffie-Hellman key exchange + confirmation flow
// between two MeshDrop devices. Produces a TrustedDevice on success.
//
// Security properties:
//  - X25519 ECDH: shared secret never transmitted over the network.
//  - Confirmation code (6-digit): defends against MITM attacks.
//  - Keys stored via SecureStorage (platform Keychain/Keystore).
//
// Network flow:
//  Initiator:  connect → send our public key → read their public key → derive secret
//  Receiver:   accept connection → read their public key → send our public key → derive secret

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../discovery/models/device.dart';
import '../encryption/crypto_manager.dart';
import 'pairing_network_protocol.dart';
import 'secure_storage/secure_storage.dart';
import 'trusted_device.dart';
import 'trusted_device_manager.dart';

class PairingSession {
  static const int pairingPort = 58433;

  final CryptoManager _cryptoManager;
  final SecureStorage _secureStorage;

  SimpleKeyPair? _localKeyPair;
  Uint8List? _remotePublicKey;
  Uint8List? _sharedSecret;
  String? _confirmationCode;

  ServerSocket? _pairingServer;

  PairingSession({
    required CryptoManager cryptoManager,
    required SecureStorage secureStorage,
  })  : _cryptoManager = cryptoManager,
        _secureStorage = secureStorage;

  // ── Initiator Side ──────────────────────────────────────────────────────────

  /// Step 1 (initiator): Generate our X25519 key pair and exchange keys
  /// with [device] over a TCP socket on port [pairingPort].
  Future<void> initiate(Device device) async {
    _localKeyPair = await _cryptoManager.generateX25519KeyPair();
    final localPublicKey = await performKeyExchange();

    final socket = await Socket.connect(
      device.ipAddress,
      pairingPort,
      timeout: const Duration(seconds: 10),
    );

    try {
      // Send our public key, then read theirs.
      await PairingNetworkProtocol.sendPublicKey(socket, localPublicKey);
      final remoteKey = await PairingNetworkProtocol.readPublicKey(socket);
      if (remoteKey == null) {
        throw StateError('Invalid pairing response from ${device.name}');
      }
      setRemotePublicKey(remoteKey);
    } finally {
      socket.destroy();
    }
  }

  // ── Receiver Side ───────────────────────────────────────────────────────────

  /// Starts a TCP server on [pairingPort] that waits for a single incoming
  /// pairing request. Completes when the key exchange is done.
  Future<void> startPairingServer() async {
    _localKeyPair = await _cryptoManager.generateX25519KeyPair();
    final localPublicKey = await performKeyExchange();

    _pairingServer =
        await ServerSocket.bind(InternetAddress.anyIPv4, pairingPort);

    // Accept exactly one connection, then close the server.
    final socket = await _pairingServer!.first;
    try {
      // Read their public key, then send ours.
      final remoteKey = await PairingNetworkProtocol.readPublicKey(socket);
      if (remoteKey == null) {
        throw StateError('Invalid pairing request');
      }
      setRemotePublicKey(remoteKey);
      await PairingNetworkProtocol.sendPublicKey(socket, localPublicKey);
    } finally {
      socket.destroy();
      await stopPairingServer();
    }
  }

  Future<void> stopPairingServer() async {
    await _pairingServer?.close();
    _pairingServer = null;
  }

  // ── Key Exchange Logic ──────────────────────────────────────────────────────

  /// Extracts our public key bytes to send to the remote device.
  Future<Uint8List> performKeyExchange() async {
    assert(_localKeyPair != null, 'Call initiate() or startPairingServer() first');
    final publicKey = await _localKeyPair!.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }

  /// Sets the remote device's public key (received over the socket).
  void setRemotePublicKey(Uint8List remotePublicKey) {
    _remotePublicKey = remotePublicKey;
  }

  /// Derives the shared secret and generates the confirmation code.
  /// Both sides arrive at the same 6-digit code without transmitting it.
  Future<String> generateConfirmationCode() async {
    assert(_remotePublicKey != null, 'Key exchange must complete first');
    _sharedSecret = await _cryptoManager.deriveSharedSecret(_remotePublicKey!);
    _confirmationCode = _deriveCode(_sharedSecret!);
    return _confirmationCode!;
  }

  /// Returns the confirmation code, or null if not yet generated.
  String? get confirmationCode => _confirmationCode;

  /// Returns the shared secret for creating an EncryptionSession.
  /// Only available after confirmation code generation.
  Uint8List? get sharedSecret => _sharedSecret;

  /// User confirms the codes match on both screens.
  bool verifyPairing(String code) => code == _confirmationCode;

  /// Persists the TrustedDevice and returns it.
  /// If [deviceManager] is provided, also registers the device ID in the
  /// manifest so it can be loaded on next app startup.
  Future<TrustedDevice> completePairing(
    Device device, {
    TrustedDeviceManager? deviceManager,
  }) async {
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
    await deviceManager?.registerDevice(device.id);
    return trusted;
  }

  /// Derives a deterministic 6-digit code from the shared secret.
  String _deriveCode(Uint8List secret) {
    int value = 0;
    for (int i = 0; i < 4 && i < secret.length; i++) {
      value = (value * 256 + secret[i]) % 1000000;
    }
    return value.toString().padLeft(6, '0');
  }

  void dispose() {
    stopPairingServer();
  }
}
