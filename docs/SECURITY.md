# Security Model

This document describes MeshDrop's cryptographic architecture, key lifecycle management, threat model, and security properties.

---

## Table of Contents

- [Cryptographic Overview](#cryptographic-overview)
- [Algorithm Selection](#algorithm-selection)
- [Key Hierarchy](#key-hierarchy)
- [Key Lifecycle](#key-lifecycle)
- [Pairing Security](#pairing-security)
- [Transfer Security](#transfer-security)
- [Secure Storage](#secure-storage)
- [Threat Model](#threat-model)
- [Security Properties](#security-properties)
- [Known Limitations](#known-limitations)

---

## Cryptographic Overview

MeshDrop employs a layered cryptographic architecture with three distinct algorithmic components:

| Layer | Algorithm | Key Type | Lifetime | Purpose |
|---|---|---|---|---|
| **Identity** | Ed25519 | Signing key pair | Permanent (device lifetime) | Proves device identity across sessions |
| **Key Exchange** | X25519 (ECDH) | Exchange key pair | Ephemeral (per-pairing or per-transfer) | Derives shared secrets without transmitting them |
| **Symmetric Encryption** | ChaCha20-Poly1305 | Session key + nonce | Ephemeral (per-transfer) | AEAD encryption of file chunks |
| **Integrity** | SHA-256 | N/A | Per-chunk | Integrity checksums for file chunks |

All cryptographic operations are implemented via the `cryptography` Dart package (version ^2.7.0), which provides constant-time implementations suitable for mobile and desktop platforms.

---

## Algorithm Selection

### ChaCha20-Poly1305 over AES-GCM

MeshDrop uses ChaCha20-Poly1305 AEAD as its symmetric cipher. This choice was made for the following reasons:

1. **No hardware acceleration dependency**: ChaCha20 performs well on devices without AES-NI instruction sets (common on low-end Android devices). AES-GCM performance degrades significantly without hardware support.

2. **AEAD construction**: Poly1305 provides a built-in Message Authentication Code (MAC). Every encrypted chunk is authenticated — any in-transit tampering (bit flips, truncation, injection) is detected during decryption. There is no need for a separate HMAC step.

3. **Nonce misuse resistance**: While nonce reuse is still catastrophic for ChaCha20-Poly1305, the 96-bit nonce space combined with fresh random nonces per chunk makes collision probability negligible (`2^-48` after `2^48` chunks).

4. **Widely audited**: ChaCha20-Poly1305 is used by TLS 1.3, WireGuard, Signal Protocol, and Google's QUIC protocol. It is battle-tested at scale.

### Ed25519 for Identity

Ed25519 provides:
- **Deterministic signatures**: Same input always produces the same signature (no ECDSA nonce hazard).
- **Small keys**: 32-byte public keys, 64-byte signatures.
- **Fast verification**: ~70,000 verifications/second on typical hardware.

### X25519 for Key Exchange

X25519 (Curve25519 Diffie-Hellman) provides:
- **32-byte keys**: Compact for wire transmission.
- **Constant-time operations**: Resistant to timing side-channel attacks.
- **Ephemeral usage**: Fresh key pairs per pairing/transfer ensure forward secrecy.

---

## Key Hierarchy

```
Device Identity (permanent, stored in SecureStorage)
├── Ed25519 Signing Key Pair
│   ├── Private Key → SecureStorage['identity_ed25519_private'] (base64)
│   └── Public Key  → SecureStorage['identity_ed25519_public'] (base64)
│
Pairing Session (ephemeral, per-pairing)
├── X25519 Key Pair (local)
├── X25519 Public Key (remote, received over TCP)
├── Shared Secret (derived via ECDH, never transmitted)
└── Confirmation Code (derived from shared secret)
│
Transfer Session (ephemeral, per-transfer)
├── X25519 Key Pair (local, fresh per transfer)
├── X25519 Public Key (remote, received in accept message)
├── Shared Secret (derived via ECDH)
└── EncryptionSession
    ├── Session ID (UUID v4)
    ├── Session Key (first 32 bytes of shared secret)
    ├── Nonce (12 bytes, random, refreshed per chunk)
    └── isActive flag (invalidated after transfer)
```

---

## Key Lifecycle

### Identity Keys (Ed25519)

```
First Launch:
  AppInitializer.ensureIdentityKeys()
    ├── Check SecureStorage.containsKey('identity_ed25519_private')
    │   └── Key exists → return (no-op)
    │
    └── Key missing (first launch):
        ├── CryptoManager.generateEd25519KeyPair()
        ├── Extract private key bytes → base64 → SecureStorage.write(private)
        └── Extract public key bytes → base64 → SecureStorage.write(public)

Subsequent Launches:
  Keys are loaded from SecureStorage on demand.
  Private key persists until the user clears app data or reinstalls.
```

### Pairing Keys (X25519)

```
Pairing Initiated:
  PairingSession.initiate(device)
    ├── CryptoManager.generateX25519KeyPair() → fresh ephemeral key pair
    ├── Extract public key → send over TCP (port 58433)
    ├── Receive remote public key
    ├── CryptoManager.deriveSharedSecret() → 32-byte shared secret
    ├── Derive 6-digit confirmation code
    ├── User confirms codes match
    └── Persist TrustedDevice (with remote public key) in SecureStorage

Post-Pairing:
  Ephemeral X25519 key pair is garbage collected.
  Only the remote public key is persisted (for future ECDH with trusted device).
```

### Transfer Keys (X25519 + ChaCha20)

```
Transfer Initiated (Sender):
  FileTransferManager.sendFile()
    ├── Generate ephemeral X25519 key pair
    ├── Send public key in transfer request header
    ├── Receive receiver's public key in accept response
    ├── deriveSharedSecret() → 32-byte secret
    ├── createSession(secret) → EncryptionSession
    │     ├── sessionKey = secret[0..31]
    │     └── nonce = 12 random bytes
    ├── Encrypt each chunk with session → nonce refreshed after each
    └── session.invalidate() after transfer completes

Transfer Accepted (Receiver):
  FileTransferManager._handleIncomingConnection()
    ├── Generate ephemeral X25519 key pair
    ├── Send public key in accept response
    ├── Use sender's public key from request header
    ├── deriveSharedSecret() → same 32-byte secret (ECDH commutativity)
    ├── createSession(secret) → EncryptionSession (same key + different nonce)
    ├── Decrypt each chunk
    └── session.invalidate() after transfer completes
```

---

## Pairing Security

### Confirmation Code as MITM Defense

The 6-digit confirmation code is derived deterministically from the ECDH shared secret. Since the shared secret is never transmitted, an attacker performing a Man-in-the-Middle attack would derive a different shared secret (and thus a different confirmation code) on each side. The user detects this by observing mismatched codes.

**Confirmation code entropy**: 6 decimal digits = ~19.93 bits. This provides a `1 / 1,000,000` chance of an attacker guessing the correct code.

### Trusted Device Persistence

After successful pairing:
1. A `TrustedDevice` object is created containing the remote device's public key, name, and pairing date.
2. The object is serialized to JSON and written to `SecureStorage` under key `trusted_<deviceId>`.
3. The device ID is appended to a manifest list stored under key `trusted_device_manifest`.

This allows the app to enumerate trusted devices on startup without needing `readAll()` support from the storage backend.

---

## Transfer Security

### Per-Transfer Key Exchange

Every file transfer performs a fresh X25519 key exchange, even between previously paired devices. This ensures:

1. **Forward secrecy**: Compromise of one transfer's session key does not reveal other transfers.
2. **Session isolation**: Each transfer has its own independent encryption context.
3. **No key reuse**: Ephemeral keys are generated and discarded per-transfer.

### Nonce Management

ChaCha20-Poly1305 requires a unique nonce for every encryption operation under the same key. MeshDrop enforces this by:

1. Generating a 12-byte cryptographically random nonce at session creation.
2. Calling `EncryptionSession.refreshNonce()` after every `encrypt()` call.
3. Prepending the nonce to the ciphertext so the receiver can decrypt without maintaining nonce state.

**Critical invariant**: The nonce is refreshed after *every chunk*. Nonce reuse under the same key would catastrophically compromise the security of ChaCha20-Poly1305 (key-stream XOR recovery).

### Encrypted Chunk Format

```
[12-byte nonce] [ciphertext] [16-byte Poly1305 MAC]
```

The receiver parses the nonce from the first 12 bytes, the MAC from the last 16 bytes, and the ciphertext from the middle. This self-describing format ensures each chunk can be independently decrypted.

---

## Secure Storage

### Platform Backends

| Platform | Backend | Encryption |
|---|---|---|
| **Android** | `EncryptedSharedPreferences` | AES-256-SIV (Android Keystore backed) |
| **iOS** | Keychain Services | Hardware-backed Secure Enclave (when available) |
| **Windows** | Windows Credential Manager | DPAPI encryption |
| **Linux** | libsecret (GNOME Keyring / KWallet) | D-Bus Secret Service API |

### Stored Keys

| Key | Format | Content |
|---|---|---|
| `identity_ed25519_private` | Base64 | Ed25519 private signing key |
| `identity_ed25519_public` | Base64 | Ed25519 public signing key |
| `trusted_<deviceId>` | JSON | TrustedDevice (public key, name, dates) |
| `trusted_device_manifest` | JSON array | List of trusted device IDs |

### Interface Abstraction

All secure storage access goes through the abstract `SecureStorage` interface:

```dart
abstract class SecureStorage {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<bool> containsKey(String key);
}
```

The concrete `FlutterSecureStorageImpl` wraps `flutter_secure_storage` with `encryptedSharedPreferences: true` on Android.

---

## Threat Model

### In-Scope Threats

| Threat | Mitigation |
|---|---|
| **Passive eavesdropping** (network sniffing) | All file data is encrypted with ChaCha20-Poly1305. Only encrypted ciphertext + nonce + MAC traverse the network. |
| **Man-in-the-Middle** (active interception during pairing) | 6-digit confirmation code derived from ECDH shared secret. MITM produces different codes → detected by user. |
| **Data tampering** (bit-flip, truncation, injection) | Poly1305 MAC authentication. Any modification causes decryption to fail (tag mismatch exception). |
| **Replay attacks** | Fresh ephemeral X25519 keys per-transfer. Replayed ciphertext would require the exact same ECDH key pair. |
| **Nonce reuse** | Nonce refreshed after every `encrypt()` call. Random 12-byte nonces from `Random.secure()`. |
| **Key leakage from storage** | Platform-native secure storage (Keychain, Keystore, DPAPI). Keys encrypted at rest. |

### Out-of-Scope Threats

| Threat | Reason |
|---|---|
| **Compromised OS / root access** | If the OS is compromised, secure storage is not reliable on any platform. |
| **Physical device theft** | MeshDrop does not implement device-level authentication (PIN, biometrics). |
| **Denial of service** | No rate limiting on incoming connections or transfer requests. |
| **DNS spoofing / mDNS poisoning** | mDNS operates on the local network; assumes the local network is not hostile. |
| **Large file memory exhaustion (sender)** | `_chunkFile()` reads the entire file into memory before chunking. See Known Limitations. |

---

## Security Properties

| Property | Status | Mechanism |
|---|---|---|
| **Confidentiality** | ✅ | ChaCha20-Poly1305 encryption of all transferred data |
| **Integrity** | ✅ | Poly1305 MAC on every chunk; SHA-256 checksums on `FileChunk` |
| **Authentication** (transfer) | ✅ | Ephemeral ECDH key exchange embedded in protocol |
| **Authentication** (pairing) | ✅ | 6-digit confirmation code from ECDH shared secret |
| **Forward Secrecy** | ✅ | Ephemeral X25519 keys per-transfer; past transfers safe if long-term key compromised |
| **Non-repudiation** | ⚠️ Partial | Ed25519 signing keys exist but are not currently used to sign transfer headers |
| **Replay Protection** | ✅ | Ephemeral keys make replay infeasible |
| **At-rest Encryption** | ✅ | Keys stored in platform-native secure storage |

---

## Known Limitations

1. **Sender Memory Usage**: `FileTransferManager._chunkFile()` calls `file.readAsBytes()` which loads the entire file into memory before chunking. For very large files (> available RAM), this will cause an `OutOfMemoryError`. A streaming chunking approach using `file.openRead()` would resolve this.

2. **No Transfer Authentication**: While transfers use ephemeral ECDH, the sender's identity is not cryptographically verified. The receiver sees a device name (self-reported string) but cannot confirm it's from a specific trusted device. Signing the transfer header with the Ed25519 identity key would add sender authentication.

3. **Confirmation Code Entropy**: The 6-digit code provides ~20 bits of entropy. This is standard for user-facing pairing (matching Bluetooth's Numeric Comparison), but a determined attacker could brute-force it with `10^6` attempts. Increasing to 8 digits would provide ~26.5 bits.

4. **No Certificate Pinning**: The pairing protocol trusts whichever public key it receives over the TCP connection. If an attacker can intercept the TCP connection on the local network (e.g., ARP spoofing), they can perform MITM. The confirmation code is the sole defense.

5. **Session Key Derivation**: The session key is simply the first 32 bytes of the raw ECDH shared secret. A proper key derivation function (HKDF-SHA256) would be more robust, providing domain separation and key diversification.

6. **No Padding**: Chunk sizes reveal plaintext sizes (64 KB boundaries). An observer can determine the approximate file size by counting chunks, even without decryption. This is generally acceptable for file transfer applications.
