# RemoteMacHost (macOS)

The host app captures this Mac's screen, streams it over WebRTC, and injects the remote
input received from the paired iOS client.

## Modules (MVVM)

| Path                       | Responsibility                                            |
|----------------------------|-----------------------------------------------------------|
| `App/`                     | App entry point + scene.                                  |
| `ViewModels/`              | `HostViewModel` orchestrates services, exposes UI state.  |
| `Capture/`                 | `ScreenCaptureService` (ScreenCaptureKit → frames).       |
| `Transport/`               | `WebRTCHostTransport`, `DeviceIdentity` (WebRTC + E2EE).  |
| `Input/`                   | `InputInjector` (CGEvent mouse/keyboard/scroll/text).     |
| `Permissions/`             | `PermissionsManager` (screen recording + accessibility).  |
| `Views/`                   | SwiftUI `HostView`, `PairingQRView`.                      |
| `Support/`                 | `Info.plist`, entitlements.                               |

## Build notes

- Add the `stasel/WebRTC` SwiftPM package and link it to this target (docs/SETUP.md).
- Add `SharedKit` (local package) as a dependency.
- **Disable App Sandbox** (see entitlements) and grant Accessibility at first run.
- The Xcode project/workspace file is generated locally; this phase delivers source +
  configuration. A project generator config lands with the workspace in Phase 4.
