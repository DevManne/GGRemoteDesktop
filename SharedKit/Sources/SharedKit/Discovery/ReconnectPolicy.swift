import Foundation

/// Computes exponential-backoff delays for automatic reconnection after a dropped
/// connection. Pure value type so it is trivially unit-testable.
public struct ReconnectPolicy: Sendable {
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let maxAttempts: Int
    private(set) public var attempt: Int = 0

    public init(baseDelay: TimeInterval = 0.5, maxDelay: TimeInterval = 8, maxAttempts: Int = 10) {
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.maxAttempts = maxAttempts
    }

    /// Next delay, or `nil` once `maxAttempts` is exhausted. Advances the attempt count.
    public mutating func nextDelay() -> TimeInterval? {
        guard attempt < maxAttempts else { return nil }
        let delay = min(maxDelay, baseDelay * pow(2, Double(attempt)))
        attempt += 1
        return delay
    }

    public mutating func reset() { attempt = 0 }
}
