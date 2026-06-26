import XCTest
@testable import SharedKit

final class PairingPayloadTests: XCTestCase {
    func testQRRoundTrip() throws {
        let host = DeviceInfo(name: "Mac", role: .host, publicKey: "AAA=")
        let payload = PairingPayload(
            host: host,
            salt: CryptoBox.randomSalt(),
            offer: SessionDescriptor(kind: .offer, sdp: "v=0..."),
            authString: "123456"
        )
        let qr = try payload.encodedForQR()
        let decoded = try PairingPayload.decodeFromQR(qr)
        XCTAssertEqual(decoded, payload)
    }

    func testAuthStringIsDeterministicAndSixDigits() {
        let h = Data([1, 2, 3]); let c = Data([4, 5, 6]); let s = Data([7, 8, 9])
        let a = PairingPayload.makeAuthString(hostPublicKey: h, clientPublicKey: c, salt: s)
        let b = PairingPayload.makeAuthString(hostPublicKey: h, clientPublicKey: c, salt: s)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 6)
    }
}
