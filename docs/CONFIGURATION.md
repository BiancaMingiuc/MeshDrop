# Configuration Guide

This document covers MeshDrop's configuration system, storage backends, default values, and tuning recommendations.

---

## Table of Contents

- [Settings Overview](#settings-overview)
- [Persistence Layer](#persistence-layer)
- [Settings Reference](#settings-reference)
- [Initialization Flow](#initialization-flow)
- [Runtime Updates](#runtime-updates)
- [Transfer History Persistence](#transfer-history-persistence)
- [Secure Storage Keys](#secure-storage-keys)
- [Platform-Specific Notes](#platform-specific-notes)
- [Tuning Guide](#tuning-guide)

---

## Settings Overview

MeshDrop stores user preferences in an `AppSettings` object that is:

1. **Loaded synchronously at startup** before `runApp()` is called, ensuring settings are available to all providers from the first frame.
2. **Persisted to `SharedPreferences`** as a JSON string under the key `meshdrop_app_settings`.
3. **Updated reactively** via the `AppSettingsNotifier` — any change is immediately reflected in the Riverpod provider tree and persisted to disk.

---

## Persistence Layer

```
┌──────────────────────────────────────────────────────────────┐
│ Storage Type      │ Backend              │ Data Stored       │
├───────────────────┼──────────────────────┼───────────────────┤
│ SharedPreferences │ Platform key-value   │ App settings      │
│                   │ store (XML on        │ Transfer history  │
│                   │ Android, plist on    │                   │
│                   │ iOS, registry/file   │                   │
│                   │ on desktop)          │                   │
├───────────────────┼──────────────────────┼───────────────────┤
│ SecureStorage     │ iOS Keychain         │ Ed25519 keys      │
│                   │ Android Keystore     │ Trusted devices   │
│                   │ Windows Credential   │ Device manifest   │
│                   │ Manager              │                   │
│                   │ Linux libsecret      │                   │
└──────────────────────────────────────────────────────────────┘
```

**Key distinction**: User preferences (non-sensitive) use `SharedPreferences`. Cryptographic keys and trust data (sensitive) use `SecureStorage` backed by platform-native keystores.

---

## Settings Reference

### AppSettings Fields

| Field | Type | Default | Persisted Key | Description |
|---|---|---|---|---|
| `downloadDirectory` | `String` | System Documents dir | `downloadDirectory` | Filesystem path where received files are written |
| `chunkSizeBytes` | `int` | `65536` (64 KB) | `chunkSizeBytes` | Plaintext size of each transfer chunk in bytes |
| `autoAccept` | `bool` | `false` | `autoAccept` | When `true`, incoming transfers are accepted without showing the Accept/Reject dialog |

### SharedPreferences Key

All settings are serialized as a single JSON object under:

```
Key: meshdrop_app_settings
Value: {"downloadDirectory":"/path/to/downloads","chunkSizeBytes":65536,"autoAccept":false}
```

---

## Initialization Flow

Settings are loaded before the Flutter widget tree mounts:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load settings from SharedPreferences (async)
  await initAppSettingsProvider();
  //    └── AppSettingsNotifier.load()
  //        ├── SharedPreferences.getString('meshdrop_app_settings')
  //        ├── If found: AppSettings.fromJson(decoded)
  //        └── If null/corrupted: fallback to defaults
  //            └── downloadDirectory = getApplicationDocumentsDirectory()

  // 2. Create the provider with loaded settings
  // The `appSettingsProvider` is a late final global that is assigned here.

  runApp(const ProviderScope(child: MeshDropApp()));
}
```

This guarantees that `appSettingsProvider` is ready before any provider or widget reads it.

### Default Download Directory

On first launch (no persisted settings), the download directory defaults to the platform's application documents directory:

| Platform | Default Path |
|---|---|
| **Windows** | `C:\Users\<user>\Documents` |
| **Android** | `/data/data/com.example.meshdrop/app_flutter/` (internal) |
| **iOS** | Application Documents directory (sandboxed) |
| **Linux** | `~/.local/share/meshdrop/` or equivalent |

Users can change this via the Settings screen by selecting any directory via the native file picker.

---

## Runtime Updates

When the user changes a setting via the Settings screen:

```dart
await ref.read(appSettingsProvider.notifier).update(
  downloadDirectory: '/new/path',
);
```

This triggers:
1. `AppSettingsNotifier.state` is updated with `copyWith(...)`.
2. `_persist()` is called, writing the full JSON to `SharedPreferences`.
3. All providers/widgets watching `appSettingsProvider` rebuild.
4. `transferManagerProvider` listens for `downloadDirectory` changes and dynamically updates `FileTransferManager.downloadDirectory` without restarting the server.

---

## Transfer History Persistence

Completed transfers are persisted separately from app settings:

| Key | Format | Content |
|---|---|---|
| `meshdrop_transfer_history` | JSON array | List of serialized `TransferEntry` objects |

### Serialized TransferEntry Format

```json
{
  "transferId": "a1b2c3d4-...",
  "fileName": "photo.jpg",
  "fileSize": 2048576,
  "status": "completed",
  "progress": 1.0,
  "startedAt": "2026-01-15T10:30:00.000Z",
  "completedAt": "2026-01-15T10:30:05.000Z",
  "targetDevice": {
    "id": "AliceLaptop",
    "name": "AliceLaptop",
    "ipAddress": "192.168.1.42",
    "port": 58432,
    "platform": "windows"
  }
}
```

### History Behavior

- History is loaded in the `TransferStateNotifier` constructor via `_loadHistory()`.
- Entries are added to history when a transfer transitions to `completed`, `failed`, or `cancelled`.
- Corrupted entries are silently skipped during loading (best-effort deserialization).
- There is no automatic history pruning — entries accumulate indefinitely.

---

## Secure Storage Keys

The following keys are stored in platform-native secure storage:

| Key | Format | Written By | Read By |
|---|---|---|---|
| `identity_ed25519_private` | Base64 string | `AppInitializer.ensureIdentityKeys()` | Not currently read at runtime |
| `identity_ed25519_public` | Base64 string | `AppInitializer.ensureIdentityKeys()` | Not currently read at runtime |
| `trusted_<deviceId>` | JSON string | `PairingSession.completePairing()` | `TrustedDeviceManager.loadTrustedDevices()` |
| `trusted_device_manifest` | JSON array of strings | `TrustedDeviceManager.registerDevice()` | `TrustedDeviceManager.loadTrustedDevices()` |

### Manifest Pattern

Since `flutter_secure_storage` does not expose a `readAll()` method through MeshDrop's abstract `SecureStorage` interface, trusted devices are enumerated via a manifest:

1. `trusted_device_manifest` stores a JSON array of device IDs: `["device1", "device2"]`
2. On load, each ID is used to construct the key `trusted_<id>` and read the corresponding JSON.
3. When a device is added: the ID is appended to the manifest.
4. When a device is removed: the ID is removed from the manifest, and the `trusted_<id>` key is deleted.

---

## Platform-Specific Notes

### Android

- `FlutterSecureStorage` uses `EncryptedSharedPreferences` (`AndroidOptions(encryptedSharedPreferences: true)`), which provides AES-256-SIV encryption backed by Android Keystore.
- The `SharedPreferences` instance (for app settings) uses standard Android SharedPreferences (XML file in app data directory).
- Transfer notifications use the `meshdrop_transfer` Android notification channel.

### iOS

- `FlutterSecureStorage` uses iOS Keychain Services.
- Keychain items persist across app updates but are deleted on uninstall.
- Local network access requires `NSLocalNetworkUsageDescription` and `NSBonjourServices` entries in `Info.plist`.

### Windows

- `FlutterSecureStorage` uses Windows Credential Manager (DPAPI encryption).
- `SharedPreferences` stores data in a JSON file in the app data directory.
- The Windows Firewall must allow inbound TCP on ports 58432 and 58433.

### Linux

- `FlutterSecureStorage` uses libsecret (GNOME Keyring or KWallet).
- Requires `libsecret-1-dev` to be installed.
- The Avahi daemon must be running for mDNS discovery.

---

## Tuning Guide

### Chunk Size Selection

| Chunk Size | Best For | Trade-offs |
|---|---|---|
| **32 KB** | Slow/unreliable networks, mobile data | More protocol overhead, finer progress granularity |
| **64 KB** (default) | LAN transfers, balanced | Good balance of throughput and progress reporting |
| **128 KB** | Fast LAN, larger files | Better throughput, less frequent progress updates |
| **256 KB** | Gigabit LAN, very large files | Maximum throughput, coarse progress updates |

**Recommendation**: The default 64 KB is optimal for typical Wi-Fi LAN transfers. Increase to 128–256 KB for Gigabit Ethernet transfers of large files.

### Encrypted Overhead

Each encrypted chunk adds 28 bytes of overhead (12-byte nonce + 16-byte MAC tag):

| Plaintext Size | Encrypted Size | Overhead |
|---|---|---|
| 32 KB | 32,796 bytes | 0.085% |
| 64 KB | 65,564 bytes | 0.043% |
| 128 KB | 131,100 bytes | 0.021% |
| 256 KB | 262,172 bytes | 0.011% |

The overhead is negligible for all supported chunk sizes.

### Auto-Accept Mode

When `autoAccept` is `true`:
- Incoming transfers bypass the Accept/Reject dialog entirely.
- The `onIncomingRequest` callback still fires but returns `true` immediately.
- **Security warning**: This mode should only be enabled on trusted networks. Any device on the same LAN can send files without user confirmation.

### Network Port Configuration

The transfer port (58432) and pairing port (58433) are currently hardcoded as compile-time constants:

- `FileTransferManager._port = 58432`
- `PairingSession.pairingPort = 58433`
- `discoveryManagerProvider._makeAdapter()` → `port = 58432`

To change these ports, modify the constants and rebuild. There is no runtime port configuration.
