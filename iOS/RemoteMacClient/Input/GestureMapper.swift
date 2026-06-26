import Foundation
import CoreGraphics
import SharedKit

/// Converts touch interactions on the remote-screen view into `ControlEvent`s.
///
/// Touch locations arrive in the renderer view's coordinate space and are normalised to
/// `0...1` against the *video content rect* (which respects the host aspect ratio inside
/// the letterboxed view). The mapper is deliberately UI-framework agnostic so it can be
/// unit-tested; SwiftUI gesture handlers call these methods.
public final class GestureMapper {
    /// Emits a mapped control event (wired to the transport by the view model).
    public var onEvent: ((ControlEvent) -> Void)?

    /// Host display aspect ratio (width / height); updated from `HostStatus`.
    public var hostAspectRatio: Double = 16.0 / 10.0

    public init() {}

    // MARK: Pointer (single finger)

    /// Normalise a touch point given the view size, accounting for letterboxing so the
    /// cursor lands on the correct spot regardless of the view's aspect ratio.
    public func normalize(point: CGPoint, in viewSize: CGSize) -> (x: Double, y: Double) {
        let viewAspect = viewSize.width / max(viewSize.height, 1)
        var contentWidth = viewSize.width
        var contentHeight = viewSize.height
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0

        if viewAspect > hostAspectRatio {
            // Pillarboxed: content narrower than the view.
            contentWidth = viewSize.height * hostAspectRatio
            offsetX = (viewSize.width - contentWidth) / 2
        } else {
            // Letterboxed: content shorter than the view.
            contentHeight = viewSize.width / hostAspectRatio
            offsetY = (viewSize.height - contentHeight) / 2
        }
        let x = Double(((point.x - offsetX) / contentWidth).clamped(to: 0...1))
        let y = Double(((point.y - offsetY) / contentHeight).clamped(to: 0...1))
        return (x, y)
    }

    public func move(to point: CGPoint, in size: CGSize) {
        let p = normalize(point: point, in: size)
        onEvent?(.mouseMove(x: p.x, y: p.y))
    }

    /// One-finger tap = left click.
    public func tap(at point: CGPoint, in size: CGSize) {
        let p = normalize(point: point, in: size)
        onEvent?(.click(button: .left, x: p.x, y: p.y))
    }

    /// Two-finger tap = right click.
    public func twoFingerTap(at point: CGPoint, in size: CGSize) {
        let p = normalize(point: point, in: size)
        onEvent?(.click(button: .right, x: p.x, y: p.y))
    }

    public func doubleTap(at point: CGPoint, in size: CGSize) {
        let p = normalize(point: point, in: size)
        onEvent?(.doubleClick(x: p.x, y: p.y))
    }

    // MARK: Drag (long-press + move)

    public func dragBegin(at point: CGPoint, in size: CGSize) {
        let p = normalize(point: point, in: size)
        onEvent?(.dragBegin(x: p.x, y: p.y))
    }
    public func dragMove(to point: CGPoint, in size: CGSize) {
        let p = normalize(point: point, in: size)
        onEvent?(.dragMove(x: p.x, y: p.y))
    }
    public func dragEnd(at point: CGPoint, in size: CGSize) {
        let p = normalize(point: point, in: size)
        onEvent?(.dragEnd(x: p.x, y: p.y))
    }

    // MARK: Scroll (two-finger pan)

    /// Translation deltas (points) from a two-finger pan, forwarded as scroll wheel
    /// movement. The sign is inverted to match natural scrolling on the host.
    public func scroll(translationDelta delta: CGSize) {
        onEvent?(.scroll(dx: Double(-delta.width), dy: Double(-delta.height)))
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
