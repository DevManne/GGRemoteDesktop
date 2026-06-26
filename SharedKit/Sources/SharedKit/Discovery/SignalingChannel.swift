import Foundation
import Network

/// A length-prefixed message channel over an `NWConnection`, used as the out-of-band
/// signaling path that complements the QR code.
///
/// The QR carries the host's identity + initial offer; this channel carries the client's
/// **answer** back to the host and any trickled **ICE candidates** in both directions,
/// none of which fit comfortably in a static QR.
public final class SignalingChannel {
    /// Messages exchanged during connection establishment.
    public enum Message: Codable, Sendable {
        case answer(SessionDescriptor)
        case iceCandidate(IceCandidate)
        case clientHello(DeviceInfo)
    }

    public struct IceCandidate: Codable, Sendable {
        public let sdp: String
        public let sdpMLineIndex: Int32
        public let sdpMid: String?
        public init(sdp: String, sdpMLineIndex: Int32, sdpMid: String?) {
            self.sdp = sdp
            self.sdpMLineIndex = sdpMLineIndex
            self.sdpMid = sdpMid
        }
    }

    public var onMessage: ((Message) -> Void)?
    public var onClosed: (() -> Void)?

    private let connection: NWConnection

    public init(connection: NWConnection) {
        self.connection = connection
        receiveNextFrame()
    }

    /// Encode and send a signaling message with a 4-byte big-endian length prefix.
    public func send(_ message: Message) {
        guard let payload = try? JSONEncoder().encode(message) else { return }
        var frame = Data()
        var length = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &length) { frame.append(contentsOf: $0) }
        frame.append(payload)
        connection.send(content: frame, completion: .contentProcessed { _ in })
    }

    public func close() {
        connection.cancel()
        onClosed?()
    }

    // MARK: Framed receive

    private func receiveNextFrame() {
        receiveExactly(4) { [weak self] header in
            guard let self, let header else { self?.onClosed?(); return }
            let length = header.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            self.receiveExactly(Int(length)) { body in
                if let body, let message = try? JSONDecoder().decode(Message.self, from: body) {
                    self.onMessage?(message)
                }
                self.receiveNextFrame()
            }
        }
    }

    private func receiveExactly(_ count: Int, completion: @escaping (Data?) -> Void) {
        connection.receive(minimumIncompleteLength: count, maximumLength: count) {
            data, _, isComplete, error in
            if let error = error { _ = error; completion(nil); return }
            if isComplete && (data?.isEmpty ?? true) { completion(nil); return }
            completion(data)
        }
    }
}
