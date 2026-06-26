# RemoteMacClient (iOS)

The client app scans the host pairing QR, connects over WebRTC, renders the remote Mac
screen, and forwards touch + keyboard input as encrypted control events.

## Modules (MVVM)

| Path             | Responsibility                                                  |
|------------------|-----------------------------------------------------------------|
| `App/`           | App entry point + scene.                                        |
| `ViewModels/`    | `ClientViewModel` orchestrates pairing, transport, input.       |
| `Transport/`     | `WebRTCClientTransport`, `DeviceIdentity` (WebRTC receive + E2EE).|
| `Input/`         | `GestureMapper` (touch → ControlEvent, aspect-aware).           |
| `Scanner/`       | `QRScannerView` (AVFoundation QR capture).                      |
| `Views/`         | `ClientRootView`, `ConnectView`, `ScanView`, `RemoteControlView`, `RemoteVideoView`. |
| `Support/`       | `Info.plist`.                                                   |

## Gesture map

| Gesture                   | Action          |
|---------------------------|-----------------|
| One-finger drag           | Move cursor     |
| One-finger tap            | Left click      |
| Two-finger tap            | Right click     |
| Double tap                | Double click    |
| Long-press + drag         | Drag & drop     |
| Two-finger pan            | Scroll          |
| Keyboard button           | Remote typing   |

## Build notes

- Add the `stasel/WebRTC` SwiftPM package and `SharedKit` (local) to this target.
- Requires a physical device (camera + Metal rendering); the Simulator lacks a camera.
- The answer SDP is returned to the host out-of-band; the automatic return loop
  (Bonjour / reverse QR) lands in Phase 4.
