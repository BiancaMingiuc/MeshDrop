// state/discovery_provider.dart
// Riverpod provider that owns DeviceDiscoveryManager and wires its
// onDevicesChanged callback directly into DeviceStateNotifier.
// This is the missing bridge between the discovery layer and the UI.

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/discovery/adapters/avahi_adapter.dart';
import '../features/discovery/adapters/bonjour_adapter.dart';
import '../features/discovery/adapters/nsd_adapter.dart';
import '../features/discovery/adapters/discovery_adapter.dart';
import '../features/discovery/device_discovery_manager.dart';
import '../features/discovery/models/platform_type.dart';
import 'device_state.dart';

/// Builds the correct adapter for the current platform.
DiscoveryAdapter _makeAdapter() {
  final deviceName = Platform.localHostname;
  const port = 58432;
  if (Platform.isIOS) {
    return BonjourAdapter(deviceName: deviceName, port: port);
  } else if (Platform.isAndroid) {
    return NsdAdapter(
      deviceName: deviceName,
      port: port,
      platformType: PlatformType.android,
    );
  } else {
    return AvahiAdapter(deviceName: deviceName, port: port);
  }
}

/// A provider that creates + starts the DeviceDiscoveryManager and
/// wires it so every discovered device is pushed into DeviceStateNotifier.
final discoveryManagerProvider =
    Provider<DeviceDiscoveryManager>((ref) {
  final manager = DeviceDiscoveryManager(adapter: _makeAdapter());

  // ─── THE CRITICAL BRIDGE ───────────────────────────────────────────────────
  // Whenever the discovery layer finds or loses a device, update Riverpod state.
  manager.onDevicesChanged = (devices) {
    final notifier = ref.read(deviceStateProvider.notifier);
    for (final device in devices) {
      notifier.addDiscovered(device);
    }
    // Remove devices that are no longer present.
    final currentIds = devices.map((d) => d.id).toSet();
    final existing = ref.read(deviceStateProvider).discoveredDevices;
    for (final old in existing) {
      if (!currentIds.contains(old.id)) {
        notifier.removeDiscovered(old);
      }
    }
  };

  // Start advertising + browsing immediately.
  manager.startAdvertising();
  manager.startBrowsing();

  // Clean up when the provider is disposed (app closes).
  ref.onDispose(() => manager.dispose());

  return manager;
});
