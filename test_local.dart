import 'dart:io';

void main() async {
  try {
    final socket = await Socket.connect('127.0.0.1', 58432);
    print("Connected locally!");
    socket.destroy();
  } catch (e) {
    print("Error: $e");
  }
}
