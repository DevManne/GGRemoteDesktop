import XCTest
@testable import SharedKit

final class ReconnectPolicyTests: XCTestCase {
    func testExponentialBackoffIsCappedAndBounded() {
        var policy = ReconnectPolicy(baseDelay: 1, maxDelay: 8, maxAttempts: 5)
        XCTAssertEqual(policy.nextDelay(), 1)
        XCTAssertEqual(policy.nextDelay(), 2)
        XCTAssertEqual(policy.nextDelay(), 4)
        XCTAssertEqual(policy.nextDelay(), 8)
        XCTAssertEqual(policy.nextDelay(), 8) // capped at maxDelay
        XCTAssertNil(policy.nextDelay())      // attempts exhausted
    }

    func testResetRestartsBackoff() {
        var policy = ReconnectPolicy(baseDelay: 1, maxDelay: 8, maxAttempts: 3)
        _ = policy.nextDelay(); _ = policy.nextDelay()
        policy.reset()
        XCTAssertEqual(policy.nextDelay(), 1)
    }
}
