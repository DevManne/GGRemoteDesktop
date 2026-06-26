import Foundation

/// Identifies a participant (host or client) on the network.
///
/// `id` is a stable, app-generated identifier persisted across launches so a previously
/// trusted device can be recognised on reconnect.
public struct DeviceInfo: Codable, Identifiable, Hashable, Sendable {
    public enum Role: String, Codable, Sendable {
        case host   // the Mac being controlled
        case client // the iPhone/iPad controlling it
    }

    public let id: UUID
    public var name: String
    public var role: Role
    /// Base64-encoded Curve25519 public key used for pairing / key agreement.
    public var publicKey: String

    public init(id: UUID = UUID(), name: String, role: Role, publicKey: String) {
        self.id = id
        self.name = name
        self.role = role
        self.publicKey = publicKey
    }
}
