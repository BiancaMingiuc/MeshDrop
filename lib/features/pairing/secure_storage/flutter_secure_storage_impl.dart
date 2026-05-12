// features/pairing/secure_storage/flutter_secure_storage_impl.dart
// Concrete implementation of SecureStorage backed by flutter_secure_storage.
// Uses iOS Keychain, Android Keystore, and OS credential managers on desktop.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'secure_storage.dart';

class FlutterSecureStorageImpl implements SecureStorage {
  final FlutterSecureStorage _storage;

  FlutterSecureStorageImpl()
      : _storage = const FlutterSecureStorage(
          // Android options: use EncryptedSharedPreferences for added safety.
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<bool> containsKey(String key) => _storage.containsKey(key: key);
}
