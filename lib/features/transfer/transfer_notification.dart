// features/transfer/transfer_notification.dart
// Wraps flutter_local_notifications to show native OS transfer notifications.
// iOS gets a banner, Android gets a Material notification,
// Linux gets a libnotify popup.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class TransferNotification {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  TransferNotification() : _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings();
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> showProgress(
    String transferId,
    String fileName,
    double progress,
  ) async {
    try {
      await initialize();
      final percent = (progress * 100).toInt();
      final androidDetails = AndroidNotificationDetails(
        'meshdrop_transfer',
        'File Transfers',
        channelDescription: 'MeshDrop file transfer progress',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: 100,
        progress: percent,
        onlyAlertOnce: true,
      );
      final details = NotificationDetails(android: androidDetails);
      await _plugin.show(
        transferId.hashCode,
        'Sending $fileName',
        '$percent% complete',
        details,
      );
    } catch (e) {
      // Ignored on platforms without notification support
    }
  }

  Future<void> showCompleted(String transferId, String fileName) async {
    try {
      await initialize();
      const androidDetails = AndroidNotificationDetails(
        'meshdrop_transfer',
        'File Transfers',
        channelDescription: 'MeshDrop file transfer progress',
        importance: Importance.defaultImportance,
      );
      const details = NotificationDetails(android: androidDetails);
      await _plugin.show(
        transferId.hashCode,
        'Transfer complete',
        '$fileName received successfully',
        details,
      );
    } catch (e) {
      // Ignored
    }
  }

  Future<void> showFailed(String transferId, String error) async {
    try {
      await initialize();
      const androidDetails = AndroidNotificationDetails(
        'meshdrop_transfer',
        'File Transfers',
        channelDescription: 'MeshDrop file transfer progress',
        importance: Importance.high,
      );
      const details = NotificationDetails(android: androidDetails);
      await _plugin.show(
        transferId.hashCode,
        'Transfer failed',
        error,
        details,
      );
    } catch (e) {
      debugPrint('Notification failed: $e');
    }
  }

  Future<void> dismiss(String transferId) async {
    await _plugin.cancel(transferId.hashCode);
  }
}
