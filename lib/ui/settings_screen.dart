// ui/settings_screen.dart
// User preferences: download directory, chunk size, auto-accept, clear trust.
// All settings are persisted via AppSettingsNotifier → SharedPreferences.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_settings_provider.dart';
import '../state/device_state.dart';
import '../state/init_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        children: [
          _tile(
            icon: Icons.folder_open,
            title: 'Download Directory',
            subtitle: settings.downloadDirectory,
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => _setDownloadDirectory(context, ref),
          ),
          _switchTile(
            icon: Icons.download_done,
            title: 'Auto-Accept',
            subtitle: 'Accept incoming transfers without prompting',
            value: settings.autoAccept,
            onChanged: (v) => _setAutoAccept(ref, v),
          ),
          _tile(
            icon: Icons.memory,
            title: 'Chunk Size',
            subtitle: _chunkSizeLabel(settings.chunkSizeBytes),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => _setChunkSize(context, ref),
          ),
          const Divider(color: Colors.white12, height: 32),
          _tile(
            icon: Icons.no_encryption_gmailerrorred,
            title: 'Clear Trusted Devices',
            subtitle: 'Remove all paired device records',
            titleColor: Colors.red,
            onTap: () => _confirmClearTrusted(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white54),
      title: Text(title,
          style: TextStyle(color: titleColor ?? Colors.white, fontSize: 15)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.white38),
          overflow: TextOverflow.ellipsis),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white54),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38)),
      trailing: Switch(
        value: value,
        activeThumbColor: const Color(0xFF238636),
        onChanged: onChanged,
      ),
    );
  }

  // ── Action Handlers ────────────────────────────────────────────────────────

  Future<void> _setDownloadDirectory(BuildContext context, WidgetRef ref) async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose download directory',
    );
    if (path == null) return;
    await ref.read(appSettingsProvider.notifier).update(downloadDirectory: path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download directory set to $path'),
          backgroundColor: const Color(0xFF238636),
        ),
      );
    }
  }

  Future<void> _setAutoAccept(WidgetRef ref, bool enabled) async {
    await ref.read(appSettingsProvider.notifier).update(autoAccept: enabled);
  }

  Future<void> _setChunkSize(BuildContext context, WidgetRef ref) async {
    final options = {
      '32 KB': 32768,
      '64 KB (default)': 65536,
      '128 KB': 131072,
      '256 KB': 262144,
    };

    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Chunk Size', style: TextStyle(color: Colors.white)),
        children: options.entries
            .map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, e.value),
                  child: Text(e.key, style: const TextStyle(color: Colors.white70)),
                ))
            .toList(),
      ),
    );

    if (selected != null) {
      await ref.read(appSettingsProvider.notifier).update(chunkSizeBytes: selected);
    }
  }

  Future<void> _clearTrustedDevices(WidgetRef ref) async {
    // Clear from SecureStorage.
    final secureStorage = ref.read(secureStorageProvider);
    final pairedDevices = ref.read(deviceStateProvider).pairedDevices;
    for (final device in pairedDevices) {
      await secureStorage.delete(key: 'trusted_${device.deviceId}');
    }
    // Clear from Riverpod state.
    for (final device in pairedDevices) {
      ref.read(deviceStateProvider.notifier).removePaired(device.deviceId);
    }
  }

  void _confirmClearTrusted(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Clear trusted devices?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'All paired devices will need to pair again.',
          style: TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              _clearTrustedDevices(ref);
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _chunkSizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    return '${bytes ~/ 1024} KB';
  }
}
