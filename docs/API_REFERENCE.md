# API Reference

Complete class-level and method-level reference for every module in MeshDrop.

---

## Table of Contents

- [Core](#core)
  - [AppInitializer](#appinitializer)
  - [AppSettings](#appsettings)
- [Discovery](#discovery)
  - [Device](#device)
  - [PlatformType](#platformtype)
  - [DiscoveryAdapter](#discoveryadapter)
  - [NsdAdapter](#nsdadapter)
  - [BonjourAdapter](#bonjouradapter)
  - [AvahiAdapter](#avahiadapter)
  - [DeviceDiscoveryManager](#devicediscoverymanager)
- [Encryption](#encryption)
  - [CryptoManager](#cryptomanager)
  - [EncryptionSession](#encryptionsession)
- [Pairing](#pairing)
  - [SecureStorage](#securestorage)
  - [FlutterSecureStorageImpl](#fluttersecurestorageimpl)
  - [TrustedDevice](#trusteddevice)
  - [TrustedDeviceManager](#trusteddevicemanager)
  - [PairingNetworkProtocol](#pairingnetworkprotocol)
  - [PairingSession](#pairingsession)
- [Transfer](#transfer)
  - [TransferStatus](#transferstatus)
  - [FileChunk](#filechunk)
  - [TransferEntry](#transferentry)
  - [TransferRequest](#transferrequest)
  - [SocketReader](#socketreader)
  - [TransferProtocol](#transferprotocol)
  - [TransferQueue](#transferqueue)
  - [TransferNotification](#transfernotification)
  - [FileTransferManager](#filetransfermanager)
- [State](#state)
  - [AppState / AppStateNotifier](#appstate--appstatenotifier)
  - [DeviceState / DeviceStateNotifier](#devicestate--devicestatenotifier)
  - [TransferState / TransferStateNotifier](#transferstate--transferstatenotifier)
  - [AppSettingsNotifier](#appsettingsnotifier)
  - [Providers](#providers)
- [UI](#ui)
  - [MeshDropApp](#meshdropapp)
  - [HomeScreen](#homescreen)
  - [DeviceListScreen](#devicelistscreen)
  - [TransferScreen](#transferscreen)
  - [SettingsScreen](#settingsscreen)

---

## Core

### AppInitializer

**File**: `lib/core/app_initializer.dart`

Bootstraps the app by generating Ed25519 identity keys on first launch and persisting them to SecureStorage.

```dart
class AppInitializer {
  AppInitializer({
    required SecureStorage secureStorage,
    required CryptoManager cryptoManager,
  });

  /// Generates Ed25519 identity key pair on first launch.
  /// No-op if keys already exist in SecureStorage.
  /// Keys stored under: 'identity_ed25519_private', 'identity_ed25519_public'
  Future<void> ensureIdentityKeys() async;
}
```

---

### AppSettings

**File**: `lib/core/app_settings.dart`

Immutable value object representing user-configurable application settings.

```dart
class AppSettings {
  final String downloadDirectory;    // Where received files are saved
  final int chunkSizeBytes;          // Size per chunk (default: 65536 = 64 KB)
  final bool autoAccept;             // Auto-accept incoming transfers (default: false)

  const AppSettings({
    required this.downloadDirectory,
    this.chunkSizeBytes = 65536,
    this.autoAccept = false,
  });

  AppSettings copyWith({String? downloadDirectory, int? chunkSizeBytes, bool? autoAccept});
  Map<String, dynamic> toJson();
  factory AppSettings.fromJson(Map<String, dynamic> json);
}
```

---

## Discovery

### Device

**File**: `lib/features/discovery/models/device.dart`

Represents a peer device discovered on the local network via mDNS.

```dart
class Device {
  final String id;               // Unique identifier (from mDNS TXT record or hostname)
  final String name;             // Human-readable device name
  final String ipAddress;        // IPv4 address
  final int port;                // Transfer port (58432)
  final PlatformType platform;   // Device platform

  const Device({required this.id, required this.name, required this.ipAddress,
                required this.port, required this.platform});

  Device copyWith({String? id, String? name, String? ipAddress, int? port, PlatformType? platform});
  Map<String, dynamic> toJson();
  factory Device.fromJson(Map<String, dynamic> json);

  // Equality based on `id` field only.
  @override bool operator ==(Object other);
  @override int get hashCode;
  @override String toString();   // e.g. "Device(AliceLaptop @ 192.168.1.42:58432 [windows])"
}
```

---

### PlatformType

**File**: `lib/features/discovery/models/platform_type.dart`

```dart
enum PlatformType { iOS, android, windows, linux, unknown }
```

---

### DiscoveryAdapter

**File**: `lib/features/discovery/adapters/discovery_adapter.dart`

Abstract base class for platform-specific mDNS/DNS-SD implementations.

```dart
abstract class DiscoveryAdapter {
  @protected String get serviceName;   // e.g. "MeshDrop-AlicesPhone"
  @protected String get serviceType;   // e.g. "_meshdrop._tcp"

  void Function(Device device)? onDeviceFound;   // Callback: peer found
  void Function(Device device)? onDeviceLost;    // Callback: peer lost

  Future<void> advertise();       // Start broadcasting presence
  Future<void> stopAdvertise();   // Stop broadcasting
  Future<void> browse();          // Start listening for peers
  Future<void> stopBrowse();      // Stop listening
}
```

---

### NsdAdapter

**File**: `lib/features/discovery/adapters/nsd_adapter.dart`

Cross-platform mDNS adapter wrapping the `nsd` package. Used directly on Android; used as a delegate by `BonjourAdapter` and `AvahiAdapter`.

```dart
class NsdAdapter extends DiscoveryAdapter {
  static const String _serviceType = '_meshdrop._tcp';

  NsdAdapter({
    required String deviceName,
    required int port,
    required PlatformType platformType,
  });

  @override String get serviceName;   // "MeshDrop-<deviceName>"
  @override String get serviceType;

  @override Future<void> advertise();      // Registers NSD service with TXT records
  @override Future<void> stopAdvertise();  // Unregisters NSD service
  @override Future<void> browse();         // Starts NSD discovery with IPv4 lookup
  @override Future<void> stopBrowse();     // Stops NSD discovery
}
```

**TXT Records Published**:
| Key | Value |
|---|---|
| `deviceId` | UTF-8 encoded device name |
| `platform` | `PlatformType.name` (e.g., "android", "windows") |

---

### BonjourAdapter

**File**: `lib/features/discovery/adapters/bonjour_adapter.dart`

iOS-specific adapter. Delegates to `NsdAdapter` (since `nsd` wraps Bonjour on iOS). Kept as a separate class for potential iOS-specific customizations.

```dart
class BonjourAdapter extends DiscoveryAdapter {
  BonjourAdapter({required String deviceName, required int port});
  // All methods delegate to internal NsdAdapter with PlatformType.iOS
}
```

---

### AvahiAdapter

**File**: `lib/features/discovery/adapters/avahi_adapter.dart`

Windows/Linux adapter. Delegates to `NsdAdapter`. Platform type auto-detected from `Platform.isWindows`.

```dart
class AvahiAdapter extends DiscoveryAdapter {
  AvahiAdapter({required String deviceName, required int port});
  // All methods delegate to internal NsdAdapter with PlatformType.windows or .linux
}
```

---

### DeviceDiscoveryManager

**File**: `lib/features/discovery/device_discovery_manager.dart`

Owns a `DiscoveryAdapter` and maintains the in-memory list of discovered peers.

```dart
class DeviceDiscoveryManager {
  void Function(List<Device> devices)? onDevicesChanged;

  DeviceDiscoveryManager({required DiscoveryAdapter adapter});

  List<Device> getDiscoveredDevices();   // Returns unmodifiable snapshot
  Future<void> startAdvertising();
  Future<void> stopAdvertising();
  Future<void> startBrowsing();
  Future<void> stopBrowsing();
  void onDeviceFound(Device device);     // Manually trigger found event
  void onDeviceLost(Device device);      // Manually trigger lost event
  Device resolveDevice(String deviceId); // Lookup device by ID (throws if not found)
  void dispose();                        // Stops advertising + browsing
}
```

---

## Encryption

### CryptoManager

**File**: `lib/features/encryption/crypto_manager.dart`

Stateful cryptographic engine. Holds the Ed25519 signing key pair and provides all crypto operations.

```dart
class CryptoManager {
  // ── Key Generation ──
  Future<SimpleKeyPair> generateEd25519KeyPair();   // Long-term identity key
  Future<SimpleKeyPair> generateX25519KeyPair();     // Ephemeral exchange key

  // ── Key Exchange ──
  /// Derives 32-byte shared secret from our X25519 private key
  /// and the remote device's public key. Secret is never transmitted.
  Future<Uint8List> deriveSharedSecret(SimpleKeyPair ourKeyPair, Uint8List remotePublicKeyBytes);

  // ── Session Creation ──
  /// Creates EncryptionSession from shared secret.
  /// Session key = secret[0..31], nonce = 12 random bytes.
  Future<EncryptionSession> createSession(Uint8List sharedSecret);

  // ── Encryption / Decryption ──
  /// Encrypts plaintext. Returns: [12-byte nonce][ciphertext][16-byte MAC].
  /// Automatically refreshes the session nonce after encryption.
  Future<Uint8List> encrypt(Uint8List plaintext, EncryptionSession session);

  /// Decrypts a blob produced by encrypt().
  /// Parses nonce (first 12 bytes), MAC (last 16 bytes), ciphertext (middle).
  Future<Uint8List> decrypt(Uint8List ciphertext, EncryptionSession session);

  // ── Signing / Verification ──
  Future<Uint8List> sign(Uint8List data);   // Signs with Ed25519 key pair
  Future<bool> verify(Uint8List data, Uint8List signatureBytes, SimplePublicKey publicKey);
}
```

---

### EncryptionSession

**File**: `lib/features/encryption/encryption_session.dart`

Short-lived session binding a session key and nonce to one file transfer.

```dart
class EncryptionSession {
  final String sessionId;        // UUID v4
  final Uint8List sessionKey;    // 32-byte key from shared secret
  Uint8List nonce;               // 12-byte nonce (refreshed per chunk)
  final String algorithm;        // Default: 'ChaCha20-Poly1305'
  final DateTime createdAt;
  bool isActive;                 // Set to false after transfer completes

  EncryptionSession({
    required this.sessionId,
    required this.sessionKey,
    required this.nonce,
    this.algorithm = 'ChaCha20-Poly1305',
    DateTime? createdAt,
    this.isActive = true,
  });

  /// Generates a new random 12-byte nonce. MUST be called between every chunk.
  void refreshNonce();

  /// Marks session as invalid. Called after transfer completes or fails.
  void invalidate();
}
```

---

## Pairing

### SecureStorage

**File**: `lib/features/pairing/secure_storage/secure_storage.dart`

Abstract interface for platform-native secure key storage.

```dart
abstract class SecureStorage {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<bool> containsKey(String key);
}
```

---

### FlutterSecureStorageImpl

**File**: `lib/features/pairing/secure_storage/flutter_secure_storage_impl.dart`

Concrete `SecureStorage` implementation backed by `flutter_secure_storage`. Uses `EncryptedSharedPreferences` on Android.

```dart
class FlutterSecureStorageImpl implements SecureStorage {
  // Wraps FlutterSecureStorage with AndroidOptions(encryptedSharedPreferences: true)
}
```

---

### TrustedDevice

**File**: `lib/features/pairing/trusted_device.dart`

Represents a device that has completed the pairing handshake.

```dart
class TrustedDevice {
  final String deviceId;
  final String deviceName;
  final Uint8List publicKey;           // Remote device's X25519 public key
  final DateTime pairingDate;
  DateTime lastSeen;                   // Updated each time device is seen online
  final Map<String, dynamic> sessionMetadata;
  bool isVerified;                     // Defaults to true after pairing

  TrustedDevice({...});

  void updateLastSeen();               // Stamps DateTime.now()
  Map<String, dynamic> toJson();
  factory TrustedDevice.fromJson(Map<String, dynamic> json);

  // Equality based on deviceId.
  @override bool operator ==(Object other);
  @override int get hashCode;
}
```

---

### TrustedDeviceManager

**File**: `lib/features/pairing/trusted_device_manager.dart`

Manages the list of trusted devices in SecureStorage using a manifest pattern.

```dart
class TrustedDeviceManager {
  TrustedDeviceManager({required SecureStorage secureStorage});

  /// Loads all trusted devices by reading the manifest, then loading each entry.
  Future<List<TrustedDevice>> loadTrustedDevices();

  /// Deletes a trusted device from storage and the manifest.
  Future<void> removeDevice(String deviceId);

  /// Adds a device ID to the manifest (called after completePairing).
  Future<void> registerDevice(String deviceId);
}
```

**Storage keys**:
- `trusted_device_manifest`: JSON array of device IDs
- `trusted_<deviceId>`: JSON-serialized `TrustedDevice`

---

### PairingNetworkProtocol

**File**: `lib/features/pairing/pairing_network_protocol.dart`

Static utility for the MSHP wire protocol (X25519 key exchange).

```dart
class PairingNetworkProtocol {
  static const int _magic = 0x4D534850;   // "MSHP"

  /// Sends X25519 public key: [magic][key_length][key_bytes]
  static Future<void> sendPublicKey(Socket socket, Uint8List publicKey);

  /// Reads remote public key. Returns null if magic doesn't match.
  /// Key length must be 1..256 bytes (sanity check).
  static Future<Uint8List?> readPublicKey(Socket socket);
}
```

---

### PairingSession

**File**: `lib/features/pairing/pairing_session.dart`

Full Diffie–Hellman key exchange + confirmation flow. Produces a `TrustedDevice` on success.

```dart
class PairingSession {
  static const int pairingPort = 58433;

  PairingSession({required CryptoManager cryptoManager, required SecureStorage secureStorage});

  // ── Initiator ──
  /// Connect to device, exchange X25519 keys.
  Future<void> initiate(Device device);

  // ── Receiver ──
  /// Start TCP server on port 58433, accept one connection, exchange keys.
  Future<void> startPairingServer();
  Future<void> stopPairingServer();

  // ── Key Exchange ──
  Future<Uint8List> performKeyExchange();     // Extract our public key bytes
  void setRemotePublicKey(Uint8List key);     // Store received remote key

  // ── Confirmation ──
  Future<String> generateConfirmationCode();  // Derive shared secret + 6-digit code
  String? get confirmationCode;
  Uint8List? get sharedSecret;
  bool verifyPairing(String code);            // Check if code matches

  // ── Completion ──
  /// Persist TrustedDevice to SecureStorage. Register in manifest if deviceManager provided.
  Future<TrustedDevice> completePairing(Device device, {TrustedDeviceManager? deviceManager});

  void dispose();
}
```

---

## Transfer

### TransferStatus

**File**: `lib/features/transfer/models/transfer_status.dart`

```dart
enum TransferStatus { queued, inProgress, paused, completed, failed, cancelled }
```

---

### FileChunk

**File**: `lib/features/transfer/models/file_chunk.dart`

One unit of a chunked file transfer with integrity checksum.

```dart
class FileChunk {
  final int chunkId;           // Sequential chunk index
  final String transferId;     // Parent transfer UUID
  final Uint8List data;        // Raw (pre-encryption) chunk bytes
  final int offset;            // Byte offset within the original file
  final int size;              // data.length
  final String checksum;       // SHA-256 hex digest of data
  final bool isLast;           // True for the final chunk

  const FileChunk({...});

  /// Recomputes SHA-256 and verifies against stored checksum.
  bool validate();

  /// Factory that auto-computes the SHA-256 checksum.
  factory FileChunk.create({
    required int chunkId,
    required String transferId,
    required Uint8List data,
    required int offset,
    required bool isLast,
  });
}
```

---

### TransferEntry

**File**: `lib/features/transfer/models/transfer_entry.dart`

Metadata for a single file transfer (send or receive).

```dart
class TransferEntry {
  final String transferId;      // UUID v4
  final String fileName;
  final int fileSize;           // Total bytes
  TransferStatus status;
  double progress;              // 0.0 – 1.0
  final Device targetDevice;    // Remote peer
  final DateTime startedAt;
  DateTime? completedAt;

  TransferEntry({...});

  TransferEntry copyWith({TransferStatus? status, double? progress, DateTime? completedAt});
  String get fileSizeLabel;     // e.g. "2.4 MB", "512 B", "1.23 GB"

  // Equality based on transferId.
  @override bool operator ==(Object other);
  @override int get hashCode;
}
```

---

### TransferRequest

**File**: `lib/features/transfer/transfer_protocol.dart`

Parsed transfer request header received from the sender.

```dart
class TransferRequest {
  final String senderName;
  final String fileName;
  final int fileSize;
  final Uint8List senderPublicKey;  // 32-byte X25519 public key

  const TransferRequest({...});

  String get fileSizeLabel;   // Human-readable size string
}
```

---

### SocketReader

**File**: `lib/features/transfer/socket_reader.dart`

Buffered byte reader over a TCP socket stream. Shared between protocol header parsing and chunk reading to prevent multiple stream subscriptions.

```dart
class SocketReader {
  SocketReader(Socket socket);  // Subscribes to socket stream via StreamIterator

  /// Reads exactly [count] bytes, buffering as needed.
  /// Throws StateError('Socket closed') if stream ends prematurely.
  Future<Uint8List> read(int count);
}
```

---

### TransferProtocol

**File**: `lib/features/transfer/transfer_protocol.dart`

Static utility for the MSHD wire protocol (transfer request/response headers).

```dart
class TransferProtocol {
  static const int _magic = 0x4D534844;   // "MSHD"

  /// Writes transfer request: [magic][sender_name][file_name][file_size][public_key]
  static Future<void> sendRequest(Socket socket, {
    required String senderName,
    required String fileName,
    required int fileSize,
    required Uint8List senderPublicKey,  // Must be 32 bytes
  });

  /// Reads transfer request using existing SocketReader.
  /// Returns null if magic doesn't match or parsing fails.
  static Future<TransferRequest?> readRequest(SocketReader reader);

  /// Sends accept: [0x01][32-byte receiver public key]
  static void sendAccept(Socket socket, Uint8List receiverPublicKey);

  /// Sends reject: [0x00]
  static void sendReject(Socket socket);

  /// Reads response. Returns 32-byte public key if accepted, null if rejected.
  static Future<Uint8List?> readResponse(SocketReader reader);
}
```

---

### TransferQueue

**File**: `lib/features/transfer/transfer_queue.dart`

Ordered list of pending and active transfers. Composed inside `FileTransferManager`.

```dart
class TransferQueue {
  void enqueue(TransferEntry entry);
  TransferEntry? dequeue();                          // First queued entry
  List<TransferEntry> getActive();                   // In-progress entries
  List<TransferEntry> getByStatus(TransferStatus s);
  void updateStatus(String transferId, TransferStatus status);
  void updateProgress(String transferId, double progress);
  TransferEntry? getById(String transferId);
  List<TransferEntry> getAll();                      // Unmodifiable snapshot
  void clear();
}
```

---

### TransferNotification

**File**: `lib/features/transfer/transfer_notification.dart`

Wraps `flutter_local_notifications` to show native OS notifications for transfer progress, completion, and failure.

```dart
class TransferNotification {
  TransferNotification();

  Future<void> initialize();   // Lazy init; called automatically

  /// Shows a progress notification (Android: progress bar, others: text).
  Future<void> showProgress(String transferId, String fileName, double progress);

  /// Shows a completion notification.
  Future<void> showCompleted(String transferId, String fileName);

  /// Shows a failure notification with error details.
  Future<void> showFailed(String transferId, String error);

  /// Dismisses a notification by transfer ID.
  Future<void> dismiss(String transferId);
}
```

**Notification Channel** (Android): `meshdrop_transfer` / "File Transfers"

---

### FileTransferManager

**File**: `lib/features/transfer/file_transfer_manager.dart`

Central orchestrator for all file transfer operations. Manages the TCP receive server and send flow.

```dart
class FileTransferManager {
  static const int _port = 58432;
  static const int _chunkSize = 65536;

  FileTransferManager({
    required DeviceDiscoveryManager discoveryManager,
    required CryptoManager cryptoManager,
    required TransferNotification notification,
    required String localDeviceName,
    String? downloadDirectory,
  });

  String? downloadDirectory;   // Mutable; updated dynamically by provider

  // ── Callbacks (wired by provider layer) ──
  void Function(TransferEntry entry)? onTransferUpdated;
  Future<bool> Function(TransferRequest request)? onIncomingRequest;
  TrustedDevice? Function(String deviceId)? lookupTrustedDevice;

  // ── Receive Server ──
  Future<void> startReceiveServer();   // ServerSocket.bind(:58432)
  Future<void> stopReceiveServer();

  // ── Send ──
  Future<void> sendFile(File file, Device target);

  // ── Transfer Control ──
  void pauseTransfer(String transferId);
  void resumeTransfer(String transferId);
  void cancelTransfer(String transferId);
}
```

---

## State

### AppState / AppStateNotifier

**File**: `lib/state/app_state.dart`

Root state composing device and transfer state with encryption session.

```dart
class AppState {
  final DeviceState deviceState;
  final TransferState transferState;
  final EncryptionSession? encryptionSession;
  final bool isDiscovering;

  const AppState({...});
  AppState copyWith({...});
}

class AppStateNotifier extends StateNotifier<AppState> {
  void updateDeviceState(DeviceState deviceState);
  void updateTransferState(TransferState transferState);
  void setEncryptionSession(EncryptionSession session);
  void setDiscovering(bool discovering);
}

// Provider: listens to deviceStateProvider and transferStateProvider
final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>(...);
```

---

### DeviceState / DeviceStateNotifier

**File**: `lib/state/device_state.dart`

```dart
enum DeviceConnectionStatus { discovered, paired, untrusted, offline }

class DeviceState {
  final List<Device> discoveredDevices;
  final List<TrustedDevice> pairedDevices;
  final DeviceConnectionStatus status;

  const DeviceState({...});
  DeviceState copyWith({...});
}

class DeviceStateNotifier extends StateNotifier<DeviceState> {
  void addDiscovered(Device device);       // Ignores duplicates
  void removeDiscovered(Device device);
  void addPaired(TrustedDevice trusted);   // Ignores duplicates
  void removePaired(String deviceId);
}

final deviceStateProvider = StateNotifierProvider<DeviceStateNotifier, DeviceState>(...);
```

---

### TransferState / TransferStateNotifier

**File**: `lib/state/transfer_state.dart`

```dart
class TransferState {
  final List<TransferEntry> activeTransfers;
  final List<TransferEntry> completedTransfers;
  final double currentProgress;
  final TransferStatus status;

  const TransferState({...});
  TransferState copyWith({...});
}

class TransferStateNotifier extends StateNotifier<TransferState> {
  static const _historyKey = 'meshdrop_transfer_history';

  void addTransfer(TransferEntry entry);
  void updateEntry(TransferEntry newEntry);     // Match by transferId
  void removeTransfer(String transferId);       // Moves to completedTransfers if finished
  void onTransferUpdated(TransferEntry entry);  // Unified handler for all status changes
}

final transferStateProvider = StateNotifierProvider<TransferStateNotifier, TransferState>(...);
```

**Persistence**: Completed transfers are serialized to JSON and stored in `SharedPreferences` under key `meshdrop_transfer_history`.

---

### AppSettingsNotifier

**File**: `lib/state/app_settings_provider.dart`

```dart
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  static const _prefsKey = 'meshdrop_app_settings';

  AppSettingsNotifier(AppSettings initial);

  /// Updates fields and persists to SharedPreferences.
  Future<void> update({String? downloadDirectory, int? chunkSizeBytes, bool? autoAccept});

  /// Loads from SharedPreferences, falling back to system Documents dir.
  static Future<AppSettings> load();
}
```

---

### Providers

**File**: `lib/state/` (various files)

| Provider | Type | File |
|---|---|---|
| `appSettingsProvider` | `StateNotifierProvider<AppSettingsNotifier, AppSettings>` | `app_settings_provider.dart` |
| `appStateProvider` | `StateNotifierProvider<AppStateNotifier, AppState>` | `app_state.dart` |
| `deviceStateProvider` | `StateNotifierProvider<DeviceStateNotifier, DeviceState>` | `device_state.dart` |
| `transferStateProvider` | `StateNotifierProvider<TransferStateNotifier, TransferState>` | `transfer_state.dart` |
| `cryptoManagerProvider` | `Provider<CryptoManager>` | `init_provider.dart` |
| `secureStorageProvider` | `Provider<SecureStorage>` | `init_provider.dart` |
| `initProvider` | `FutureProvider<void>` | `init_provider.dart` |
| `discoveryManagerProvider` | `Provider<DeviceDiscoveryManager>` | `discovery_provider.dart` |
| `transferManagerProvider` | `Provider<FileTransferManager>` | `transfer_manager_provider.dart` |
| `trustedDeviceManagerProvider` | `Provider<TrustedDeviceManager>` | `trusted_devices_provider.dart` |
| `loadTrustedDevicesProvider` | `FutureProvider<void>` | `trusted_devices_provider.dart` |

---

## UI

### MeshDropApp

**File**: `lib/main.dart`

Root widget. Configures `MaterialApp` with dark theme and named routes.

| Route | Screen |
|---|---|
| `/` | `HomeScreen` |
| `/devices` | `DeviceListScreen` |
| `/transfers` | `TransferScreen` |
| `/settings` | `SettingsScreen` |

**Theme**: Material 3, dark mode. Background: `#0D1117`, Surface: `#161B22`, Primary: `#238636`.

---

### HomeScreen

**File**: `lib/ui/home_screen.dart`

Landing screen. Displays discovered devices as tappable cards. Tapping a device opens the native file picker and initiates a send. Shows incoming transfer Accept/Reject dialogs.

**Sub-widgets**:
- `_EmptyDiscoveryView`: Shown when no devices are discovered.
- `_DeviceCard`: Material card showing device name, IP, platform icon, and send button.

---

### DeviceListScreen

**File**: `lib/ui/device_list_screen.dart`

Two-section view: "Nearby" (discovered, unverified devices with Pair button) and "Trusted" (paired devices with Delete button). Initiates the full pairing flow including confirmation code dialog.

**Sub-widgets**:
- `_PairingConfirmDialog`: Shows 6-digit confirmation code in monospace font with green border.

---

### TransferScreen

**File**: `lib/ui/transfer_screen.dart`

Two-section view: "Active" transfers with progress bars and Pause/Resume/Cancel controls, and "History" showing completed/failed/cancelled transfers.

**Sub-widgets**:
- `_ActiveTransferCard`: Progress bar, file name, size, target device, control buttons.
- `_HistoryCard`: File name, size, target device, colored status icon.

---

### SettingsScreen

**File**: `lib/ui/settings_screen.dart`

Preferences screen with:
- Download directory picker (native folder dialog)
- Auto-accept toggle switch
- Chunk size selector (dialog with 32/64/128/256 KB options)
- Clear trusted devices (with confirmation dialog)
