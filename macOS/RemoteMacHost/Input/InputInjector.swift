import Foundation
import CoreGraphics

#if canImport(AppKit)
import AppKit
#endif

import SharedKit

/// Translates `ControlEvent`s from the client into native macOS input using
/// **CoreGraphics** event injection (the Accessibility-gated `CGEvent` API).
///
/// Normalised `0...1` coordinates are scaled to the main display's pixel geometry.
/// Requires the app to be granted Accessibility permission; otherwise injected events
/// are silently ignored by the system.
public final class InputInjector {
    private let eventSource = CGEventSource(stateID: .combinedSessionState)
    private var dragOrigin: CGPoint?

    public init() {}

    /// Current main-display bounds in pixels, used to denormalise coordinates.
    private var displayBounds: CGRect {
        CGDisplayBounds(CGMainDisplayID())
    }

    private func point(_ x: Double, _ y: Double) -> CGPoint {
        let b = displayBounds
        return CGPoint(x: b.origin.x + CGFloat(x) * b.width,
                       y: b.origin.y + CGFloat(y) * b.height)
    }

    public func inject(_ event: ControlEvent) {
        switch event {
        case let .mouseMove(x, y):
            post(.mouseMoved, at: point(x, y), button: .left)
        case let .mouseDown(button, x, y):
            post(downType(button), at: point(x, y), button: cgButton(button))
        case let .mouseUp(button, x, y):
            post(upType(button), at: point(x, y), button: cgButton(button))
        case let .click(button, x, y):
            let p = point(x, y)
            post(downType(button), at: p, button: cgButton(button))
            post(upType(button), at: p, button: cgButton(button))
        case let .doubleClick(x, y):
            postDoubleClick(at: point(x, y))
        case let .dragBegin(x, y):
            let p = point(x, y); dragOrigin = p
            post(.leftMouseDown, at: p, button: .left)
        case let .dragMove(x, y):
            post(.leftMouseDragged, at: point(x, y), button: .left)
        case let .dragEnd(x, y):
            post(.leftMouseUp, at: point(x, y), button: .left)
            dragOrigin = nil
        case let .scroll(dx, dy):
            postScroll(dx: dx, dy: dy)
        case let .keyDown(keyCode, modifiers):
            postKey(keyCode, down: true, modifiers: modifiers)
        case let .keyUp(keyCode, modifiers):
            postKey(keyCode, down: false, modifiers: modifiers)
        case let .text(string):
            postText(string)
        }
    }

    // MARK: Mouse helpers

    private func cgButton(_ b: ControlEvent.MouseButton) -> CGMouseButton {
        switch b {
        case .left: return .left
        case .right: return .right
        case .center: return .center
        }
    }
    private func downType(_ b: ControlEvent.MouseButton) -> CGEventType {
        switch b {
        case .left: return .leftMouseDown
        case .right: return .rightMouseDown
        case .center: return .otherMouseDown
        }
    }
    private func upType(_ b: ControlEvent.MouseButton) -> CGEventType {
        switch b {
        case .left: return .leftMouseUp
        case .right: return .rightMouseUp
        case .center: return .otherMouseUp
        }
    }

    private func post(_ type: CGEventType, at point: CGPoint, button: CGMouseButton) {
        guard let event = CGEvent(mouseEventSource: eventSource, mouseType: type,
                                  mouseCursorPosition: point, mouseButton: button) else { return }
        event.post(tap: .cghidEventTap)
    }

    private func postDoubleClick(at point: CGPoint) {
        guard let down = CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseDown,
                                 mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseUp,
                               mouseCursorPosition: point, mouseButton: .left) else { return }
        for click in 1...2 {
            down.setIntegerValueField(.mouseEventClickState, value: Int64(click))
            up.setIntegerValueField(.mouseEventClickState, value: Int64(click))
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    private func postScroll(dx: Double, dy: Double) {
        guard let event = CGEvent(scrollWheelEvent2Source: eventSource, units: .pixel,
                                  wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx),
                                  wheel3: 0) else { return }
        event.post(tap: .cghidEventTap)
    }

    // MARK: Keyboard helpers

    private func postKey(_ keyCode: UInt16, down: Bool, modifiers: KeyModifiers) {
        guard let event = CGEvent(keyboardEventSource: eventSource,
                                  virtualKey: CGKeyCode(keyCode), keyDown: down) else { return }
        event.flags = cgFlags(modifiers)
        event.post(tap: .cghidEventTap)
    }

    private func cgFlags(_ m: KeyModifiers) -> CGEventFlags {
        var flags = CGEventFlags()
        if m.contains(.shift) { flags.insert(.maskShift) }
        if m.contains(.control) { flags.insert(.maskControl) }
        if m.contains(.option) { flags.insert(.maskAlternate) }
        if m.contains(.command) { flags.insert(.maskCommand) }
        if m.contains(.capsLock) { flags.insert(.maskAlphaShift) }
        return flags
    }

    /// Inject arbitrary Unicode text by setting the event's unicode string. This avoids
    /// keycode/layout mapping for ordinary typing from the iOS keyboard.
    private func postText(_ string: String) {
        for scalarChunk in string.unicodeScalars {
            let utf16 = Array(String(scalarChunk).utf16)
            guard let down = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false)
            else { continue }
            down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }
}
