import XCTest
@testable import RoonKit

final class DiscoveryErrorTests: XCTestCase {
    func testNoCoresFoundError() {
        let error = DiscoveryError.noCoresFound
        XCTAssertEqual(error.errorDescription, "no Roon cores found")
    }

    func testTimeoutError() {
        let error = DiscoveryError.timeout
        XCTAssertEqual(error.errorDescription, "discovery timed out")
    }

    func testSocketError() {
        let error = DiscoveryError.socketError("bind failed")
        XCTAssertEqual(error.errorDescription, "socket error: bind failed")
    }

    func testParseError() {
        let error = DiscoveryError.parseError("invalid packet format")
        XCTAssertEqual(error.errorDescription, "parse error: invalid packet format")
    }

    func testNetworkUnavailableError() {
        let error = DiscoveryError.networkUnavailable
        XCTAssertEqual(error.errorDescription, "network unavailable")
    }

    func testErrorEquality() {
        let error1 = DiscoveryError.timeout
        let error2 = DiscoveryError.timeout
        XCTAssertEqual(error1, error2)
    }

    func testErrorInequality() {
        let error1 = DiscoveryError.timeout
        let error2 = DiscoveryError.noCoresFound
        XCTAssertNotEqual(error1, error2)
    }

    func testSocketErrorEquality() {
        let error1 = DiscoveryError.socketError("test")
        let error2 = DiscoveryError.socketError("test")
        XCTAssertEqual(error1, error2)
    }

    func testSocketErrorInequality() {
        let error1 = DiscoveryError.socketError("error1")
        let error2 = DiscoveryError.socketError("error2")
        XCTAssertNotEqual(error1, error2)
    }

    func testErrorSendable() {
        let error = DiscoveryError.timeout
        Task {
            let _ = error
        }
    }

    func testErrorConformsToError() {
        let error = DiscoveryError.noCoresFound as Error
        XCTAssertNotNil(error)
    }

    func testErrorConformsToLocalizedError() {
        let error = DiscoveryError.timeout as LocalizedError
        XCTAssertNotNil(error.errorDescription)
    }
}
