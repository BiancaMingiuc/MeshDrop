// features/pairing/trusted_device_manager.dart
// Manages the list of trusted (paired) devices stored in SecureStorage.
// Provides load and remove operations. The write is handled by PairingSession.

import 'dart:convert';

import 'secure_storage/secure_storage.dart';
import 'trusted_device.dart';

class TrustedDeviceManager {
  final SecureStorage _secureStorage;

  TrustedDeviceManager({required SecureStorage secureStorage})
      : _secureStorage = secureStorage;

  /// Loads all trusted devices from SecureStorage by scanning for keys
  /// that start with the `trusted_` prefix.
  Future<List<TrustedDevice>> loadTrustedDevices() async {
    final devices = <TrustedDevice>[];

    // flutter_secure_storage supports readAll() which returns all key-value pairs.
    // Since our SecureStorage interface only exposes read/write/delete/containsKey,
    // we need to try known keys. For a production app, we'd add a readAll()
    // method to the interface. For now, we store a manifest of trusted device IDs.
    final manifest = await _secureStorage.read(key: _manifestKey);
    if (manifest == null) return devices;

    final ids = (jsonDecode(manifest) as List).cast<String>();
    for (final id in ids) {
      final raw = await _secureStorage.read(key: 'trusted_$id');
      if (raw != null) {
        try {
          devices.add(TrustedDevice.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          ));
        } catch (_) {
          // Skip corrupted entries.
        }
      }
    }
    return devices;
  }

  /// Removes a trusted device from SecureStorage.
  Future<void> removeDevice(String deviceId) async {
    await _secureStorage.delete(key: 'trusted_$deviceId');
    await _removeFromManifest(deviceId);
  }

  /// Adds a device ID to the manifest list (called after PairingSession.completePairing).
  Future<void> registerDevice(String deviceId) async {
    final ids = await _loadManifest();
    if (!ids.contains(deviceId)) {
      ids.add(deviceId);
      await _saveManifest(ids);
    }
  }

  // ── Manifest Helpers ──────────────────────────────────────────────────────

  static const _manifestKey = 'trusted_device_manifest';

  Future<List<String>> _loadManifest() async {
    final raw = await _secureStorage.read(key: _manifestKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  Future<void> _saveManifest(List<String> ids) async {
    await _secureStorage.write(
      key: _manifestKey,
      value: jsonEncode(ids),
    );
  }

  Future<void> _removeFromManifest(String deviceId) async {
    final ids = await _loadManifest();
    ids.remove(deviceId);
    await _saveManifest(ids);
  }
}
