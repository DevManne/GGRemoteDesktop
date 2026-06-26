import Foundation

/// A single input action sent from the client to the host over the encrypted data
/// channel. The host translates each case into a `CGEvent` (Phase 2).
///
/// Coordinates are **normalised** to `0...1` relative to the streamed display so the
/// mapping is resolution-independent; the host scales them to physical pixels.
public enum ControlEvent: Codable, Sendable, Equatable {
    case mouseMove(x: Double, y: Double)
    case mouseDown(button: MouseButton, x: Double, y: Double)
    case mouseUp(button: MouseButton, x: Double, y: Double)
    case click(button: MouseButton, x: Double, y: Double)
    case doubleClick(x: Double, y: Double)
    case dragBegin(x: Double, y: Double)
    case dragMove(x: Double, y: Double)
    case dragEnd(x: Double, y: Double)
    case scroll(dx: Double, dy: Double)
    case keyDown(keyCode: UInt16, modifiers: KeyModifiers)
    case keyUp(keyCode: UInt16, modifiers: KeyModifiers)
    /// Unicode text entry (e.g. from the iOS keyboard) injected as keystrokes.
    case text(String)

    public enum MouseButton: String, Codable, Sendable {
        case left, right, center
    }
}

/// Bit flags for keyboard modifier keys, mirroring `CGEventFlags` semantics.
public struct KeyModifiers: OptionSet, Codable, Sendable, Equatable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let shift   = KeyModifiers(rawValue: 1 << 0)
    public static let control = KeyModifiers(rawValue: 1 << 1)
    public static let option  = KeyModifiers(rawValue: 1 << 2)
    public static let command = KeyModifiers(rawValue: 1 << 3)
    public static let capsLock = KeyModifiers(rawValue: 1 << 4)
}
