import Foundation
import ScreenCaptureKit
import CoreGraphics

#if canImport(AppKit)
import AppKit
#endif

/// Centralises the host's two critical permissions: **Screen Recording** and
/// **Accessibility**. Microphone (optional audio) is handled in a later phase.
public final class PermissionsManager {
    public init() {}

    /// Ensure Screen Recording is granted. Querying shareable content triggers the
    /// system prompt on first use; if still denied we throw so the UI can guide the user.
    public func ensureScreenRecording() async throws {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true)
        } catch {
            throw PermissionError.screenRecordingDenied
        }
    }

    /// Accessibility cannot be requested programmatically. We check the trust state and,
    /// if needed, prompt the system dialog that deep-links to System Settings.
    /// - Returns: true if already trusted.
    @discardableResult
    public func ensureAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    public var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    /// Open the relevant System Settings pane for the user.
    public func openAccessibilitySettings() {
#if canImport(AppKit)
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
#endif
    }
}

public enum PermissionError: Error, LocalizedError {
    case screenRecordingDenied
    public var errorDescription: String? {
        switch self {
        case .screenRecordingDenied:
            return "Screen Recording permission is required. Enable it in System Settings › Privacy & Security › Screen Recording, then relaunch."
        }
    }
}
