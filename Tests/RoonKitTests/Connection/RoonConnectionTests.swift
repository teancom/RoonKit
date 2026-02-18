import Foundation
import Testing
@testable import RoonKit

// Helper to check if Data contains a string
fileprivate extension Data {
    func containsString(_ str: String) -> Bool {
        guard let text = String(data: self, encoding: .utf8) else { return false }
        return text.contains(str)
    }
}

/// Test suite for RoonConnection basic state and message encoding.
///
/// For comprehensive async connection lifecycle tests (state transitions, token persistence,
/// reconnection, state stream), see `ConnectionLifecycleTests` which uses `MockRoonServer`
/// to solve the actor reentrancy timing problem.
@Suite("RoonConnection Tests")
struct RoonConnectionTests {

    let extensionInfo = ExtensionInfo(
        extensionId: "com.test.app",
        displayName: "Test App",
        displayVersion: "1.0.0",
        publisher: "Test",
        email: "test@test.com"
    )

    // MARK: - Connection State Tests

    @Test("Connection starts in disconnected state")
    func connectionStartsDisconnected() async {
        let connection = RoonConnection(
            host: "192.168.1.100",
            extensionInfo: extensionInfo
        )

        let state = await connection.state

        #expect(state == .disconnected)
    }

    @Test("Invalid URL throws error during connect")
    func invalidURLThrows() async throws {
        let connection = RoonConnection(
            host: "invalid url with spaces",
            port: 9100,
            extensionInfo: extensionInfo
        )

        do {
            try await connection.connect()
            #expect(Bool(false), "Expected ConnectionError")
        } catch is ConnectionError {
            // Expected
        }
    }

    // MARK: - Send/Subscribe Tests (without connection)

    @Test("Send fails if not connected")
    func sendFailsNotConnected() async throws {
        let connection = RoonConnection(
            host: "192.168.1.100",
            extensionInfo: extensionInfo
        )

        do {
            _ = try await connection.send(path: "com.roonlabs.registry:1/info")
            #expect(Bool(false), "Expected ConnectionError")
        } catch is ConnectionError {
            // Expected
        }
    }

    @Test("Subscribe fails if not connected")
    func subscribeFailsNotConnected() async throws {
        let connection = RoonConnection(
            host: "192.168.1.100",
            extensionInfo: extensionInfo
        )

        do {
            _ = try await connection.subscribe(
                path: "com.roonlabs.status:1/subscribe_zones"
            )
            #expect(Bool(false), "Expected ConnectionError")
        } catch is ConnectionError {
            // Expected
        }
    }

    // MARK: - Message Encoding Tests

    @Test("Send encodes request correctly")
    func sendEncodesRequest() throws {
        let request = RoonRequest(
            requestId: 5,
            path: "com.roonlabs.transport:2/control",
            body: ["zone_or_output_id": "zone123", "control": "play"]
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("com.roonlabs.transport:2/control"))
        #expect(encoded.containsString("Request-Id: 5"))
        #expect(encoded.containsString("zone123"))
        #expect(encoded.containsString("play"))
    }
}
