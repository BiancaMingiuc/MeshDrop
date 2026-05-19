// ui/home_screen.dart
// Landing screen — shows discovered devices and handles file sending.
// Also shows the incoming transfer Accept/Reject dialog.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/discovery/models/device.dart';
import '../features/transfer/transfer_protocol.dart';
import '../state/app_state.dart';
import '../state/discovery_provider.dart';
import '../state/init_provider.dart';
import '../state/transfer_manager_provider.dart';
import '../state/trusted_devices_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Wire the incoming-request dialog as soon as the screen is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transferManagerProvider).onIncomingRequest = _showIncomingDialog;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Trigger one-time initialization (identity keys, trusted device loading).
    ref.watch(initProvider);
    ref.watch(loadTrustedDevicesProvider);

    // Watching keeps discovery alive while the screen is mounted.
    ref.watch(discoveryManagerProvider);
    // Watching starts the receive server immediately.
    ref.watch(transferManagerProvider);

    final appState = ref.watch(appStateProvider);
    final devices = appState.deviceState.discoveredDevices;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'MeshDrop',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: devices.isEmpty
          ? const _EmptyDiscoveryView()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return _DeviceCard(
                  device: device,
                  onTap: () => _onDeviceTapped(device),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF238636),
        onPressed: () => Navigator.pushNamed(context, '/transfers'),
        icon: const Icon(Icons.swap_horiz, color: Colors.white),
        label: const Text('Transfers', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // ── Send flow ─────────────────────────────────────────────────────────────

  Future<void> _onDeviceTapped(Device device) async {
    // 1. Open native file picker.
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a file to send to ${device.name}',
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    final file = File(path);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sending "${result.files.single.name}" to ${device.name}…'),
        backgroundColor: const Color(0xFF238636),
      ),
    );

    // 2. Send — FileTransferManager handles chunking, encryption, progress.
    final manager = ref.read(transferManagerProvider);
    try {
      await manager.sendFile(file, device);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed connecting to ${device.ipAddress}:\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Incoming request dialog ───────────────────────────────────────────────

  Future<bool> _showIncomingDialog(TransferRequest request) async {
    if (!mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Incoming file from ${request.senderName}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Row(
          children: [
            const Icon(Icons.insert_drive_file, color: Colors.white54, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.fileName,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.fileSizeLabel,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return accepted ?? false;
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _EmptyDiscoveryView extends StatelessWidget {
  const _EmptyDiscoveryView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_tethering,
              size: 80, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 24),
          const Text(
            'Looking for devices...',
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Make sure other devices have MeshDrop open\nand are on the same Wi-Fi network.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;

  const _DeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF161B22),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF238636),
          child:
              Icon(_platformIcon(device.platform.name), color: Colors.white),
        ),
        title: Text(device.name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${device.ipAddress}  •  ${device.platform.name}',
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: const Icon(Icons.send, color: Color(0xFF238636)),
        onTap: onTap,
      ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'ios':
        return Icons.phone_iphone;
      case 'android':
        return Icons.android;
      case 'windows':
        return Icons.window;
      case 'linux':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }
}
