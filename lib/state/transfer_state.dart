// state/transfer_state.dart
// Riverpod state for active and completed file transfers.
// Completed transfers are persisted to SharedPreferences so they
// survive app restarts.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/discovery/models/device.dart';
import '../features/transfer/models/transfer_entry.dart';
import '../features/transfer/models/transfer_status.dart';

class TransferState {
  final List<TransferEntry> activeTransfers;
  final List<TransferEntry> completedTransfers;
  final double currentProgress;
  final TransferStatus status;

  const TransferState({
    this.activeTransfers = const [],
    this.completedTransfers = const [],
    this.currentProgress = 0.0,
    this.status = TransferStatus.queued,
  });

  TransferState copyWith({
    List<TransferEntry>? activeTransfers,
    List<TransferEntry>? completedTransfers,
    double? currentProgress,
    TransferStatus? status,
  }) {
    return TransferState(
      activeTransfers: activeTransfers ?? this.activeTransfers,
      completedTransfers: completedTransfers ?? this.completedTransfers,
      currentProgress: currentProgress ?? this.currentProgress,
      status: status ?? this.status,
    );
  }
}

class TransferStateNotifier extends StateNotifier<TransferState> {
  static const _historyKey = 'meshdrop_transfer_history';

  TransferStateNotifier() : super(const TransferState()) {
    _loadHistory();
  }

  void addTransfer(TransferEntry entry) {
    state = state.copyWith(
      activeTransfers: [...state.activeTransfers, entry],
      status: TransferStatus.inProgress,
    );
  }

  void updateEntry(TransferEntry newEntry) {
    final updated = state.activeTransfers.map((e) {
      return e.transferId == newEntry.transferId ? newEntry : e;
    }).toList();
    state = state.copyWith(
      activeTransfers: updated,
      currentProgress: newEntry.progress,
    );
  }

  void removeTransfer(String transferId) {
    final entry = state.activeTransfers
        .where((e) => e.transferId == transferId)
        .firstOrNull;
    if (entry == null) return;

    final remaining =
        state.activeTransfers.where((e) => e.transferId != transferId).toList();

    if (entry.status == TransferStatus.completed ||
        entry.status == TransferStatus.failed ||
        entry.status == TransferStatus.cancelled) {
      // Add all finished states to history so user can see failures/cancellations too.
      final updated = [...state.completedTransfers, entry];
      state = state.copyWith(
        activeTransfers: remaining,
        completedTransfers: updated,
        status: entry.status,
      );
      _persistHistory(updated);
    } else {
      state = state.copyWith(activeTransfers: remaining);
    }
  }

  void onTransferUpdated(TransferEntry entry) {
    final inActive = state.activeTransfers.any((e) => e.transferId == entry.transferId);
    if (inActive) {
      updateEntry(entry);
      if (entry.status == TransferStatus.completed ||
          entry.status == TransferStatus.failed ||
          entry.status == TransferStatus.cancelled) {
        removeTransfer(entry.transferId);
      }
    } else {
      addTransfer(entry);
    }
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null) return;

      final list = jsonDecode(raw) as List;
      final entries = list
          .map((e) => _entryFromJson(e as Map<String, dynamic>))
          .whereType<TransferEntry>()
          .toList();

      state = state.copyWith(completedTransfers: entries);
    } catch (_) {
      // Corrupted data — start with empty history.
    }
  }

  Future<void> _persistHistory(List<TransferEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = entries.map((e) => _entryToJson(e)).toList();
      await prefs.setString(_historyKey, jsonEncode(json));
    } catch (_) {
      // Best-effort persistence.
    }
  }

  /// Serializes a TransferEntry for SharedPreferences storage.
  static Map<String, dynamic> _entryToJson(TransferEntry entry) => {
        'transferId': entry.transferId,
        'fileName': entry.fileName,
        'fileSize': entry.fileSize,
        'status': entry.status.name,
        'progress': entry.progress,
        'startedAt': entry.startedAt.toIso8601String(),
        'completedAt': entry.completedAt?.toIso8601String(),
        'targetDevice': entry.targetDevice.toJson(),
      };

  /// Deserializes a TransferEntry from SharedPreferences storage.
  static TransferEntry? _entryFromJson(Map<String, dynamic> json) {
    try {
      return TransferEntry(
        transferId: json['transferId'] as String,
        fileName: json['fileName'] as String,
        fileSize: json['fileSize'] as int,
        status: TransferStatus.values.byName(json['status'] as String),
        progress: (json['progress'] as num).toDouble(),
        startedAt: DateTime.parse(json['startedAt'] as String),
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        targetDevice: Device.fromJson(json['targetDevice'] as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }
}

final transferStateProvider =
    StateNotifierProvider<TransferStateNotifier, TransferState>(
  (ref) => TransferStateNotifier(),
);
