// state/transfer_state.dart
// Riverpod state for active and completed file transfers.

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  TransferStateNotifier() : super(const TransferState());

  void addTransfer(TransferEntry entry) {
    state = state.copyWith(
      activeTransfers: [...state.activeTransfers, entry],
      status: TransferStatus.inProgress,
    );
  }

  void updateProgress(String transferId, double progress) {
    final updated = state.activeTransfers.map((e) {
      return e.transferId == transferId ? e.copyWith(progress: progress) : e;
    }).toList();
    state = state.copyWith(
      activeTransfers: updated,
      currentProgress: progress,
    );
  }

  void removeTransfer(String transferId) {
    final entry = state.activeTransfers
        .where((e) => e.transferId == transferId)
        .firstOrNull;
    if (entry == null) return;

    final remaining =
        state.activeTransfers.where((e) => e.transferId != transferId).toList();

    if (entry.status == TransferStatus.completed) {
      state = state.copyWith(
        activeTransfers: remaining,
        completedTransfers: [...state.completedTransfers, entry],
        status: TransferStatus.completed,
      );
    } else {
      state = state.copyWith(activeTransfers: remaining);
    }
  }

  void onTransferUpdated(TransferEntry entry) {
    final inActive = state.activeTransfers.any((e) => e.transferId == entry.transferId);
    if (inActive) {
      updateProgress(entry.transferId, entry.progress);
      if (entry.status == TransferStatus.completed ||
          entry.status == TransferStatus.failed ||
          entry.status == TransferStatus.cancelled) {
        removeTransfer(entry.transferId);
      }
    } else {
      addTransfer(entry);
    }
  }
}

final transferStateProvider =
    StateNotifierProvider<TransferStateNotifier, TransferState>(
  (ref) => TransferStateNotifier(),
);
