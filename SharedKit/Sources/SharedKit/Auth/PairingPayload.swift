import Foundation
import CryptoKit

/// The data encoded into the host's pairing **QR code**.
///
/// It carries everything the client needs to (a) trust the host's identity and (b) start
/// the WebRTC handshake without a signaling server. The `authString` is a short,
/// human-verifiable value (rendered on both screens) to detect man-in-the-middle.
public struct PairingPayload: Codable, Sendable, Equatable {
    public let host: DeviceInfo
    public let salt: Data
    public let offer: SessionDescriptor
    public let authString: String

    public init(host: DeviceInfo, salt: Data, offer: SessionDescriptor, authString: String) {
        self.host = host
        self.salt = salt
        self.offer = offer
        self.authString = authString
    }

    /// Serialise for embedding in a QR code (compact JSON, then base64).
    public func encodedForQR() throws -> String {
        let data = try JSONEncoder().encode(self)
        return data.base64EncodedString()
    }

    /// Reconstruct from a scanned QR payload.
    public static func decodeFromQR(_ string: String) throws -> PairingPayload {
        guard let data = Data(base64Encoded: string) else {
            throw PairingError.malformedPayload
        }
        return try JSONDecoder().decode(PairingPayload.self, from: data)
    }

    /// Derive a 6-digit short authentication string from the two public keys + salt.
    /// Both peers compute it independently; the user compares the on-screen values.
    public static func makeAuthString(hostPublicKey: Data,
                                      clientPublicKey: Data,
                                      salt: Data) -> String {
        var hasher = SHA256()
        hasher.update(data: hostPublicKey)
        hasher.update(data: clientPublicKey)
        hasher.update(data: salt)
        let digest = hasher.finalize()
        let value = digest.prefix(4).reduce(0) { ($0 << 8) | UInt32($1) }
        return String(format: "%06d", value % 1_000_000)
    }
}

public enum PairingError: Error, Sendable {
    case malformedPayload
    case authStringMismatch
    case untrustedDevice
}
