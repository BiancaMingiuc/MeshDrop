// features/discovery/adapters/avahi_adapter.dart
// Windows/Linux mDNS adapter.
// The `nsd` package uses Avahi (Linux) and the Windows mDNS API under the hood,
// so this delegates to NsdAdapter. Kept separate per the UML for
// desktop-specific customization (firewall rules, network interface selection).

import '../models/device.dart';
import '../models/platform_type.dart';
import 'discovery_adapter.dart';
import 'nsd_adapter.dart';
import 'dart:io';

class AvahiAdapter extends DiscoveryAdapter {
  final NsdAdapter _delegate;

  AvahiAdapter({required String deviceName, required int port})
      : _delegate = NsdAdapter(
          deviceName: deviceName,
          port: port,
          platformType: Platform.isWindows
              ? PlatformType.windows
              : PlatformType.linux,
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
