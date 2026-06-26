import Foundation

/// WebRTC SDP exchanged out-of-band (via QR or Bonjour) because there is no signaling
/// server. `kind` mirrors `RTCSdpType`.
public struct SessionDescriptor: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case offer, answer
    }
    public let kind: Kind
    public let sdp: String
    public init(kind: Kind, sdp: String) {
        self.kind = kind
        self.sdp = sdp
    }
}
