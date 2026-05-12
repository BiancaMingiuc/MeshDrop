// core/app_initializer.dart
// Bootstraps the entire app: loads settings, initializes SecureStorage,
// and kicks off device discovery. Nothing else starts before this finishes.


import 'package:path_provider/path_provider.dart';

import '../core/app_settings.dart';
import '../features/pairing/secure_storage/secure_storage.dart';
import '../features/discovery/device_discovery_manager.dart';
import '../features/discovery/adapters/discovery_adapter.dart';


class AppInitializer {
  late AppSettings settings;
  late SecureStorage secureStorage;
  late DeviceDiscoveryManager discoveryManager;

  /// Entry point called from main(). Order matters:
  /// 1. loadSettings, 2. initSecureStorage, 3. startDiscovery.
  Future<void> initialize({
    required SecureStorage storage,
    required DiscoveryAdapter adapter,
  }) async {
    secureStorage = storage;
    settings = await loadSettings();
    await initSecureStorage();
    discoveryManager = DeviceDiscoveryManager(adapter: adapter);
    await startDiscovery();
  }

  /// Reads persisted user preferences. Falls back to defaults on first run.
  Future<AppSettings> loadSettings() async {
    // TODO: Read from shared_preferences or secure storage.
    final directory = await getApplicationDocumentsDirectory();
    return AppSettings(downloadDirectory: directory.path);
  }

  /// Warms up SecureStorage so cryptographic keys are ready to serve.
  Future<void> initSecureStorage() async {
    // TODO: Verify keystore access; generate identity key pair if absent.
    final hasKey = await secureStorage.containsKey('identity_ed25519_private');
    if (!hasKey) {
      // CryptoManager will generate and store keys on first use.
    }
  }

  /// Starts advertising this device and browsing for peers on the local network.
  Future<void> startDiscovery() async {
    discoveryManager.startAdvertising();
    discoveryManager.startBrowsing();
  }
}
