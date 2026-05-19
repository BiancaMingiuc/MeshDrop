// state/transfer_manager_provider.dart
// Riverpod provider that owns FileTransferManager, starts the TCP receive
// server, and wires progress updates into TransferStateNotifier.

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/transfer/file_transfer_manager.dart';
import '../features/transfer/transfer_notification.dart';
import 'app_settings_provider.dart';
import 'device_state.dart';
import 'discovery_provider.dart';
import 'init_provider.dart';
import 'transfer_state.dart';

final transferManagerProvider = Provider<FileTransferManager>((ref) {
  final discoveryManager = ref.watch(discoveryManagerProvider);
  final cryptoManager = ref.watch(cryptoManagerProvider);
  final notification = TransferNotification();
  final manager = FileTransferManager(
    discoveryManager: discoveryManager,
    cryptoManager: cryptoManager,
    notification: notification,
    localDeviceName: Platform.localHostname,
    downloadDirectory: ref.read(appSettingsProvider).downloadDirectory,
  );

  // Update download directory dynamically without restarting the server.
  ref.listen(appSettingsProvider, (previous, next) {
    manager.downloadDirectory = next.downloadDirectory;
  });

  // Wire transfer updates into Riverpod state.
  manager.onTransferUpdated = (entry) {
    ref.read(transferStateProvider.notifier).onTransferUpdated(entry);
  };

  // Wire trusted device lookup for ECDH key derivation.
  manager.lookupTrustedDevice = (deviceId) {
    final paired = ref.read(deviceStateProvider).pairedDevices;
    try {
      return paired.firstWhere((d) => d.deviceId == deviceId);
    } catch (_) {
      return null;
    }
  };

  // Start the TCP receive server in the background.
  manager.startReceiveServer().catchError((e) {
    // Port may already be in use on restart — log and continue.
  });

  ref.onDispose(() => manager.stopReceiveServer());

  return manager;
});
