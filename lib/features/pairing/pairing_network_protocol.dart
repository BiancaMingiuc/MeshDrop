// features/pairing/pairing_network_protocol.dart
// Wire protocol for the X25519 key exchange during device pairing.
//
// Wire format (both directions):
//   [4 bytes: magic 0x4D534850 "MSHP" (MeshDrop Pairing)]
//   [4 bytes: public key length (big-endian)]
//   [N bytes: X25519 public key]
//
// The initiator sends first, then reads the response.
// The receiver reads first, then sends its own key.

import 'dart:io';
import 'dart:typed_data';

import '../transfer/socket_reader.dart';

class PairingNetworkProtocol {
  static const int _magic = 0x4D534850; // "MSHP"

  /// Sends our X25519 public key to the remote device.
  static Future<void> sendPublicKey(Socket socket, Uint8List publicKey) async {
    final buffer = BytesBuilder();
    buffer.add(_int32Bytes(_magic));
    buffer.add(_int32Bytes(publicKey.length));
    buffer.add(publicKey);
    socket.add(buffer.toBytes());
    await socket.flush();
  }

  /// Reads the remote device's X25519 public key from the socket.
  /// Returns null if the magic bytes don't match (not a pairing message).
  static Future<Uint8List?> readPublicKey(Socket socket) async {
    try {
      final reader = SocketReader(socket);
      final magic = _bytesToInt32(await reader.read(4));
      if (magic != _magic) return null;

      final keyLen = _bytesToInt32(await reader.read(4));
      if (keyLen <= 0 || keyLen > 256) return null; // sanity check
      return await reader.read(keyLen);
    } catch (_) {
      return null;
    }
  }

  static Uint8List _int32Bytes(int value) {
    final b = ByteData(4);
    b.setInt32(0, value, Endian.big);
    return b.buffer.asUint8List();
  }

  static int _bytesToInt32(List<int> bytes) {
    return ByteData.sublistView(Uint8List.fromList(bytes))
        .getInt32(0, Endian.big);
  }
}
