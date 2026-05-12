// ui/device_list_screen.dart
// Shows discovered (unverified) and paired (trusted) devices.
// Starts a PairingSession when the user taps a new device.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/pairing/trusted_device.dart';
import '../features/discovery/models/device.dart';
import '../state/device_state.dart';

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
          showDiscoveredDevices(context, ref, deviceState.discoveredDevices),
          const SizedBox(height: 24),
          _sectionHeader('Trusted'),
          showTrustedDevices(context, ref, deviceState.pairedDevices),
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

  Widget showDiscoveredDevices(
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
                  onPressed: () => onPairDevice(context, ref, d),
                  child: const Text('Pair', style: TextStyle(color: Color(0xFF238636))),
                ),
              ))
          .toList(),
    );
  }

  Widget showTrustedDevices(
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
                  onPressed: () => onRemoveTrust(ref, d),
                ),
              ))
          .toList(),
    );
  }

  void onPairDevice(BuildContext context, WidgetRef ref, Device device) {
    // TODO: Instantiate PairingSession and show confirmation code dialog.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pairing with ${device.name}...')),
    );
  }

  void onRemoveTrust(WidgetRef ref, TrustedDevice device) {
    ref.read(deviceStateProvider.notifier).removePaired(device.deviceId);
  }
}
