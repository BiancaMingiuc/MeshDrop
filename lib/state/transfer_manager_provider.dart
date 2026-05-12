// state/transfer_manager_provider.dart
// Riverpod provider that owns FileTransferManager, starts the TCP receive
// server, and wires progress updates into TransferStateNotifier.

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../features/encryption/crypto_manager.dart';
import '../features/transfer/file_transfer_manager.dart';
import '../features/transfer/transfer_notification.dart';
import 'discovery_provider.dart';
import 'transfer_state.dart';

final transferManagerProvider = Provider<FileTransferManager>((ref) {
  final discoveryManager = ref.watch(discoveryManagerProvider);
  final cryptoManager = CryptoManager();
  final notification = TransferNotification();

  final manager = FileTransferManager(
    discoveryManager: discoveryManager,
    cryptoManager: cryptoManager,
    notification: notification,
    localDeviceName: Platform.localHostname,
  );

  // Wire transfer updates into Riverpod state.
  manager.onTransferUpdated = (entry) {
    ref.read(transferStateProvider.notifier).onTransferUpdated(entry);
  };

  // Start the TCP receive server in the background.
  manager.startReceiveServer().catchError((e) {
    // Port may already be in use on restart — log and continue.
  });

  ref.onDispose(() => manager.stopReceiveServer());

  return manager;
});
