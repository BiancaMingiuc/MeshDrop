// features/transfer/socket_reader.dart
// Buffered byte reader over a TCP socket stream.
// Shared by TransferProtocol (header parsing) and FileTransferManager (chunk reading).

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class SocketReader {
  final List<int> _buffer = [];
  final StreamIterator<Uint8List> _iter;

  SocketReader(Socket socket) : _iter = StreamIterator(socket.cast<Uint8List>());

  /// Reads exactly [count] bytes from the socket, buffering as needed.
  /// Throws [StateError] if the socket closes before enough bytes arrive.
  Future<Uint8List> read(int count) async {
    while (_buffer.length < count) {
      if (!await _iter.moveNext()) throw StateError('Socket closed');
      _buffer.addAll(_iter.current);
    }
    final result = Uint8List.fromList(_buffer.sublist(0, count));
    _buffer.removeRange(0, count);
    return result;
  }
}
