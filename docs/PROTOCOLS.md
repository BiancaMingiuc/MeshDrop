# Wire Protocol Specification

This document defines the binary wire protocols used by MeshDrop for device pairing and file transfer. Both protocols operate over raw TCP sockets with big-endian byte order.

---

## Table of Contents

- [Overview](#overview)
- [Network Ports](#network-ports)
- [Pairing Protocol (MSHP)](#pairing-protocol-mshp)
- [Transfer Protocol (MSHD)](#transfer-protocol-mshd)
- [Encrypted Chunk Framing](#encrypted-chunk-framing)
- [Encryption Wire Format](#encryption-wire-format)
- [Error Handling](#error-handling)

---

## Overview

MeshDrop uses two distinct binary protocols:

| Protocol | Magic | Port | Purpose |
|---|---|---|---|
| **MSHP** (MeshDrop Pairing) | `0x4D534850` | 58433 | X25519 public key exchange during device pairing |
| **MSHD** (MeshDrop Data) | `0x4D534844` | 58432 | File transfer request header, accept/reject, and chunk streaming |

Both protocols use **big-endian** byte order for all multi-byte integers and include magic bytes for protocol identification and version validation.

---

## Network Ports

| Port | Protocol | Direction | Description |
|---|---|---|---|
| **58432** | TCP | Bidirectional | File transfer: request headers, accept/reject, encrypted chunks |
| **58433** | TCP | Bidirectional | Device pairing: X25519 key exchange |

Both ports should be allowed through the OS firewall for MeshDrop to function.

---

## Pairing Protocol (MSHP)

The pairing protocol exchanges X25519 public keys between two devices to establish a shared secret for the pairing confirmation code.

### Wire Format

Both the initiator and receiver send the same message structure:

```
┌──────────────────────────────────────────────────────────────┐
│ Offset │ Size    │ Field                │ Description        │
├────────┼─────────┼──────────────────────┼────────────────────┤
│ 0      │ 4 bytes │ Magic                │ 0x4D534850 "MSHP"  │
│ 4      │ 4 bytes │ Public Key Length     │ int32, big-endian  │
│ 8      │ N bytes │ X25519 Public Key    │ Raw key bytes      │
└──────────────────────────────────────────────────────────────┘
```

**Total message size**: `8 + N` bytes (typically `8 + 32 = 40` bytes for X25519).

### Validation Rules

- Magic bytes must be exactly `0x4D534850`. If the magic does not match, the message is discarded and `null` is returned.
- Public key length must be in the range `1..256` bytes (sanity check).
- X25519 public keys are always 32 bytes.

### Sequence Diagram

```
    Initiator                         Receiver
       │                                 │
       │  Socket.connect(:58433)         │
       │ ───────────────────────────────►│
       │                                 │
       │  [MSHP][len][public_key]        │
       │ ───────────────────────────────►│  ← Initiator sends first
       │                                 │
       │  [MSHP][len][public_key]        │
       │ ◄───────────────────────────────│  ← Receiver responds
       │                                 │
       │  (both derive shared secret)    │
       │  (both display 6-digit code)    │
       │                                 │
       │  socket.destroy()               │
       │ ───────────────────────────────►│
       │                                 │
```

### Confirmation Code Derivation

After the key exchange, both sides derive the same shared secret via `X25519.sharedSecretKey()`. The 6-digit confirmation code is then derived deterministically:

```
code = 0
for i in 0..3:
    code = (code * 256 + secret[i]) % 1_000_000
return code.toString().padLeft(6, '0')
```

This produces a string like `"042851"`. Both devices display this code simultaneously. The user verifies they match visually.

---

## Transfer Protocol (MSHD)

The transfer protocol handles the request/response handshake before any file data is sent.

### Transfer Request (Sender → Receiver)

```
┌──────────────────────────────────────────────────────────────────────────┐
│ Offset │ Size    │ Field                │ Description                   │
├────────┼─────────┼──────────────────────┼───────────────────────────────┤
│ 0      │ 4 bytes │ Magic                │ 0x4D534844 "MSHD"             │
│ 4      │ 4 bytes │ Sender Name Length   │ int32, big-endian              │
│ 8      │ S bytes │ Sender Name          │ UTF-8 encoded device name      │
│ 8+S    │ 4 bytes │ File Name Length     │ int32, big-endian              │
│ 12+S   │ F bytes │ File Name            │ UTF-8 encoded file name        │
│ 12+S+F │ 8 bytes │ File Size            │ int64, big-endian (bytes)      │
│ 20+S+F │ 32 bytes│ Sender Public Key    │ X25519 ephemeral public key    │
└──────────────────────────────────────────────────────────────────────────┘
```

**Total message size**: `52 + S + F` bytes (variable, depending on name lengths).

### Transfer Response (Receiver → Sender)

#### Accept

```
┌──────────────────────────────────────────────────────┐
│ Offset │ Size     │ Field              │ Description │
├────────┼──────────┼────────────────────┼─────────────┤
│ 0      │ 1 byte   │ Status             │ 0x01        │
│ 1      │ 32 bytes │ Receiver Public Key│ X25519 key  │
└──────────────────────────────────────────────────────┘
```

**Total**: 33 bytes.

#### Reject

```
┌──────────────────────────────────────────────────────┐
│ Offset │ Size     │ Field              │ Description │
├────────┼──────────┼────────────────────┼─────────────┤
│ 0      │ 1 byte   │ Status             │ 0x00        │
└──────────────────────────────────────────────────────┘
```

**Total**: 1 byte.

### Sequence Diagram

```
    Sender                              Receiver
       │                                   │
       │  Socket.connect(:58432)           │
       │ ─────────────────────────────────►│
       │                                   │
       │  [MSHD header + public key]       │
       │ ─────────────────────────────────►│  ← Transfer request
       │                                   │
       │                                   │  onIncomingRequest → UI dialog
       │                                   │
       │  [0x01][receiver public key]      │
       │ ◄─────────────────────────────────│  ← Accept + key exchange
       │     OR                            │
       │  [0x00]                           │
       │ ◄─────────────────────────────────│  ← Reject
       │                                   │
       │  (both derive shared secret)      │
       │  (both create EncryptionSession)  │
       │                                   │
       │  [encrypted chunk stream...]      │
       │ ─────────────────────────────────►│
       │                                   │
       │  socket.destroy()                 │
       │ ─────────────────────────────────►│
```

---

## Encrypted Chunk Framing

After the handshake, file data is sent as a sequence of length-prefixed encrypted chunks:

```
┌───────────────────────────────────────────────────────────────┐
│ Repeat for each chunk:                                        │
├──────────────────────────────────────────────────────────────┤
│ Offset │ Size    │ Field            │ Description             │
├────────┼─────────┼──────────────────┼─────────────────────────┤
│ 0      │ 4 bytes │ Chunk Length     │ int32, big-endian       │
│        │         │                  │ (size of encrypted blob)│
│ 4      │ L bytes │ Encrypted Blob   │ See "Encryption Wire   │
│        │         │                  │  Format" below          │
└──────────────────────────────────────────────────────────────┘
```

The receiver reads `[4-byte length]` then reads exactly that many bytes as the encrypted payload. This repeats until the total decrypted bytes equal the file size declared in the request header.

### Chunk Size

The default plaintext chunk size is **65,536 bytes (64 KB)**. This is configurable via the `AppSettings.chunkSizeBytes` field (valid options: 32 KB, 64 KB, 128 KB, 256 KB).

The encrypted chunk is slightly larger than the plaintext due to the prepended nonce (12 bytes) and appended authentication tag (16 bytes).

**Encrypted chunk size** = `12 + plaintext_size + 16` bytes.

For the default 64 KB plaintext:
- Encrypted chunk size: `12 + 65,536 + 16 = 65,564 bytes`
- Length prefix value: `65,564` (written as big-endian int32)

---

## Encryption Wire Format

Each encrypted chunk is a self-contained blob with the following structure:

```
┌──────────────────────────────────────────────────────────┐
│ Offset │ Size     │ Field            │ Description       │
├────────┼──────────┼──────────────────┼───────────────────┤
│ 0      │ 12 bytes │ Nonce            │ Random per-chunk  │
│ 12     │ P bytes  │ Ciphertext       │ ChaCha20 output   │
│ 12+P   │ 16 bytes │ MAC (Poly1305)   │ Authentication tag│
└──────────────────────────────────────────────────────────┘
```

**Total**: `12 + P + 16` bytes, where `P` is the plaintext chunk size.

### Security Properties

- **Nonce**: A fresh 12-byte cryptographically random nonce is generated for every chunk. The nonce is prepended to the ciphertext so the receiver can decrypt without maintaining nonce synchronization state.
- **AEAD**: ChaCha20-Poly1305 provides both confidentiality (encryption) and integrity (authentication tag). Any modification to the nonce, ciphertext, or tag will cause decryption to fail.
- **Forward Secrecy**: Ephemeral X25519 key pairs are generated per-transfer. Compromise of a device's long-term Ed25519 key does not reveal past transfer contents.

---

## Error Handling

### Connection Errors

| Scenario | Behavior |
|---|---|
| Target device offline | `Socket.connect` times out after 5 seconds; `SocketException` thrown |
| Port 58432 in use | `ServerSocket.bind` throws; logged and continued |
| Socket closed mid-transfer | `SocketReader.read()` throws `StateError('Socket closed')` |

### Protocol Errors

| Scenario | Behavior |
|---|---|
| Invalid magic bytes | `readRequest()` / `readPublicKey()` returns `null` |
| Key length out of range | `readPublicKey()` returns `null` (sanity: 1..256 bytes) |
| Public key ≠ 32 bytes | Assertion failure in `sendRequest()` / `sendAccept()` |
| Decryption failure | `Chacha20.poly1305Aead().decrypt()` throws (AEAD tag mismatch) |

### Transfer Error Recovery

| Scenario | Behavior |
|---|---|
| Send fails mid-transfer | `TransferStatus.failed` set; notification shown; exception rethrown |
| Receive fails mid-transfer | Partial file remains on disk; `TransferStatus.failed` notification |
| File name conflict | Auto-renamed: `file.txt` → `file (1).txt` → `file (2).txt` |
