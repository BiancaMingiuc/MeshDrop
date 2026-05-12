// state/app_state.dart
// Root Riverpod state. Single source of truth for the whole app.
// Composes DeviceState and TransferState (lifecycle-bound).
// Aggregates EncryptionSession (nullable reference, owned by CryptoManager).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/encryption/encryption_session.dart';
import 'device_state.dart';
import 'transfer_state.dart';

class AppState {
  final DeviceState deviceState;
  final TransferState transferState;
  final EncryptionSession? encryptionSession;
  final bool isDiscovering;

  const AppState({
    required this.deviceState,
    required this.transferState,
    this.encryptionSession,
    this.isDiscovering = false,
  });

  AppState copyWith({
    DeviceState? deviceState,
    TransferState? transferState,
    EncryptionSession? encryptionSession,
    bool? isDiscovering,
  }) {
    return AppState(
      deviceState: deviceState ?? this.deviceState,
      transferState: transferState ?? this.transferState,
      encryptionSession: encryptionSession ?? this.encryptionSession,
      isDiscovering: isDiscovering ?? this.isDiscovering,
    );
  }
}

class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier()
      : super(AppState(
          deviceState: const DeviceState(),
          transferState: const TransferState(),
        ));

  void updateDeviceState(DeviceState deviceState) =>
      state = state.copyWith(deviceState: deviceState);

  void updateTransferState(TransferState transferState) =>
      state = state.copyWith(transferState: transferState);

  void setEncryptionSession(EncryptionSession session) =>
      state = state.copyWith(encryptionSession: session);

  void setDiscovering(bool discovering) =>
      state = state.copyWith(isDiscovering: discovering);
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>(
  (ref) {
    final notifier = AppStateNotifier();
    // Keep AppState in sync with nested DeviceState and TransferState.
    ref.listen(deviceStateProvider, (_, next) => notifier.updateDeviceState(next));
    ref.listen(transferStateProvider, (_, next) => notifier.updateTransferState(next));
    return notifier;
  },
);
