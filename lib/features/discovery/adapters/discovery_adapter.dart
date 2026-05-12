// features/discovery/adapters/discovery_adapter.dart
// Abstract base for all platform-specific mDNS/DNS-SD adapters.
// Adapter pattern: DeviceDiscoveryManager calls these methods without
// knowing which concrete platform implementation is being used.

import 'package:flutter/foundation.dart';

import '../models/device.dart';

abstract class DiscoveryAdapter {
  /// mDNS service name (e.g. "MeshDrop-AlicesiPhone").
  @protected
  String get serviceName;

  /// mDNS service type (e.g. "_meshdrop._tcp").
  @protected
  String get serviceType;

  /// Called when a peer device is found on the network.
  void Function(Device device)? onDeviceFound;

  /// Called when a previously discovered peer goes offline.
  void Function(Device device)? onDeviceLost;

  /// Start broadcasting this device's presence on the local network.
  Future<void> advertise();

  /// Stop broadcasting.
  Future<void> stopAdvertise();

  /// Start listening for other MeshDrop peers on the network.
  Future<void> browse();

  /// Stop listening.
  Future<void> stopBrowse();
}
