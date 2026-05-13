// state/trusted_devices_provider.dart
// Riverpod provider that loads trusted devices from SecureStorage on startup
// and populates DeviceState.pairedDevices.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/pairing/trusted_device_manager.dart';
import 'device_state.dart';
import 'init_provider.dart';

/// Provides the TrustedDeviceManager singleton.
final trustedDeviceManagerProvider = Provider<TrustedDeviceManager>((ref) {
  return TrustedDeviceManager(
    secureStorage: ref.read(secureStorageProvider),
  );
});

/// Loads trusted devices from SecureStorage and pushes them into DeviceState.
/// Should be watched by a top-level widget (e.g. HomeScreen) to trigger loading.
final loadTrustedDevicesProvider = FutureProvider<void>((ref) async {
  final manager = ref.read(trustedDeviceManagerProvider);
  final devices = await manager.loadTrustedDevices();
  final notifier = ref.read(deviceStateProvider.notifier);
  for (final device in devices) {
    notifier.addPaired(device);
  }
});
