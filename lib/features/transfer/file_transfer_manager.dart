// features/transfer/file_transfer_manager.dart  (Phase 2 — full implementation)
// Orchestrates send + receive over TCP sockets.
//
// SEND flow:
//   1. Open socket to target device IP:port
//   2. Send TransferProtocol header (sender name, file name, file size)
//   3. Wait for Accept/Reject byte
//   4. If accepted: chunk → encrypt → send each chunk preceded by 4-byte length
//   5. Update progress → Riverpod → UI + OS notification
//
// RECEIVE flow:
//   ServerSocket listens on port 58432.
//   For each incoming connection:
//   1. Read TransferProtocol header
//   2. Fire onIncomingRequest callback → UI shows Accept/Reject dialog
//   3. If accepted: read length-prefixed encrypted chunks, decrypt, validate, reassemble
//   4. Save file to download directory (auto-rename if name conflict)

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../discovery/device_discovery_manager.dart';
import '../discovery/models/device.dart';
import '../discovery/models/platform_type.dart';
import '../encryption/crypto_manager.dart';
import '../encryption/encryption_session.dart';
import '../pairing/trusted_device.dart';
import 'models/file_chunk.dart';
import 'models/transfer_entry.dart';
import 'models/transfer_status.dart';
import 'socket_reader.dart';
import 'transfer_notification.dart';
import 'transfer_protocol.dart';
import 'transfer_queue.dart';

class FileTransferManager {
  static const int _port = 58432;
  static const int _chunkSize = 65536; // 64 KB

  final DeviceDiscoveryManager _discoveryManager;
  final CryptoManager _cryptoManager;
  final TransferQueue _transferQueue;
  final TransferNotification _notification;
  final String _localDeviceName;
  final String? _downloadDirectory;

  ServerSocket? _serverSocket;
  final Set<String> _paused = {};
  final _uuid = const Uuid();

  /// Fired when a transfer entry changes (progress, status). Wire to Riverpod.
  void Function(TransferEntry entry)? onTransferUpdated;

  /// Fired when another device wants to send us a file.
  /// The callback receives the request and must return true (accept) or false (reject).
  Future<bool> Function(TransferRequest request)? onIncomingRequest;

  /// Looks up a TrustedDevice by its device ID to retrieve its public key
  /// for ECDH key derivation. Injected by the provider layer.
  TrustedDevice? Function(String deviceId)? lookupTrustedDevice;

  FileTransferManager({
    required DeviceDiscoveryManager discoveryManager,
    required CryptoManager cryptoManager,
    required TransferNotification notification,
    required String localDeviceName,
    String? downloadDirectory,
  })  : _discoveryManager = discoveryManager,
        _cryptoManager = cryptoManager,
        _notification = notification,
        _localDeviceName = localDeviceName,
        _downloadDirectory = downloadDirectory,
        _transferQueue = TransferQueue();

  // ── Receive Server ────────────────────────────────────────────────────────

