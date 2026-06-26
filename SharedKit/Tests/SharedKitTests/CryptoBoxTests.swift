import XCTest
import CryptoKit
@testable import SharedKit

final class CryptoBoxTests: XCTestCase {
    func testSealOpenRoundTrip() throws {
        let alice = Curve25519.KeyAgreement.PrivateKey()
        let bob = Curve25519.KeyAgreement.PrivateKey()
        let salt = CryptoBox.randomSalt()

        let aliceBox = try CryptoBox(privateKey: alice, peerPublicKey: bob.publicKey, salt: salt)
        let bobBox = try CryptoBox(privateKey: bob, peerPublicKey: alice.publicKey, salt: salt)

        let message = Data("left click at 0.5,0.5".utf8)
        let sealed = try aliceBox.seal(message)
        let opened = try bobBox.open(sealed)

        XCTAssertEqual(opened, message)
        XCTAssertNotEqual(sealed, message)
    }

    func testTamperedCiphertextFailsToOpen() throws {
        let key = CryptoBox.randomSalt(byteCount: 32)
        let box = CryptoBox(rawKey: key)
        var sealed = try box.seal(Data("hello".utf8))
        sealed[sealed.count - 1] ^= 0xFF // flip a bit in the auth tag
        XCTAssertThrowsError(try box.open(sealed))
    }
}
