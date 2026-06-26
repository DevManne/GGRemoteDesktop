# Architecture

The suite follows **MVVM** with clearly separated modules. Cross-platform logic lives in
the `SharedKit` Swift package; platform code lives in the two app targets.

## Modules

| Module        | Responsibility                                                |
|---------------|---------------------------------------------------------------|
| **Models**    | Domain types + the binary/JSON wire protocol (control msgs).  |
| **Crypto**    | Curve25519 key agreement, ChaCha20-Poly1305 AEAD, HKDF.       |
| **Auth**      | Pairing payloads, trusted-device store, session tokens.       |
| **Capture**   | (Host) ScreenCaptureKit → CMSampleBuffer → RTCVideoFrame.     |
| **Transport** | WebRTC peer connection, data channel, ICE, reconnect.         |
| **Input**     | (Host) CGEvent injection; (Client) gesture→event mapping.     |
| **Discovery** | Bonjour advertise/browse + QR SDP exchange.                   |
| **UI**        | SwiftUI views + ViewModels per platform.                      |

## Data flow (host → client video)

```
SCStream → CMSampleBuffer → RTCVideoFrame → RTCVideoSource
        → RTCPeerConnection (H.264/HEVC) → (network) → RTCVideoTrack → RTCMTLVideoView
```

## Data flow (client → host control)

```
SwiftUI gesture → ControlEvent → encode + AEAD seal → RTCDataChannel
              → (network) → AEAD open + decode → CGEvent injection
```

## Security model

- Pairing establishes a shared secret via Curve25519 ECDH; QR carries the host public
  key + a short authentication string to defend against MITM.
- All control-channel messages are sealed with ChaCha20-Poly1305 using keys derived
  via HKDF from the ECDH secret. Video uses WebRTC's mandatory DTLS-SRTP.
- Trusted devices are persisted (Keychain-backed in later phases) so re-pairing is not
  required on reconnect.
