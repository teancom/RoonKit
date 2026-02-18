import Testing
@testable import RoonKit

/// Test suite for TransportService basic state and error handling.
///
/// For comprehensive command tests (play, pause, stop, volume, seek, settings, grouping),
/// see `TransportCommandTests` which uses `MockRoonServer` to solve the actor reentrancy
/// timing problem. For subscription lifecycle tests, see `SubscriptionLifecycleTests`.
@Suite("TransportService Tests")
struct TransportServiceTests {

    // MARK: - Zone Selection Tests (no connection needed)

    @Test("Zone selection updates selectedZoneId")
    func zoneSelectionUpdates() async {
        // Create service directly with a mock connection (never connected)
        let extensionInfo = ExtensionInfo(
            extensionId: "com.test.app",
            displayName: "Test",
            displayVersion: "1.0.0",
            publisher: "Test",
            email: "test@test.com"
        )

        let connection = RoonConnection(
            host: "192.168.1.100",
            extensionInfo: extensionInfo,
            transportFactory: { _ in MockWebSocketTransport() }
        )

        let service = TransportService(connection: connection)

        await service.selectZone(id: "zone-abc")

        let selectedId = await service.selectedZoneId
        #expect(selectedId == "zone-abc")
    }

    @Test("Selected zone returns nil when no zone selected")
    func selectedZoneReturnsNilInitially() async {
        let extensionInfo = ExtensionInfo(
            extensionId: "com.test.app",
            displayName: "Test",
            displayVersion: "1.0.0",
            publisher: "Test",
            email: "test@test.com"
        )

        let connection = RoonConnection(
            host: "192.168.1.100",
            extensionInfo: extensionInfo,
            transportFactory: { _ in MockWebSocketTransport() }
        )

        let service = TransportService(connection: connection)

        let selectedZone = await service.selectedZone
        #expect(selectedZone == nil)
    }

    @Test("Zones dictionary is empty initially")
    func zonesDictionaryEmptyInitially() async {
        let extensionInfo = ExtensionInfo(
            extensionId: "com.test.app",
            displayName: "Test",
            displayVersion: "1.0.0",
            publisher: "Test",
            email: "test@test.com"
        )

        let connection = RoonConnection(
            host: "192.168.1.100",
            extensionInfo: extensionInfo,
            transportFactory: { _ in MockWebSocketTransport() }
        )

        let service = TransportService(connection: connection)

        let zones = await service.zones
        #expect(zones.isEmpty)
    }

    // MARK: - TransportError Tests

    @Test("TransportError noZoneSelected has correct description")
    func noZoneSelectedErrorDescription() {
        let error = TransportError.noZoneSelected

        #expect(error.localizedDescription == "no zone selected")
    }

    @Test("TransportError commandFailed includes message")
    func commandFailedErrorDescription() {
        let error = TransportError.commandFailed("zone not found")

        #expect(error.localizedDescription == "command failed: zone not found")
    }

    @Test("TransportError is Equatable")
    func transportErrorIsEquatable() {
        #expect(TransportError.noZoneSelected == TransportError.noZoneSelected)
        #expect(TransportError.commandFailed("a") == TransportError.commandFailed("a"))
        #expect(TransportError.commandFailed("a") != TransportError.commandFailed("b"))
    }
}

// MARK: - RoonClient Tests

@Suite("RoonClient Tests")
struct RoonClientTests {

    @Test("RoonClient initializes with correct properties")
    func clientInitializesCorrectly() async {
        let client = RoonClient(
            host: "192.168.1.100",
            port: 9100,
            extensionId: "com.test.roonkit",
            displayName: "Test Client",
            displayVersion: "1.0.0",
            publisher: "Test Publisher",
            email: "test@example.com"
        )

        // Access actor-isolated properties with await
        let host = await client.host
        let port = await client.port
        let extensionInfo = await client.extensionInfo

        #expect(host == "192.168.1.100")
        #expect(port == 9100)
        #expect(extensionInfo.extensionId == "com.test.roonkit")
        #expect(extensionInfo.displayName == "Test Client")
        #expect(extensionInfo.displayVersion == "1.0.0")
        #expect(extensionInfo.publisher == "Test Publisher")
        #expect(extensionInfo.email == "test@example.com")
    }

    @Test("RoonClient starts disconnected")
    func clientStartsDisconnected() async {
        let client = RoonClient(
            host: "192.168.1.100",
            extensionId: "com.test.roonkit",
            displayName: "Test Client",
            displayVersion: "1.0.0",
            publisher: "Test Publisher",
            email: "test@example.com"
        )

        let state = await client.state
        #expect(state == .disconnected)
    }
}
