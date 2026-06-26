# Setup

This project does **not** vendor the large WebRTC binary. You add it via Swift Package
Manager during setup.

## 1. Prerequisites

- macOS 14+ and Xcode 15+
- An Apple Developer account (for device deployment / Accessibility entitlements)
- A physical iPhone/iPad on **the same Wi-Fi network** as the Mac (Bonjour discovery)

## 2. Add the WebRTC dependency

We use the prebuilt binary from [`stasel/WebRTC`](https://github.com/stasel/WebRTC).

In each app target (macOS host and iOS client), add the package dependency:

```
https://github.com/stasel/WebRTC.git
```

Use the **Up to Next Major** rule from `120.0.0`. Xcode resolves and downloads the
`WebRTC.xcframework` automatically; do **not** commit it (see `.gitignore`).

## 3. Required Info.plist keys

**macOS host** (`RemoteMacHost`):

- `NSScreenCaptureUsageDescription` – screen recording permission prompt
- `NSMicrophoneUsageDescription` – optional audio
- `NSLocalNetworkUsageDescription` + `NSBonjourServices` (`_remotemac._tcp`)

Accessibility permission is granted at runtime by the user in
*System Settings › Privacy & Security › Accessibility* (cannot be requested via API).

**iOS client** (`RemoteMacClient`):

- `NSCameraUsageDescription` – QR code scanning
- `NSLocalNetworkUsageDescription` + `NSBonjourServices` (`_remotemac._tcp`)

## 4. Entitlements

- macOS host: **App Sandbox must be OFF** for `CGEvent` injection + Accessibility.
  Enable *Hardened Runtime*; not eligible for Mac App Store distribution.
- Both: Network client/server entitlements as needed.

## 5. Signing

Copy `secrets.xcconfig.example` to `secrets.xcconfig` and set your `DEVELOPMENT_TEAM`.
`secrets.xcconfig` is git-ignored.
