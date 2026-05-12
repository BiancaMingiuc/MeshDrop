// state/device_state.dart
// Riverpod state for discovered and paired devices.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/discovery/models/device.dart';
import '../features/pairing/trusted_device.dart';

enum DeviceConnectionStatus { discovered, paired, untrusted, offline }

class DeviceState {
  final List<Device> discoveredDevices;
  final List<TrustedDevice> pairedDevices;
  final DeviceConnectionStatus status;

  const DeviceState({
    this.discoveredDevices = const [],
    this.pairedDevices = const [],
    this.status = DeviceConnectionStatus.offline,
  });

  DeviceState copyWith({
    List<Device>? discoveredDevices,
    List<TrustedDevice>? pairedDevices,
    DeviceConnectionStatus? status,
  }) {
    return DeviceState(
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      pairedDevices: pairedDevices ?? this.pairedDevices,
      status: status ?? this.status,
    );
  }
}

class DeviceStateNotifier extends StateNotifier<DeviceState> {
  DeviceStateNotifier() : super(const DeviceState());

  void addDiscovered(Device device) {
    if (state.discoveredDevices.contains(device)) return;
    state = state.copyWith(
      discoveredDevices: [...state.discoveredDevices, device],
      status: DeviceConnectionStatus.discovered,
    );
  }

  void removeDiscovered(Device device) {
    state = state.copyWith(
      discoveredDevices: state.discoveredDevices.where((d) => d != device).toList(),
    );
  }

  void addPaired(TrustedDevice trusted) {
    if (state.pairedDevices.contains(trusted)) return;
    state = state.copyWith(
      pairedDevices: [...state.pairedDevices, trusted],
      status: DeviceConnectionStatus.paired,
    );
  }

  void removePaired(String deviceId) {
    state = state.copyWith(
      pairedDevices: state.pairedDevices.where((d) => d.deviceId != deviceId).toList(),
    );
  }
}

final deviceStateProvider =
    StateNotifierProvider<DeviceStateNotifier, DeviceState>(
  (ref) => DeviceStateNotifier(),
);
