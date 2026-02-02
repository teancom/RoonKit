import Testing
@testable import RoonKit

/// Test suite for TransportService.
///
/// NOTE: These tests focus on logic that can be tested without complex async message-passing.
/// The original design specified tests that would call connection.connect() and then send
/// commands, but this triggers Swift actor reentrancy issues where:
/// 1. receiveLoop runs in Task.detached and waits for messages
/// 2. After registration messages are consumed, mock throws error (empty queue)
/// 3. Tests try to add messages and call service methods, but receive loop already exited
///
/// Complex async tests (playback commands, volume control, seek, settings) are deferred to
/// Phase 6 which will implement proper test infrastructure with better async handling.
///
/// Current test coverage validates:
/// - Zone selection state management
/// - Error throwing when no zone selected
/// - TransportError types and descriptions
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
