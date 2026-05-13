// ui/device_list_screen.dart
// Shows discovered (unverified) and paired (trusted) devices.
// Starts a PairingSession when the user taps a new device.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/discovery/models/device.dart';
import '../features/pairing/pairing_session.dart';
import '../features/pairing/trusted_device.dart';
import '../state/device_state.dart';
import '../state/init_provider.dart';
import '../state/trusted_devices_provider.dart';

class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceState = ref.watch(deviceStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Devices', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Nearby'),
          _buildDiscoveredDevices(context, ref, deviceState.discoveredDevices),
          const SizedBox(height: 24),
          _sectionHeader('Trusted'),
          _buildTrustedDevices(context, ref, deviceState.pairedDevices),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _buildDiscoveredDevices(
    BuildContext context,
    WidgetRef ref,
    List<Device> devices,
  ) {
    if (devices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No devices nearby', style: TextStyle(color: Colors.white38)),
      );
    }
    return Column(
      children: devices
          .map((d) => ListTile(
                leading: const Icon(Icons.devices_other, color: Colors.white70),
                title: Text(d.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text(d.ipAddress, style: const TextStyle(color: Colors.white38)),
                trailing: TextButton(
                  onPressed: () => _onPairDevice(context, ref, d),
                  child: const Text('Pair', style: TextStyle(color: Color(0xFF238636))),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildTrustedDevices(
    BuildContext context,
    WidgetRef ref,
    List<TrustedDevice> devices,
  ) {
    if (devices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No trusted devices yet', style: TextStyle(color: Colors.white38)),
      );
    }
    return Column(
      children: devices
          .map((d) => ListTile(
                leading: const Icon(Icons.verified_user, color: Color(0xFF238636)),
                title: Text(d.deviceName, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  'Paired ${d.pairingDate.toLocal().toString().substring(0, 10)}',
                  style: const TextStyle(color: Colors.white38),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _onRemoveTrust(ref, d),
                ),
              ))
          .toList(),
    );
  }

  // ── Pairing Flow ──────────────────────────────────────────────────────────

  Future<void> _onPairDevice(
    BuildContext context,
    WidgetRef ref,
    Device device,
  ) async {
    final cryptoManager = ref.read(cryptoManagerProvider);
    final secureStorage = ref.read(secureStorageProvider);

    final session = PairingSession(
      cryptoManager: cryptoManager,
      secureStorage: secureStorage,
    );

    // Show a progress indicator while the TCP handshake runs.
    _showSnackBar(context, 'Connecting to ${device.name}…');

    try {
      await session.initiate(device);
      final code = await session.generateConfirmationCode();

      if (!context.mounted) return;

      // Show confirmation code dialog.
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _PairingConfirmDialog(
          deviceName: device.name,
          confirmationCode: code,
        ),
      );

      if (confirmed == true) {
        final deviceManager = ref.read(trustedDeviceManagerProvider);
        final trusted = await session.completePairing(
          device,
          deviceManager: deviceManager,
        );
        ref.read(deviceStateProvider.notifier).addPaired(trusted);
        if (context.mounted) {
          _showSnackBar(context, 'Paired with ${device.name} ✓');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Pairing failed: $e', isError: true);
      }
    } finally {
      session.dispose();
    }
  }

  void _onRemoveTrust(WidgetRef ref, TrustedDevice device) {
    ref.read(deviceStateProvider.notifier).removePaired(device.deviceId);
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF238636),
      ),
    );
  }
}

// ── Pairing Confirmation Dialog ──────────────────────────────────────────────

class _PairingConfirmDialog extends StatelessWidget {
  final String deviceName;
  final String confirmationCode;

  const _PairingConfirmDialog({
    required this.deviceName,
    required this.confirmationCode,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Pair with $deviceName',
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Verify that the same code appears on both devices:',
            style: TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF238636), width: 1.5),
            ),
            child: Text(
              confirmationCode,
              style: const TextStyle(
                color: Color(0xFF238636),
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF238636),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Codes Match', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
