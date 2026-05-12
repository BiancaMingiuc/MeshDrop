// features/pairing/trusted_device.dart
// A device that has completed the pairing handshake and is stored
// in SecureStorage so trust survives app restarts.

import 'dart:typed_data';
import 'dart:convert';

class TrustedDevice {
  final String deviceId;
  final String deviceName;
  final Uint8List publicKey;
  final DateTime pairingDate;
  DateTime lastSeen;
  final Map<String, dynamic> sessionMetadata;
  bool isVerified;

  TrustedDevice({
    required this.deviceId,
    required this.deviceName,
    required this.publicKey,
    required this.pairingDate,
    required this.lastSeen,
    this.sessionMetadata = const {},
    this.isVerified = true,
  });

  /// Stamps the current time as the last time this device was seen online.
  void updateLastSeen() => lastSeen = DateTime.now();

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'publicKey': base64Encode(publicKey),
        'pairingDate': pairingDate.toIso8601String(),
        'lastSeen': lastSeen.toIso8601String(),
        'sessionMetadata': sessionMetadata,
        'isVerified': isVerified,
      };

  factory TrustedDevice.fromJson(Map<String, dynamic> json) => TrustedDevice(
        deviceId: json['deviceId'] as String,
        deviceName: json['deviceName'] as String,
        publicKey: base64Decode(json['publicKey'] as String),
        pairingDate: DateTime.parse(json['pairingDate'] as String),
        lastSeen: DateTime.parse(json['lastSeen'] as String),
        sessionMetadata:
            Map<String, dynamic>.from(json['sessionMetadata'] as Map),
        isVerified: json['isVerified'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrustedDevice && other.deviceId == deviceId);

  @override
  int get hashCode => deviceId.hashCode;
}
