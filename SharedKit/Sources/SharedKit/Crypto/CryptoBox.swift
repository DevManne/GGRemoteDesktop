import Foundation
import CryptoKit

/// End-to-end encryption primitives for the control channel.
///
/// Pairing performs a Curve25519 ECDH to derive a shared secret, which is expanded with
/// HKDF into a symmetric key. Each `ControlEvent` is then sealed with
/// ChaCha20-Poly1305 (AEAD), giving confidentiality + integrity independent of WebRTC's
/// own DTLS-SRTP (defence in depth).
public struct CryptoBox: Sendable {
    private let key: SymmetricKey

    /// Derive a session key from a peer's public key and our private key.
    /// - Parameter salt: a per-session random value (exchanged during pairing) so the
    ///   derived key is unique even if the long-term keys are reused.
    public init(privateKey: Curve25519.KeyAgreement.PrivateKey,
                peerPublicKey: Curve25519.KeyAgreement.PublicKey,
                salt: Data,
                info: Data = Data("remotemac.control.v1".utf8)) throws {
        let shared = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
        self.key = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: info,
            outputByteCount: 32
        )
    }

    /// Construct directly from a raw 32-byte key (used in tests / restored sessions).
    public init(rawKey: Data) {
        self.key = SymmetricKey(data: rawKey)
    }

    /// Encrypt and authenticate `plaintext`. Returns the combined sealed box (nonce +
    /// ciphertext + tag) ready to place inside a `WireMessage.control`.
    public func seal(_ plaintext: Data) throws -> Data {
        let box = try ChaChaPoly.seal(plaintext, using: key)
        return box.combined
    }

    /// Decrypt and verify a sealed box. Throws if authentication fails.
    public func open(_ sealed: Data) throws -> Data {
        let box = try ChaChaPoly.SealedBox(combined: sealed)
        return try ChaChaPoly.open(box, using: key)
    }
}

public extension CryptoBox {
    /// Generate a fresh Curve25519 key pair for a device's long-term identity.
    static func generateIdentityKeyPair() -> Curve25519.KeyAgreement.PrivateKey {
        Curve25519.KeyAgreement.PrivateKey()
    }

    /// A cryptographically random salt for `init(privateKey:peerPublicKey:salt:)`.
    static func randomSalt(byteCount: Int = 32) -> Data {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return Data(bytes)
    }
}
