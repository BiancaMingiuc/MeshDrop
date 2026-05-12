// features/discovery/adapters/nsd_adapter.dart
// Cross-platform mDNS adapter using the `nsd` package.
// Used on Android natively; also the default fallback for Windows/Linux
// until platform-specific adapters (AvahiAdapter) are wired in.

import 'package:nsd/nsd.dart';

import '../models/device.dart';
import '../models/platform_type.dart';
import 'discovery_adapter.dart';

class NsdAdapter extends DiscoveryAdapter {
  static const String _serviceType = '_meshdrop._tcp';

  final String _deviceName;
  final int _port;
  final PlatformType _platformType;

  Registration? _registration;
  Discovery? _discovery;

  NsdAdapter({
    required String deviceName,
    required int port,
    required PlatformType platformType,
  })  : _deviceName = deviceName,
        _port = port,
        _platformType = platformType;

  @override
  String get serviceName => 'MeshDrop-$_deviceName';

  @override
  String get serviceType => _serviceType;

  @override
  Future<void> advertise() async {
    // TODO: Populate txt attributes with device metadata (id, platform).
    final service = Service(
      name: serviceName,
      type: serviceType,
      port: _port,
    );
    _registration = await register(service);
  }

  @override
  Future<void> stopAdvertise() async {
    if (_registration != null) {
      await unregister(_registration!);
      _registration = null;
    }
  }

  @override
  Future<void> browse() async {
    _discovery = await startDiscovery(serviceType);
    _discovery!.addServiceListener((service, status) async {
      if (status == ServiceStatus.found) {
        // We must explicitly resolve the service to get its IP and port.
        try {
          final resolvedService = await resolve(service);
          final device = _serviceToDevice(resolvedService);
          if (device != null) onDeviceFound?.call(device);
        } catch (e) {
          // Ignored
        }
      } else if (status == ServiceStatus.lost) {
        final device = _serviceToDevice(service);
        if (device != null) onDeviceLost?.call(device);
      }
    });
  }

  @override
  Future<void> stopBrowse() async {
    if (_discovery != null) {
      await stopDiscovery(_discovery!);
      _discovery = null;
    }
  }

  /// Converts an mDNS [Service] record into a [Device].
  Device? _serviceToDevice(Service service) {
    final host = service.host;
    final port = service.port;
    if (host == null || port == null) return null;

    // TODO: Parse device id and platform from TXT record attributes.
    return Device(
      id: service.name ?? host,
      name: service.name ?? host,
      ipAddress: host,
      port: port,
      platform: _platformType,
    );
  }
}
