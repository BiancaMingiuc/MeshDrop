# MeshDrop

**Cross-platform, encrypted, peer-to-peer file transfer — AirDrop for everyone.**

MeshDrop is a Flutter-based application that lets users share files between devices on the same local network with zero configuration. Files are transferred over direct TCP sockets, encrypted end-to-end with ChaCha20-Poly1305 AEAD, and authenticated via X25519 Diffie–Hellman key exchange and Ed25519 identity signatures. Device discovery is fully automatic via mDNS/DNS-SD.

---

## Table of Contents

- [Features](#features)
- [Supported Platforms](#supported-platforms)
- [Architecture Overview](#architecture-overview)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Configuration](#configuration)
- [Documentation](#documentation)
- [Dependencies](#dependencies)
- [Testing](#testing)
- [License](#license)

---

## Features

| Category | Details |
|---|---|
| **Zero-Config Discovery** | Automatic peer detection via mDNS/DNS-SD (`_meshdrop._tcp`). No manual IP entry required. |
| **End-to-End Encryption** | Every transfer uses a fresh ephemeral X25519 key pair to derive a shared secret, then encrypts each chunk with ChaCha20-Poly1305 AEAD. |
| **Device Pairing** | Secure pairing with 6-digit confirmation codes derived from the ECDH shared secret. Paired devices are persisted in platform-native secure storage. |
| **Chunked Streaming** | Files are split into 64 KB chunks (configurable: 32–256 KB), encrypted individually, and streamed to disk on the receiver — no full-file buffering. |
| **Transfer Management** | Pause, resume, and cancel active transfers. Transfer history is persisted across app restarts. |
| **OS Notifications** | Native progress and completion notifications on Android, iOS, and Linux. |
| **Dark UI** | Material 3 dark theme with GitHub-inspired color palette (`#0D1117` / `#161B22` / `#238636`). |
| **Accept/Reject Dialogs** | Incoming transfers prompt the user with file name and size before any data is received. Optional auto-accept mode available. |

---

## Supported Platforms

| Platform | Discovery Adapter | Secure Storage Backend | Status |
|---|---|---|---|
| **Windows** | `AvahiAdapter` → `NsdAdapter` (Windows mDNS API) | OS Credential Manager | ✅ Primary target |
| **Android** | `NsdAdapter` (Android NSD) | Android Keystore / EncryptedSharedPreferences | ✅ Supported |
| **iOS** | `BonjourAdapter` → `NsdAdapter` (Bonjour) | iOS Keychain | ✅ Supported |
| **Linux** | `AvahiAdapter` → `NsdAdapter` (Avahi) | libsecret | ✅ Supported |

---

## Architecture Overview

MeshDrop follows a **layered, modular architecture** with strict separation of concerns:

```
┌─────────────────────────────────────────────────────┐
│                     UI Layer                        │
│  HomeScreen · DeviceListScreen · TransferScreen     │
│  SettingsScreen                                     │
├─────────────────────────────────────────────────────┤
│                  State Layer (Riverpod)             │
│  AppState · DeviceState · TransferState             │
│  Providers (init, discovery, transfer, settings)    │
├─────────────────────────────────────────────────────┤
│                 Features Layer                      │
│  Discovery · Encryption · Pairing · Transfer        │
├─────────────────────────────────────────────────────┤
│                   Core Layer                        │
│  AppInitializer · AppSettings                       │
└─────────────────────────────────────────────────────┘
```

**Key design principles:**

- **Adapter Pattern**: Platform-specific discovery is abstracted behind `DiscoveryAdapter`. Adding a new platform requires only a new adapter subclass (Open/Closed Principle).
- **Dependency Inversion**: Secure storage is accessed through an abstract `SecureStorage` interface; the concrete `FlutterSecureStorageImpl` is injected at runtime via Riverpod.
- **Composition over Inheritance**: `AppState` composes `DeviceState` and `TransferState`. `FileTransferManager` composes `TransferQueue`, `CryptoManager`, and `TransferNotification`.
- **Callback Wiring**: Feature-layer classes expose callback hooks (`onDevicesChanged`, `onTransferUpdated`, `onIncomingRequest`) that the provider layer wires to Riverpod notifiers.

> 📖 For the full architectural deep-dive, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Project Structure

```text
lib/
├── main.dart                           # App entry point, MaterialApp, routing
├── core/
│   ├── app_initializer.dart            # Bootstrap: identity key generation
│   └── app_settings.dart               # Settings model (download dir, chunk size, auto-accept)
├── features/
│   ├── discovery/
│   │   ├── device_discovery_manager.dart  # Owns adapter, manages discovered peer list
│   │   ├── adapters/
│   │   │   ├── discovery_adapter.dart     # Abstract mDNS adapter interface
│   │   │   ├── nsd_adapter.dart           # Cross-platform NSD implementation
│   │   │   ├── bonjour_adapter.dart       # iOS-specific (delegates to NsdAdapter)
│   │   │   └── avahi_adapter.dart         # Windows/Linux (delegates to NsdAdapter)
│   │   └── models/
│   │       ├── device.dart                # Discovered peer model
│   │       └── platform_type.dart         # Platform enum (iOS, android, windows, linux)
│   ├── encryption/
│   │   ├── crypto_manager.dart            # Key gen, ECDH, ChaCha20-Poly1305 encrypt/decrypt
│   │   └── encryption_session.dart        # Per-transfer session (key + nonce + lifecycle)
│   ├── pairing/
│   │   ├── pairing_session.dart           # Full ECDH handshake + confirmation flow
│   │   ├── pairing_network_protocol.dart  # Wire format for key exchange ("MSHP" magic)
│   │   ├── trusted_device.dart            # Paired device model (persisted)
│   │   ├── trusted_device_manager.dart    # CRUD for trusted device manifest
│   │   └── secure_storage/
│   │       ├── secure_storage.dart        # Abstract key storage interface
│   │       └── flutter_secure_storage_impl.dart  # Concrete impl (Keychain/Keystore)
│   └── transfer/
│       ├── file_transfer_manager.dart     # Send/receive orchestrator, TCP server
│       ├── transfer_protocol.dart         # Wire format for transfer headers ("MSHD" magic)
│       ├── transfer_queue.dart            # Ordered queue of active transfers
│       ├── transfer_notification.dart     # Native OS notification wrapper
│       ├── socket_reader.dart             # Buffered byte reader over TCP stream
│       └── models/
│           ├── file_chunk.dart            # Chunk model with SHA-256 checksum
│           ├── transfer_entry.dart        # Transfer metadata (progress, status, device)
│           └── transfer_status.dart       # Status enum (queued → inProgress → completed)
├── state/
│   ├── app_state.dart                     # Root state: composes Device + Transfer state
│   ├── device_state.dart                  # Discovered + paired device lists
│   ├── transfer_state.dart                # Active + completed transfers, persistence
│   ├── app_settings_provider.dart         # Settings notifier + SharedPreferences persistence
│   ├── discovery_provider.dart            # Discovery manager ↔ DeviceState bridge
│   ├── init_provider.dart                 # One-shot identity key initialization
│   ├── transfer_manager_provider.dart     # Transfer manager ↔ TransferState bridge
│   └── trusted_devices_provider.dart      # Loads trusted devices from SecureStorage
└── ui/
    ├── home_screen.dart                   # Landing screen, device list, send flow
    ├── device_list_screen.dart            # Nearby + trusted devices, pairing flow
    ├── transfer_screen.dart               # Active transfers with progress, history
    └── settings_screen.dart               # Download dir, chunk size, auto-accept, trust management
```

---

## Getting Started

### Prerequisites

| Tool | Version |
|---|---|
| Flutter SDK | ≥ 3.11.5 (stable channel) |
| Dart SDK | ≥ 3.11.5 |
| Android Studio / Xcode | For mobile builds |
| Visual Studio | For Windows desktop builds (C++ workload) |

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/your-org/meshdrop.git
cd meshdrop

# 2. Install dependencies
flutter pub get

# 3. (Optional) Generate Riverpod code if using riverpod_generator
flutter pub run build_runner build --delete-conflicting-outputs

# 4. Run on your target platform
flutter run -d windows   # Desktop
flutter run -d android   # Android emulator or device
flutter run -d ios        # iOS simulator or device
```

### Platform-Specific Setup

#### Windows
- Ensure the Windows Firewall allows inbound TCP on port **58432** (transfers) and **58433** (pairing).
- The `nsd` package uses the Windows mDNS API — no additional software required.

#### Android
- Minimum SDK: Android 5.0 (API 21).
- The `nsd` package uses Android's built-in NSD (Network Service Discovery) APIs.
- `flutter_secure_storage` uses `EncryptedSharedPreferences` for secure key persistence.

#### iOS
- The `nsd` package wraps Apple's Bonjour framework.
- Add the following keys to `Info.plist` for local network access:
  ```xml
  <key>NSLocalNetworkUsageDescription</key>
  <string>MeshDrop needs local network access to discover nearby devices.</string>
  <key>NSBonjourServices</key>
  <array>
    <string>_meshdrop._tcp</string>
  </array>
  ```

#### Linux
- Ensure Avahi daemon is running: `sudo systemctl start avahi-daemon`.
- Install `libsecret-1-dev` for `flutter_secure_storage` support.

---

## Usage

### Sending a File

1. Open MeshDrop on both the sending and receiving device.
2. Ensure both devices are on the **same Wi-Fi network**.
3. On the sender, the home screen displays nearby discovered devices.
4. **Tap a device** to open the native file picker.
5. Select a file — MeshDrop handles chunking, encryption, and transfer automatically.
6. The receiver sees an **Accept / Reject dialog** with the file name and size.
7. Once accepted, the encrypted transfer streams chunk-by-chunk with real-time progress updates.

### Pairing Devices

1. Navigate to the **Devices** screen (`/devices` route).
2. Under "Nearby", tap **Pair** next to the target device.
3. An X25519 key exchange runs over TCP port 58433.
4. Both devices display the same **6-digit confirmation code**.
5. Verify the codes match visually, then tap **Codes Match**.
6. The device is now trusted — its public key is stored in platform-secure storage.

### Settings

Access the **Settings** screen (`/settings` route) to configure:

- **Download Directory**: Where received files are saved (defaults to the system Documents directory).
- **Auto-Accept**: When enabled, incoming transfers are accepted without prompting.
- **Chunk Size**: Transfer chunk size (32 KB / 64 KB / 128 KB / 256 KB). Larger chunks improve throughput on reliable networks; smaller chunks provide better progress granularity.
- **Clear Trusted Devices**: Removes all pairing records. Previously paired devices will need to re-pair.

---

## Configuration

Settings are persisted to `SharedPreferences` under the key `meshdrop_app_settings` and loaded at app startup before the widget tree mounts.

| Setting | Type | Default | Description |
|---|---|---|---|
| `downloadDirectory` | `String` | System Documents dir | Target directory for received files |
| `chunkSizeBytes` | `int` | `65536` (64 KB) | Size of each transfer chunk in bytes |
| `autoAccept` | `bool` | `false` | Auto-accept incoming transfers |

> 📖 See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for advanced configuration details.

---

## Documentation

| Document | Description |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) | Layered architecture, design patterns, dependency graph, data flow diagrams |
| [Protocols](docs/PROTOCOLS.md) | Wire protocol specifications for pairing and transfer (byte-level format) |
| [Security](docs/SECURITY.md) | Cryptographic model, key lifecycle, threat analysis, security properties |
| [API Reference](docs/API_REFERENCE.md) | Complete class and method reference for all modules |
| [Configuration](docs/CONFIGURATION.md) | Settings persistence, platform storage backends, tuning guide |
| [Contributing](docs/CONTRIBUTING.md) | Development workflow, code style, testing, PR guidelines |

---

## Dependencies

### Runtime Dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^2.6.1 | State management |
| `riverpod_annotation` | ^2.6.1 | Riverpod code generation annotations |
| `flutter_secure_storage` | ^9.2.4 | Platform-native secure key storage |
| `cryptography` | ^2.7.0 | X25519, Ed25519, ChaCha20-Poly1305 |
| `nsd` | ^5.0.1 | mDNS/DNS-SD discovery |
| `flutter_local_notifications` | ^18.0.1 | Native OS transfer notifications |
| `path_provider` | ^2.1.5 | Platform-specific directories |
| `uuid` | ^4.5.1 | Unique transfer/session/chunk identifiers |
| `crypto` | ^3.0.6 | SHA-256 integrity checksums |
| `path` | ^1.9.0 | File path utilities |
| `file_picker` | ^8.1.2 | Native file/directory picker |
| `shared_preferences` | ^2.3.2 | Settings and transfer history persistence |

### Dev Dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter_test` | SDK | Widget and unit testing |
| `flutter_lints` | ^6.0.0 | Recommended lint rules |
| `build_runner` | ^2.4.14 | Code generation runner |
| `riverpod_generator` | ^2.6.2 | Riverpod provider code generation |

---

## Testing

```bash
# Run widget tests
flutter test

# Run a specific test
flutter test test/widget_test.dart

# Manual transfer testing (localhost)
dart run test_sender.dart
```

The `test_sender.dart` script simulates a transfer client connecting to `127.0.0.1:58432` using the MeshDrop wire protocol, useful for validating the receive server without a second device.

---

## License

This project is proprietary software. All rights reserved.