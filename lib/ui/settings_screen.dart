// ui/settings_screen.dart
// User preferences: download directory, chunk size, auto-accept, clear trust.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';





class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

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
            subtitle: 'Where received files are saved',
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => setDownloadDirectory(context),
          ),
          _switchTile(
            icon: Icons.download_done,
            title: 'Auto-Accept',
            subtitle: 'Accept incoming transfers without prompting',
            value: false, // TODO: bind to AppSettings.autoAccept
            onChanged: (v) => setAutoAccept(v),
          ),
          _tile(
            icon: Icons.memory,
            title: 'Chunk Size',
            subtitle: '64 KB (default)',
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => setChunkSize(context),
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
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38)),
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

  void setDownloadDirectory(BuildContext context) {
    // TODO: Open platform file picker for directory selection.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Directory picker coming soon')),
    );
  }

  void setAutoAccept(bool enabled) {
    // TODO: Persist to AppSettings.
  }

  void setChunkSize(BuildContext context) {
    // TODO: Show dialog with chunk size options.
  }

  void clearTrustedDevices(WidgetRef ref) {
    // TODO: Also delete from SecureStorage.
    // For now, clear state only.
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
              clearTrustedDevices(ref);
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
