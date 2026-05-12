// features/pairing/secure_storage/secure_storage.dart
// Interface (abstract class) for OS-native secure key storage.
// Dependency Inversion: PairingSession and CryptoManager call this interface;
// the concrete implementation (FlutterSecureStorageImpl) is injected at runtime.

abstract class SecureStorage {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<bool> containsKey(String key);
}
