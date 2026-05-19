// features/transfer/transfer_protocol.dart
// Defines the wire format for transfer request headers sent before any chunks.
// Both sender and receiver must use this exact format.
//
// Wire format for a transfer request:
//   [4 bytes: magic 0x4D534844 "MSHD"]
//   [4 bytes: device name length]
//   [N bytes: device name UTF-8]
//   [4 bytes: file name length]
//   [N bytes: file name UTF-8]
//   [8 bytes: file size int64 big-endian]
//
// The receiver responds with:
//   [1 byte: 0x01 = accepted, 0x00 = rejected]

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'socket_reader.dart';

class TransferProtocol {
  static const int _magic = 0x4D534844; // "MSHD"

  /// Writes a transfer request header to [socket].
  static Future<void> sendRequest(
    Socket socket, {
    required String senderName,
    required String fileName,
    required int fileSize,
    required Uint8List senderPublicKey,
  }) async {
    assert(senderPublicKey.length == 32, 'X25519 public key must be 32 bytes');
    final senderBytes = utf8.encode(senderName);
    final fileNameBytes = utf8.encode(fileName);

    final buffer = BytesBuilder();
    // Magic
    buffer.add(_int32Bytes(_magic));
    // Sender name
    buffer.add(_int32Bytes(senderBytes.length));
    buffer.add(senderBytes);
    // File name
    buffer.add(_int32Bytes(fileNameBytes.length));
    buffer.add(fileNameBytes);
    // File size
    buffer.add(_int64Bytes(fileSize));
    // Sender public key (32 bytes)
    buffer.add(senderPublicKey);

    socket.add(buffer.toBytes());
    await socket.flush();
  }

  /// Reads a transfer request header using an existing [reader].
  /// The caller must create and own the SocketReader so it can be
  /// reused for subsequent chunk reads without re-subscribing the stream.
  static Future<TransferRequest?> readRequest(SocketReader reader) async {
    try {
      // Magic
      final magic = _bytesToInt32(await reader.read(4));
      if (magic != _magic) return null;

      // Sender name
      final senderLen = _bytesToInt32(await reader.read(4));
      final senderName = utf8.decode(await reader.read(senderLen));

      // File name
      final fileNameLen = _bytesToInt32(await reader.read(4));
      final fileName = utf8.decode(await reader.read(fileNameLen));

      // File size
      final fileSize = _bytesToInt64(await reader.read(8));

      // Sender public key (32 bytes)
      final senderPublicKey = await reader.read(32);

      return TransferRequest(
        senderName: senderName,
        fileName: fileName,
        fileSize: fileSize,
        senderPublicKey: senderPublicKey,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sends the Accept response along with the receiver's X25519 public key.
  static void sendAccept(Socket socket, Uint8List receiverPublicKey) {
    assert(receiverPublicKey.length == 32, 'X25519 public key must be 32 bytes');
    final buffer = BytesBuilder();
    buffer.add([0x01]);
    buffer.add(receiverPublicKey);
    socket.add(buffer.toBytes());
  }

  /// Sends a rejection response.
  static void sendReject(Socket socket) => socket.add([0x00]);

  /// Reads the receiver's response.
  /// Returns the receiver's 32-byte public key if accepted, or null if rejected.
  static Future<Uint8List?> readResponse(SocketReader reader) async {
    try {
      final statusBytes = await reader.read(1);
      if (statusBytes[0] == 0x01) {
        final keyBytes = await reader.read(32);
        return Uint8List.fromList(keyBytes);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Uint8List _int32Bytes(int value) {
    final b = ByteData(4);
    b.setInt32(0, value, Endian.big);
    return b.buffer.asUint8List();
  }

  static Uint8List _int64Bytes(int value) {
    final b = ByteData(8);
    b.setInt64(0, value, Endian.big);
    return b.buffer.asUint8List();
  }

  static int _bytesToInt32(List<int> bytes) {
    return ByteData.sublistView(Uint8List.fromList(bytes)).getInt32(0, Endian.big);
  }

  static int _bytesToInt64(List<int> bytes) {
    return ByteData.sublistView(Uint8List.fromList(bytes)).getInt64(0, Endian.big);
  }
}

class TransferRequest {
  final String senderName;
  final String fileName;
  final int fileSize;
  final Uint8List senderPublicKey;

  const TransferRequest({
    required this.senderName,
    required this.fileName,
    required this.fileSize,
    required this.senderPublicKey,
  });

  String get fileSizeLabel {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

