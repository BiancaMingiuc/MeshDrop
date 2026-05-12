// features/discovery/models/device.dart
// Represents a peer device discovered on the local network.

import 'platform_type.dart';

class Device {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final PlatformType platform;

  const Device({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.platform,
  });

  Device copyWith({
    String? id,
    String? name,
    String? ipAddress,
    int? port,
    PlatformType? platform,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      platform: platform ?? this.platform,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ipAddress': ipAddress,
        'port': port,
        'platform': platform.name,
      };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as String,
        name: json['name'] as String,
        ipAddress: json['ipAddress'] as String,
        port: json['port'] as int,
        platform: PlatformType.values.byName(json['platform'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Device && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Device($name @ $ipAddress:$port [$platform])';
}
