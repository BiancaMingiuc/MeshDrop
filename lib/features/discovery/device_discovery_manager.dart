// features/discovery/device_discovery_manager.dart
// Owns a DiscoveryAdapter (injected at runtime based on platform) and
// manages the list of currently discovered peers.
// Open/Closed Principle: adding a new platform = new adapter subclass only.

import 'adapters/discovery_adapter.dart';
import 'models/device.dart';

class DeviceDiscoveryManager {
  final DiscoveryAdapter _adapter;
  final List<Device> _discoveredDevices = [];

  /// Callback fired whenever the device list changes.
  void Function(List<Device> devices)? onDevicesChanged;

  DeviceDiscoveryManager({required DiscoveryAdapter adapter})
      : _adapter = adapter {
    _adapter.onDeviceFound = _handleDeviceFound;
    _adapter.onDeviceLost = _handleDeviceLost;
  }

  List<Device> getDiscoveredDevices() => List.unmodifiable(_discoveredDevices);

  Future<void> startAdvertising() => _adapter.advertise();
  Future<void> stopAdvertising() => _adapter.stopAdvertise();
  Future<void> startBrowsing() => _adapter.browse();
  Future<void> stopBrowsing() => _adapter.stopBrowse();

  void onDeviceFound(Device device) => _handleDeviceFound(device);
  void onDeviceLost(Device device) => _handleDeviceLost(device);

  void _handleDeviceFound(Device device) {
    if (!_discoveredDevices.contains(device)) {
      _discoveredDevices.add(device);
      onDevicesChanged?.call(getDiscoveredDevices());
    }
  }

  void _handleDeviceLost(Device device) {
    _discoveredDevices.remove(device);
    onDevicesChanged?.call(getDiscoveredDevices());
  }

  /// Resolves the freshest IP and port for [device].
  /// Always called before opening a transfer socket since IPs can change.
  Device resolveDevice(String deviceId) {
    return _discoveredDevices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => throw StateError('Device $deviceId not found'),
    );
  }

  void dispose() {
    stopAdvertising();
    stopBrowsing();
  }
}
