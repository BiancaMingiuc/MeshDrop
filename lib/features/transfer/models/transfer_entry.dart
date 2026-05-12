// features/transfer/models/transfer_entry.dart
// Represents one file transfer (send or receive) in the TransferQueue.

import '../../discovery/models/device.dart';
import 'transfer_status.dart';

class TransferEntry {
  final String transferId;
  final String fileName;
  final int fileSize;
  TransferStatus status;
  double progress; // 0.0 – 1.0
  final Device targetDevice;
  final DateTime startedAt;
  DateTime? completedAt;

  TransferEntry({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.targetDevice,
    this.status = TransferStatus.queued,
    this.progress = 0.0,
    DateTime? startedAt,
    this.completedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  TransferEntry copyWith({
    TransferStatus? status,
    double? progress,
    DateTime? completedAt,
  }) {
    return TransferEntry(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      targetDevice: targetDevice,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Human-readable file size (e.g. "2.4 MB").
  String get fileSizeLabel {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransferEntry && other.transferId == transferId);

  @override
  int get hashCode => transferId.hashCode;
}
