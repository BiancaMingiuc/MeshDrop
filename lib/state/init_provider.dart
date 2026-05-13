// state/init_provider.dart
// One-shot initialization provider that ensures identity keys exist
// in SecureStorage before any pairing or transfer can happen.
// Evaluated lazily on first read (triggered by HomeScreen watching it).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_initializer.dart';
import '../features/encryption/crypto_manager.dart';
import '../features/pairing/secure_storage/flutter_secure_storage_impl.dart';
import '../features/pairing/secure_storage/secure_storage.dart';

/// Provides the single CryptoManager instance shared across the app.
final cryptoManagerProvider = Provider<CryptoManager>((ref) => CryptoManager());

/// Provides the single SecureStorage instance shared across the app.
final secureStorageProvider = Provider<SecureStorage>(
  (ref) => FlutterSecureStorageImpl(),
);

/// Eagerly ensures identity keys exist. Returns a Future that completes
/// once initialization is done. Screens should `await ref.read(initProvider.future)`
/// or watch it to gate UI on readiness.
final initProvider = FutureProvider<void>((ref) async {
  final initializer = AppInitializer(
    secureStorage: ref.read(secureStorageProvider),
    cryptoManager: ref.read(cryptoManagerProvider),
  );
  await initializer.ensureIdentityKeys();
});
