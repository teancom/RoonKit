import XCTest
@testable import RoonKit

final class DiscoveredCoreTests: XCTestCase {
    func testDiscoveredCoreInitialization() {
        let core = DiscoveredCore(
            host: "192.168.1.100",
            port: 9100,
            coreId: "core-123",
            displayName: "My Roon Core",
            transactionId: "tid-abc"
        )

        XCTAssertEqual(core.host, "192.168.1.100")
        XCTAssertEqual(core.port, 9100)
        XCTAssertEqual(core.coreId, "core-123")
        XCTAssertEqual(core.displayName, "My Roon Core")
        XCTAssertEqual(core.transactionId, "tid-abc")
    }

    func testDiscoveredCoreOptionalFields() {
        let core = DiscoveredCore(
            host: "10.0.0.1",
            port: 9100,
            transactionId: "tid-123"
        )

        XCTAssertEqual(core.host, "10.0.0.1")
        XCTAssertEqual(core.port, 9100)
        XCTAssertNil(core.coreId)
        XCTAssertNil(core.displayName)
        XCTAssertEqual(core.transactionId, "tid-123")
    }

    func testDiscoveredCoreEquality() {
        let now = Date()
        let core1 = DiscoveredCore(
            host: "192.168.1.100",
            port: 9100,
            coreId: "core-123",
            transactionId: "tid-1",
            discoveredAt: now
        )

        let core2 = DiscoveredCore(
            host: "192.168.1.100",
            port: 9100,
            coreId: "core-123",
            transactionId: "tid-1",
            discoveredAt: now
        )

        XCTAssertEqual(core1, core2)
    }

    func testDiscoveredCoreInequality() {
        let core1 = DiscoveredCore(
            host: "192.168.1.100",
            port: 9100,
            transactionId: "tid-1"
        )

        let core2 = DiscoveredCore(
            host: "192.168.1.101",
            port: 9100,
            transactionId: "tid-1"
        )

        XCTAssertNotEqual(core1, core2)
    }

    func testDiscoveredCoreHashable() {
        let core1 = DiscoveredCore(
            host: "192.168.1.100",
            port: 9100,
            transactionId: "tid-1"
        )

        let core2 = DiscoveredCore(
            host: "192.168.1.101",
            port: 9100,
            transactionId: "tid-2"
        )

        // Test that cores can be used in a Set
        let set: Set<DiscoveredCore> = [core1, core2]
        XCTAssertTrue(set.contains(core1))
        XCTAssertTrue(set.contains(core2))
        XCTAssertEqual(set.count, 2)
    }

    func testDiscoveredCoreWithDates() {
        let now = Date()
        let core = DiscoveredCore(
            host: "192.168.1.100",
            port: 9100,
            transactionId: "tid-1",
            discoveredAt: now
        )

        XCTAssertEqual(core.discoveredAt, now)
    }

    func testDiscoveredCoreDefaultDate() {
        let beforeCreation = Date()
        let core = DiscoveredCore(
            host: "192.168.1.100",
            port: 9100,
            transactionId: "tid-1"
        )
        let afterCreation = Date()

        XCTAssertGreaterThanOrEqual(core.discoveredAt, beforeCreation)
        XCTAssertLessThanOrEqual(core.discoveredAt, afterCreation)
    }

    func testDiscoveredCoreSendable() {
        let core = DiscoveredCore(
            host: "192.168.1.100",
            port: 9100,
            coreId: "core-123",
            displayName: "My Core",
            transactionId: "tid-1"
        )

        Task {
            let _ = core  // Can be used in async context
        }
    }

    func testDiscoveredCoreWithDifferentPorts() {
        let core1 = DiscoveredCore(
            host: "192.168.1.100",
            port: 9100,
            transactionId: "tid-1"
        )

        let core2 = DiscoveredCore(
            host: "192.168.1.100",
            port: 9101,
            transactionId: "tid-1"
        )

        XCTAssertNotEqual(core1, core2)
    }

    func testDiscoveredCoreDisplayDescription() {
        let core = DiscoveredCore(
            host: "192.168.1.100",
            port: 9100,
            displayName: "Living Room",
            transactionId: "tid-1"
        )

        let description = "\(core)"
        XCTAssertTrue(description.contains("192.168.1.100"))
    }
}
