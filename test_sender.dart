import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

void main() async {
  try {
    print("Connecting...");
    final socket = await Socket.connect('127.0.0.1', 58432);
    print("Connected!");
    
    // Simulate Request Header
    final senderBytes = utf8.encode("TestSender");
    final fileNameBytes = utf8.encode("test.txt");

    final buffer = BytesBuilder();
    buffer.add(_int32Bytes(0x4D534844)); // Magic MSHD
    buffer.add(_int32Bytes(senderBytes.length));
    buffer.add(senderBytes);
    buffer.add(_int32Bytes(fileNameBytes.length));
    buffer.add(fileNameBytes);
    buffer.add(_int64Bytes(1024)); // File size
    buffer.add(Uint8List(32)); // Fake 32-byte public key
    
    socket.add(buffer.toBytes());
    await socket.flush();
    print("Sent request. Waiting for response...");

    // Wait for Accept
    final responseBytes = await _readExactly(socket, 1);
    if (responseBytes[0] == 0x01) {
       print("Accepted!");
       final keyBytes = await _readExactly(socket, 32);
       print("Got public key.");
       
       // Now wait for pairing byte
       final pairingByte = await _readExactly(socket, 1);
       print("Pairing byte: \${pairingByte[0]}");
    } else {
       print("Rejected.");
    }
    socket.destroy();
  } catch (e) {
    print("Error: $e");
  }
}

List<int> _int32Bytes(int value) {
  final bytes = ByteData(4);
  bytes.setInt32(0, value, Endian.big);
  return bytes.buffer.asUint8List();
}

List<int> _int64Bytes(int value) {
  final bytes = ByteData(8);
  bytes.setInt64(0, value, Endian.big);
  return bytes.buffer.asUint8List();
}

Future<Uint8List> _readExactly(Socket socket, int count) async {
  final completer = Completer<Uint8List>();
  final buffer = BytesBuilder();
  late StreamSubscription sub;
  
  sub = socket.listen((data) {
    buffer.add(data);
    if (buffer.length >= count) {
      sub.cancel();
      completer.complete(buffer.toBytes());
    }
  }, onError: completer.completeError, onDone: () {
    if (!completer.isCompleted) completer.completeError("Socket closed prematurely");
  });
  
  return completer.future;
}
