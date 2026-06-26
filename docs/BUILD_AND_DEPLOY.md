# Build & Deployment Guide

## Build the shared package

```bash
cd SharedKit
swift build
swift test
```

## Build & run the macOS host

1. Open the workspace in Xcode.
2. Select the **RemoteMacHost** scheme → *My Mac*.
3. Build & run. On first launch grant:
   - **Screen Recording** (prompted)
   - **Accessibility** (open System Settings, toggle the app on)
   - **Local Network** (prompted)

## Build & run the iOS client

1. Select the **RemoteMacClient** scheme → your connected device.
2. Set your signing team (`secrets.xcconfig`).
3. Build & run. Grant **Camera** (QR) and **Local Network** when prompted.

## Pairing flow

1. Launch the host – it advertises over Bonjour and shows a pairing QR.
2. On the client, scan the QR to import the host public key + WebRTC offer.
3. The client returns its answer (QR or Bonjour data channel) to complete the handshake.

## Release / distribution

- macOS host is distributed via **Developer ID + notarization** (not the App Store,
  due to disabled sandbox for input injection). Archive → Distribute App → Developer ID.
- iOS client via TestFlight / App Store or ad-hoc.

## Troubleshooting

- **Black screen:** Screen Recording permission missing → re-grant and relaunch.
- **Input ignored:** Accessibility permission missing or app moved after granting.
- **Peers not found:** ensure both devices are on the same subnet; check Local Network
  permission and `NSBonjourServices`.
