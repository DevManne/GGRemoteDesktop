import Foundation
import CryptoKit
import SharedKit

#if canImport(AppKit)
import AppKit
#endif

/// A device's long-term identity: a persisted Curve25519 key pair plus `DeviceInfo`.
///
/// The private key is stored once and reused so a trusted device keeps the same
/// identity across launches. (Phase 4 migrates persistence to the Keychain.)
public struct DeviceIdentity {
    public let privateKey: Curve25519.KeyAgreement.PrivateKey
    public let info: DeviceInfo

    public var publicKeyData: Data { privateKey.publicKey.rawRepresentation }

    public static func loadOrCreate(role: DeviceInfo.Role, name: String) -> DeviceIdentity {
        let defaults = UserDefaults.standard
        let keyTag = "remotemac.identity.privateKey"
        let idTag = "remotemac.identity.id"

        let key: Curve25519.KeyAgreement.PrivateKey
        if let raw = defaults.data(forKey: keyTag),
           let restored = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw) {
            key = restored
        } else {
            key = Curve25519.KeyAgreement.PrivateKey()
            defaults.set(key.rawRepresentation, forKey: keyTag)
        }

        let id: UUID
        if let stored = defaults.string(forKey: idTag), let parsed = UUID(uuidString: stored) {
            id = parsed
        } else {
            id = UUID()
            defaults.set(id.uuidString, forKey: idTag)
        }

        let info = DeviceInfo(id: id, name: name, role: role,
                              publicKey: key.publicKey.rawRepresentation.base64EncodedString())
        return DeviceIdentity(privateKey: key, info: info)
    }
}

public enum Host {
    public static var machineName: String {
#if canImport(AppKit)
        Host.current().localizedName ?? "Mac"
#else
        "Mac"
#endif
    }
}
