// core/app_initializer.dart
// Bootstraps the entire app: initializes SecureStorage, generates identity
// keys on first launch, and kicks off device discovery.
// Called via Riverpod providers — settings are loaded separately by
// AppSettingsNotifier so they're available as a provider dependency.

import 'dart:convert';

import '../features/encryption/crypto_manager.dart';
import '../features/pairing/secure_storage/secure_storage.dart';

class AppInitializer {
  final SecureStorage _secureStorage;
  final CryptoManager _cryptoManager;

  AppInitializer({
    required SecureStorage secureStorage,
    required CryptoManager cryptoManager,
  })  : _secureStorage = secureStorage,
        _cryptoManager = cryptoManager;

  /// Verifies keystore access and generates the Ed25519 identity key pair
  /// on first launch. The private key is stored in SecureStorage so it
  /// persists across restarts; the public key is derived from it on demand.
  Future<void> ensureIdentityKeys() async {
    final hasKey =
        await _secureStorage.containsKey('identity_ed25519_private');
    if (hasKey) return;

    final keyPair = await _cryptoManager.generateEd25519KeyPair();
    final privateKey = await keyPair.extractPrivateKeyBytes();
    await _secureStorage.write(
      key: 'identity_ed25519_private',
      value: base64Encode(privateKey),
    );

    final publicKey = await keyPair.extractPublicKey();
    await _secureStorage.write(
      key: 'identity_ed25519_public',
      value: base64Encode(publicKey.bytes),
    );
  }
}
