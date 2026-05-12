// features/discovery/adapters/bonjour_adapter.dart
// iOS-specific mDNS adapter.
// The `nsd` package wraps Bonjour on iOS, so this delegates to NsdAdapter.
// Kept as a separate class to preserve the UML architecture and allow
// iOS-specific customization (e.g. Bonjour TXT records, Keychain integration).

import '../models/device.dart';
import '../models/platform_type.dart';
import 'discovery_adapter.dart';
import 'nsd_adapter.dart';

class BonjourAdapter extends DiscoveryAdapter {
  final NsdAdapter _delegate;

  BonjourAdapter({required String deviceName, required int port})
      : _delegate = NsdAdapter(
          deviceName: deviceName,
          port: port,
          platformType: PlatformType.iOS,
        );

  @override
  String get serviceName => _delegate.serviceName;

  @override
  String get serviceType => _delegate.serviceType;

  @override
  set onDeviceFound(void Function(Device device)? cb) =>
      _delegate.onDeviceFound = cb;

  @override
  void Function(Device device)? get onDeviceFound => _delegate.onDeviceFound;

  @override
  set onDeviceLost(void Function(Device device)? cb) =>
      _delegate.onDeviceLost = cb;

  @override
  void Function(Device device)? get onDeviceLost => _delegate.onDeviceLost;

  @override
  Future<void> advertise() => _delegate.advertise();

  @override
  Future<void> stopAdvertise() => _delegate.stopAdvertise();

  @override
  Future<void> browse() => _delegate.browse();

  @override
  Future<void> stopBrowse() => _delegate.stopBrowse();
}