  Future<void> startReceiveServer() async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, _port);
    _serverSocket!.listen(_handleIncomingConnection);
  }

  Future<void> stopReceiveServer() async {
    await _serverSocket?.close();
    _serverSocket = null;
  }

  Future<void> _handleIncomingConnection(Socket socket) async {
    // Create the SocketReader ONCE. It subscribes to the socket stream exactly
    // one time — passing it to readRequest and then to _receiveChunks prevents
    // the fatal "Stream has already been listened to" StateError.
    final reader = SocketReader(socket);
    try {
      // 1. Read the transfer request header.
      final request = await TransferProtocol.readRequest(reader);
      if (request == null) {
        socket.destroy();
        return;
      }

      // 2. Ask the UI whether to accept.
      final accepted = await (onIncomingRequest?.call(request) ?? Future.value(false));
      if (!accepted) {
        TransferProtocol.sendReject(socket);
        await socket.flush();
        socket.destroy();
        return;
      }
      TransferProtocol.sendAccept(socket);
      await socket.flush();

      // 3. Receive all chunks, streaming directly to disk.
      final transferId = _uuid.v4();
      final entry = TransferEntry(
        transferId: transferId,
        fileName: request.fileName,
        fileSize: request.fileSize,
        targetDevice: Device(
          id: request.senderName,
          name: request.senderName,
          ipAddress: socket.remoteAddress.address,
          port: _port,
          platform: _discoveryManager
              .getDiscoveredDevices()
              .firstWhere(
                (d) => d.name == request.senderName,
                orElse: () => Device(
                  id: request.senderName,
                  name: request.senderName,
                  ipAddress: socket.remoteAddress.address,
                  port: _port,
                  platform: PlatformType.unknown,
                ),
              )
              .platform,
        ),
        status: TransferStatus.inProgress,
      );
      _transferQueue.enqueue(entry);
      onTransferUpdated?.call(entry);

      final session = await _cryptoManager.createSession(request.sessionKey);

      // Open the destination file for streaming writes.
      final destPath = await _resolveDestPath(request.fileName);
      final sink = File(destPath).openWrite();
      try {
        await _receiveChunks(reader, sink, request.fileSize, transferId, session);
      } finally {
        await sink.flush();
        await sink.close();
      }

      _transferQueue.updateStatus(transferId, TransferStatus.completed);
      final done = entry.copyWith(
        status: TransferStatus.completed,
        progress: 1.0,
        completedAt: DateTime.now(),
      );
      onTransferUpdated?.call(done);
      await _notification.showCompleted(transferId, request.fileName);
      session.invalidate();
    } catch (e) {
      await _notification.showFailed('recv', e.toString());
    } finally {
      socket.destroy();
    }
  }

  Future<void> _receiveChunks(
    SocketReader reader,
    IOSink sink,
    int totalSize,
    String transferId,
    EncryptionSession session,
  ) async {
    int received = 0;

    while (received < totalSize) {
      // Read 4-byte length prefix.
      final lenBytes = await reader.read(4);
      final chunkLen =
          ByteData.sublistView(Uint8List.fromList(lenBytes)).getInt32(0, Endian.big);

      // Read encrypted chunk.
      final encrypted = await reader.read(chunkLen);

      // Decrypt and write directly to disk — no in-memory accumulation.
      final decrypted = await _cryptoManager.decrypt(Uint8List.fromList(encrypted), session);
      sink.add(decrypted);

      received += decrypted.length;

      final progress = received / totalSize;
      _transferQueue.updateProgress(transferId, progress);
      final updated = _transferQueue.getById(transferId)!;
      onTransferUpdated?.call(updated);
      await _notification.showProgress(transferId, updated.fileName, progress);
    }
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  Future<void> sendFile(File file, Device target) async {
    final fileName = p.basename(file.path);
    final fileSize = await file.length();
    final transferId = _uuid.v4();

    final entry = TransferEntry(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      targetDevice: target,
      status: TransferStatus.inProgress,
    );
    _transferQueue.enqueue(entry);
    onTransferUpdated?.call(entry);

    try {
      final socket = await Socket.connect(target.ipAddress, _port, timeout: const Duration(seconds: 5));

      // 0. Generate a random session key for this transfer.
      final sessionKey = _generateRandomKey();

      // 1. Send transfer request header.
      await TransferProtocol.sendRequest(
        socket,
        senderName: _localDeviceName,
        fileName: fileName,
        fileSize: fileSize,
        sessionKey: sessionKey,
      );

      // 2. Wait for accept / reject.
      // Create the reader ONCE here so the same stream subscription is used
      // for readResponse and any future reads on this socket.
      final senderReader = SocketReader(socket);
      final accepted = await TransferProtocol.readResponse(senderReader);
      if (!accepted) {
        socket.destroy();
        _transferQueue.updateStatus(transferId, TransferStatus.cancelled);
        onTransferUpdated?.call(_transferQueue.getById(transferId)!);
        return;
      }

      // 3. Chunk, encrypt, send.
      final session = await _cryptoManager.createSession(sessionKey);
      final chunks = await _chunkFile(file, transferId);

      for (int i = 0; i < chunks.length; i++) {
        if (_paused.contains(transferId)) {
          _transferQueue.updateStatus(transferId, TransferStatus.paused);
          onTransferUpdated?.call(_transferQueue.getById(transferId)!);
          while (_paused.contains(transferId)) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          _transferQueue.updateStatus(transferId, TransferStatus.inProgress);
        }

        final encrypted = await _cryptoManager.encrypt(chunks[i].data, session);

        // Send 4-byte length prefix then encrypted data.
        final lenBytes = ByteData(4);
        lenBytes.setInt32(0, encrypted.length, Endian.big);
        socket.add(lenBytes.buffer.asUint8List());
        socket.add(encrypted);

        final progress = (i + 1) / chunks.length;
        _transferQueue.updateProgress(transferId, progress);
        onTransferUpdated?.call(_transferQueue.getById(transferId)!);
        await _notification.showProgress(transferId, fileName, progress);
      }

      await socket.flush();
      socket.destroy();
      session.invalidate();

      _transferQueue.updateStatus(transferId, TransferStatus.completed);
      final done = _transferQueue.getById(transferId)!.copyWith(
        status: TransferStatus.completed,
        completedAt: DateTime.now(),
      );
      onTransferUpdated?.call(done);
      await _notification.showCompleted(transferId, fileName);
    } catch (e) {
      _transferQueue.updateStatus(transferId, TransferStatus.failed);
      onTransferUpdated?.call(_transferQueue.getById(transferId)!);
      await _notification.showFailed(transferId, e.toString());
    }
  }

  // ── Control ───────────────────────────────────────────────────────────────

  void pauseTransfer(String transferId) => _paused.add(transferId);
  void resumeTransfer(String transferId) => _paused.remove(transferId);

  void cancelTransfer(String transferId) {
    _paused.remove(transferId);
    _transferQueue.updateStatus(transferId, TransferStatus.cancelled);
    final entry = _transferQueue.getById(transferId);
    if (entry != null) onTransferUpdated?.call(entry);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Generates a cryptographically secure random 32-byte key.
  static Uint8List _generateRandomKey() {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => rng.nextInt(256)),
    );
  }

  Future<List<FileChunk>> _chunkFile(File file, String transferId) async {
    final bytes = await file.readAsBytes();
    final chunks = <FileChunk>[];
    int offset = 0;
    int id = 0;
    while (offset < bytes.length) {
      final end = (offset + _chunkSize).clamp(0, bytes.length);
      final slice = bytes.sublist(offset, end);
      chunks.add(FileChunk.create(
        chunkId: id++,
        transferId: transferId,
        data: slice,
        offset: offset,
        isLast: end == bytes.length,
      ));
      offset = end;
    }
    return chunks;
  }


  /// Returns a destination path that doesn't conflict with existing files.
  /// Uses the user-configured download directory, falling back to the
  /// system documents directory if none is set or the path doesn't exist.
  Future<String> _resolveDestPath(String fileName) async {
    String dirPath;
    if (_downloadDirectory != null &&
        _downloadDirectory.isNotEmpty &&
        await Directory(_downloadDirectory).exists()) {
      dirPath = _downloadDirectory;
    } else {
      dirPath = (await getApplicationDocumentsDirectory()).path;
    }
    String dest = p.join(dirPath, fileName);
    int counter = 1;
    final ext = p.extension(fileName);
    final base = p.basenameWithoutExtension(fileName);
    while (await File(dest).exists()) {
      dest = p.join(dirPath, '$base ($counter)$ext');
      counter++;
    }
    return dest;
  }
}
