// features/transfer/transfer_queue.dart
// Manages the ordered list of pending and active transfers.
// Composed inside FileTransferManager (lifecycle-bound).

import 'models/transfer_entry.dart';
import 'models/transfer_status.dart';

class TransferQueue {
  final List<TransferEntry> _queue = [];

  void enqueue(TransferEntry entry) => _queue.add(entry);

  TransferEntry? dequeue() {
    final pending = _queue.where((e) => e.status == TransferStatus.queued).toList();
    if (pending.isEmpty) return null;
    return pending.first;
  }

  List<TransferEntry> getActive() =>
      _queue.where((e) => e.status == TransferStatus.inProgress).toList();

  List<TransferEntry> getByStatus(TransferStatus status) =>
      _queue.where((e) => e.status == status).toList();

  void updateStatus(String transferId, TransferStatus status) {
    final idx = _queue.indexWhere((e) => e.transferId == transferId);
    if (idx == -1) return;
    _queue[idx] = _queue[idx].copyWith(status: status);
  }

  void updateProgress(String transferId, double progress) {
    final idx = _queue.indexWhere((e) => e.transferId == transferId);
    if (idx == -1) return;
    _queue[idx] = _queue[idx].copyWith(progress: progress);
  }

  TransferEntry? getById(String transferId) {
    try {
      return _queue.firstWhere((e) => e.transferId == transferId);
    } catch (_) {
      return null;
    }
  }

  List<TransferEntry> getAll() => List.unmodifiable(_queue);

  void clear() => _queue.clear();
}
