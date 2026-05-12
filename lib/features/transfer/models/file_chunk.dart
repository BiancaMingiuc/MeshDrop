// features/transfer/models/file_chunk.dart
// One unit of a chunked file transfer. Each chunk is encrypted independently
// and carries its own integrity checksum.

import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

class FileChunk {
  final int chunkId;
  final String transferId;
  final Uint8List data;
  final int offset;
  final int size;
  final String checksum; // SHA-256 hex of raw (pre-encryption) data
  final bool isLast;

  const FileChunk({
    required this.chunkId,
    required this.transferId,
    required this.data,
    required this.offset,
    required this.size,
    required this.checksum,
    required this.isLast,
  });

  /// Recomputes the SHA-256 of [data] and checks it against [checksum].
  bool validate() {
    final digest = crypto.sha256.convert(data);
    return digest.toString() == checksum;
  }

  /// Builds a FileChunk and automatically computes its checksum.
  factory FileChunk.create({
    required int chunkId,
    required String transferId,
    required Uint8List data,
    required int offset,
    required bool isLast,
  }) {
    final checksum = crypto.sha256.convert(data).toString();
    return FileChunk(
      chunkId: chunkId,
      transferId: transferId,
      data: data,
      offset: offset,
      size: data.length,
      checksum: checksum,
      isLast: isLast,
    );
  }
}
