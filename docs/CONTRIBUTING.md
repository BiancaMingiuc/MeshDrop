# Contributing to MeshDrop

Thank you for your interest in contributing to MeshDrop! This guide covers the development workflow, code organization, coding standards, and how to submit changes.

---

## Table of Contents

- [Development Environment](#development-environment)
- [Project Structure](#project-structure)
- [Code Style](#code-style)
- [Architecture Guidelines](#architecture-guidelines)
- [Adding a New Feature](#adding-a-new-feature)
- [Adding a New Platform Adapter](#adding-a-new-platform-adapter)
- [Testing](#testing)
- [Pull Request Guidelines](#pull-request-guidelines)
- [Common Tasks](#common-tasks)

---

## Development Environment

### Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Flutter SDK | ≥ 3.11.5 | Stable channel |
| Dart SDK | ≥ 3.11.5 | Bundled with Flutter |
| Git | Latest | Version control |
| IDE | VS Code or Android Studio | With Flutter/Dart extensions |

### Setup

```bash
# Clone the repository
git clone https://github.com/your-org/meshdrop.git
cd meshdrop

# Install dependencies
flutter pub get

# Verify setup
flutter doctor
flutter analyze
```

### Running

```bash
# Run on Windows (primary development target)
flutter run -d windows

# Run on Android
flutter run -d android

# Run on iOS
flutter run -d ios

# Run on Linux
flutter run -d linux
```

---

## Project Structure

```
lib/
├── core/           # App-wide configuration and bootstrap
├── features/       # Business logic, organized by feature domain
│   ├── discovery/  # mDNS peer discovery
│   ├── encryption/ # Cryptographic operations
│   ├── pairing/    # Device pairing and trust management
│   └── transfer/   # File transfer protocol and management
├── state/          # Riverpod providers and state notifiers
├── ui/             # Flutter widgets and screens
└── main.dart       # Entry point
```

### Key principles

- **Features are self-contained**: Each feature module under `lib/features/` should encapsulate its own models, adapters, protocols, and business logic.
- **State bridges features to UI**: The `lib/state/` layer creates providers that instantiate feature-layer objects and wire their callbacks into Riverpod notifiers.
- **UI is declarative**: Screens watch Riverpod providers and rebuild reactively. Business logic stays in the features layer.

For the full architectural overview, see [docs/ARCHITECTURE.md](ARCHITECTURE.md).

---

## Code Style

### General Rules

- Follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) style guide.
- The project uses `flutter_lints` (`package:flutter_lints/flutter.yaml`) for static analysis.
- Run `flutter analyze` before submitting changes — there should be zero warnings.

### Naming Conventions

| Entity | Convention | Example |
|---|---|---|
| Files | `snake_case.dart` | `file_transfer_manager.dart` |
| Classes | `PascalCase` | `FileTransferManager` |
| Methods | `camelCase` | `startReceiveServer()` |
| Constants | `camelCase` or `_camelCase` | `_port`, `pairingPort` |
| Providers | `camelCaseProvider` | `transferManagerProvider` |
| Enums | `PascalCase` with `camelCase` values | `TransferStatus.inProgress` |
| Private members | `_camelCase` | `_serverSocket`, `_handleIncomingConnection` |

### File Organization

Each Dart file should follow this order:

1. File-level comment (purpose and key details)
2. Imports (dart:, package:, relative — separated by blank lines)
3. Constants
4. Main class
5. Helper classes (private, prefixed with `_`)

### Documentation Comments

- **Public APIs**: Every public class, method, and field should have a `///` doc comment.
- **Private methods**: Use `//` comments for non-obvious logic.
- **File headers**: Start each file with a `//` block explaining the file's purpose, design decisions, and relationships.

Example:

```dart
// features/transfer/transfer_queue.dart
// Manages the ordered list of pending and active transfers.
// Composed inside FileTransferManager (lifecycle-bound).

/// Enqueues a new transfer. Does not start the transfer — that is
/// managed by [FileTransferManager].
void enqueue(TransferEntry entry) => _queue.add(entry);
```

---

## Architecture Guidelines

### Layer Dependencies

```
UI → State → Features → Core
         ↘ Models ↗
```

- **UI** may import from **State** and **Feature models** (for types used in dialogs).
- **State** may import from **Features** and **Core**.
- **Features** may import from other **Features** and **Core**.
- **Core** has no dependencies on other layers.

**Never** import UI or State from the Features layer.

### Adding Callbacks vs. Direct Dependencies

Feature-layer classes should expose callbacks rather than depending on Riverpod:

```dart
// ✅ Good: callback hook
class FileTransferManager {
  void Function(TransferEntry entry)? onTransferUpdated;
}

// ❌ Bad: direct Riverpod dependency in feature layer
class FileTransferManager {
  final Ref _ref;  // Don't do this
}
```

### Immutable Models

State models should be immutable with `copyWith()`:

```dart
// ✅ Good: immutable with copyWith
class DeviceState {
  final List<Device> discoveredDevices;
  const DeviceState({this.discoveredDevices = const []});
  DeviceState copyWith({List<Device>? discoveredDevices}) { ... }
}

// ❌ Bad: mutable state
class DeviceState {
  List<Device> discoveredDevices = [];  // Don't mutate directly
}
```

---

## Adding a New Feature

When adding a new feature (e.g., file compression, bandwidth throttling):

1. **Create a feature directory**: `lib/features/your_feature/`
2. **Define models**: `lib/features/your_feature/models/`
3. **Implement business logic**: Pure Dart, no Flutter dependencies.
4. **Expose callbacks**: For events the state layer needs to react to.
5. **Create a provider**: `lib/state/your_feature_provider.dart` that instantiates the feature and wires callbacks.
6. **Update UI**: Watch the provider from the relevant screen.
7. **Add tests**: `test/your_feature_test.dart`.
8. **Update documentation**: Add to API Reference and Architecture docs.

---

## Adding a New Platform Adapter

MeshDrop's discovery system uses the Adapter pattern. To add support for a new platform:

1. **Create the adapter**: `lib/features/discovery/adapters/new_platform_adapter.dart`

```dart
class NewPlatformAdapter extends DiscoveryAdapter {
  @override String get serviceName => 'MeshDrop-$_deviceName';
  @override String get serviceType => '_meshdrop._tcp';

  @override Future<void> advertise() async { ... }
  @override Future<void> stopAdvertise() async { ... }
  @override Future<void> browse() async { ... }
  @override Future<void> stopBrowse() async { ... }
}
```

2. **Register in the factory**: Update `_makeAdapter()` in `lib/state/discovery_provider.dart`:

```dart
DiscoveryAdapter _makeAdapter() {
  if (Platform.isNewPlatform) {
    return NewPlatformAdapter(deviceName: deviceName, port: port);
  }
  // ... existing platform checks
}
```

3. **Add the platform type**: Update `PlatformType` enum in `lib/features/discovery/models/platform_type.dart`.

4. **Test**: Verify discovery works on the new platform.

No changes to `DeviceDiscoveryManager`, the state layer, or the UI should be necessary.

---

## Testing

### Running Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/widget_test.dart

# With coverage
flutter test --coverage
```

### Test Categories

| Category | Location | Purpose |
|---|---|---|
| Widget tests | `test/` | UI rendering and interaction |
| Manual test scripts | `test_sender.dart` | Protocol-level testing |
| Smoke test | `test/widget_test.dart` | Verifies HomeScreen renders |

### Manual Protocol Testing

The `test_sender.dart` script simulates a transfer client:

```bash
# Start MeshDrop first (flutter run), then in another terminal:
dart run test_sender.dart
```

This connects to `127.0.0.1:58432`, sends a MSHD protocol header, and waits for Accept/Reject. Useful for validating the receive server without a second device.

### Writing Tests

- Use `ProviderScope` for widget tests that depend on Riverpod providers.
- Mock `SecureStorage` and `CryptoManager` for unit tests (they implement abstract interfaces).
- Use `SocketReader` in integration tests to simulate protocol exchanges.

---

## Pull Request Guidelines

### Before Submitting

- [ ] Run `flutter analyze` — zero warnings
- [ ] Run `flutter test` — all tests pass
- [ ] Update documentation if API surface changed
- [ ] Add/update file-level comments for new/modified files
- [ ] Follow the naming conventions above

### PR Description Template

```markdown
## What
Brief description of the change.

## Why
Motivation and context.

## How
Technical approach and key decisions.

## Testing
How was this tested? Manual steps, new tests, etc.

## Breaking Changes
List any breaking changes to the API or wire protocol.
```

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add bandwidth throttling to FileTransferManager
fix: prevent nonce reuse when transfer is paused and resumed
docs: update PROTOCOLS.md with new chunk header format
refactor: extract _chunkFile into standalone ChunkBuilder class
test: add unit tests for TransferQueue
```

---

## Common Tasks

### Regenerate Riverpod Code

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Update Dependencies

```bash
flutter pub upgrade
flutter pub outdated   # Check for available updates
```

### Check Code Quality

```bash
flutter analyze
dart format lib/ --set-exit-if-changed
```

### Build for Release

```bash
# Windows
flutter build windows --release

# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```
