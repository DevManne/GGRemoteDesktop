import Foundation

/// Top-level envelope exchanged over the WebRTC **data channel**.
///
/// Every payload that travels on the control channel is wrapped in a `WireMessage` so
/// the receiver can dispatch on `type` without ambiguity. Control payloads are sealed
/// with ChaCha20-Poly1305 before transport (see `CryptoBox`); signaling/handshake
/// messages are sent before the secure channel is established.
public enum WireMessage: Codable, Sendable {
    /// An encrypted blob containing an encoded `ControlEvent`.
    case control(sealed: Data)
    /// Periodic ping used to measure round-trip latency.
    case ping(sentAt: Date)
    case pong(sentAt: Date)
    /// Host-side notification (e.g. display geometry changed).
    case hostStatus(HostStatus)

    public struct HostStatus: Codable, Sendable, Equatable {
        public var displayWidth: Int
        public var displayHeight: Int
        public var scaleFactor: Double
        public init(displayWidth: Int, displayHeight: Int, scaleFactor: Double) {
            self.displayWidth = displayWidth
            self.displayHeight = displayHeight
            self.scaleFactor = scaleFactor
        }
    }
}

public enum WireCodec {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}
