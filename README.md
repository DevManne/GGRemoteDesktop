# RemoteMac

A macOS + iOS remote-control suite (similar to Macky): stream your Mac screen to an
iPhone/iPad over low-latency **WebRTC** and control the Mac with touch, gestures and a
remote keyboard.

> **Status:** Phase 1 of 4 (foundation). See the roadmap below. The capture,
> transport, input-injection and UI layers land in subsequent phases.

## Highlights

- **macOS host** (Swift + SwiftUI): screen capture via **ScreenCaptureKit**, input
  injection via **Accessibility / CGEvent**.
- **iOS client** (SwiftUI): renders the remote screen and maps multi-touch gestures to
  mouse/keyboard events.
- **WebRTC** peer-to-peer media + data channel (H.264 / HEVC).
- **No signaling server.** The WebRTC offer/answer (SDP) is exchanged via **QR codes**,
  and peers are discovered on the LAN with **Bonjour**.
- **End-to-end encryption**: Curve25519 key agreement + ChaCha20-Poly1305 for the
  control channel; pairing secrets shown as QR.
- **Trusted-device management**, latency monitoring, automatic reconnect.
- **MVVM** architecture with networking, capture, input, auth and UI as separate modules.

## Repository layout

```
.
├─ README.md
├─ docs/                      # setup, build & deployment, architecture
├─ SharedKit/                 # Swift package shared by both apps
│  └─ Sources/SharedKit/
│     ├─ Models/             # domain models, wire protocol
│     ├─ Crypto/             # E2EE key agreement + AEAD
│     └─ Auth/               # pairing payload + trusted-device store
├─ macOS/RemoteMacHost/       # SwiftUI macOS host app (Phase 2)
└─ iOS/RemoteMacClient/       # SwiftUI iOS client app (Phase 3)
```

## Compatibility

- macOS 14+ (Sonoma), Xcode 15+
- iOS 17+

## Quick start

1. Read [`docs/SETUP.md`](docs/SETUP.md) to add the WebRTC binary and configure signing.
2. Read [`docs/BUILD_AND_DEPLOY.md`](docs/BUILD_AND_DEPLOY.md) to build and run.
3. Architecture details in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Generating the Xcode project

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
export DEVELOPMENT_TEAM=XXXXXXXXXX   # your Apple Developer team id
xcodegen generate                   # produces RemoteMac.xcodeproj
open RemoteMac.xcodeproj
```

Xcode resolves the `stasel/WebRTC` and local `SharedKit` packages automatically.

## End-to-end run

1. Build & run **RemoteMacHost** on the Mac; grant Screen Recording + Accessibility.
2. The host advertises over Bonjour and shows a pairing QR + verification code.
3. Build & run **RemoteMacClient** on an iPhone/iPad on the same Wi-Fi; tap *Scan*.
4. Scan the QR. The client connects, returns its answer over Bonjour, and the live
   screen appears. Verify the 6-digit code matches on both devices.

## Roadmap

- [x] **Phase 1** – Foundation: structure, docs, shared models, crypto & auth.
- [x] **Phase 2** – macOS host: ScreenCaptureKit capture, WebRTC sender, input injection.
- [x] **Phase 3** – iOS client: WebRTC receiver/renderer, touch→input mapping, QR scanner.
- [x] **Phase 4** – Pairing & discovery: QR exchange, Bonjour, reconnect, Keychain, workspace.

## License

MIT (see project owner).
