import Foundation
import Testing
@testable import RoonKit

/// Tests for race conditions in the connection layer.
///
/// These tests verify that the actor reentrancy fixes in `RoonConnection.send()` work correctly:
/// - The continuation is registered BEFORE the transport send (preventing dropped responses)
/// - The removeValue(forKey:) atomic claim prevents double-resume
/// - Timeout fires correctly when no response arrives
@Suite("Race Condition Tests", .serialized)
struct RaceConditionTests {

    let extensionInfo = ExtensionInfo(
        extensionId: "com.test.app",
        displayName: "Test App",
        displayVersion: "1.0.0",
        publisher: "Test",
        email: "test@test.com"
    )

    @Test("Fast response doesn't hang caller (prevents bug d767495)")
    func fastResponseDoesNotHang() async throws {
        // MockRoonServer responds synchronously in the onSend callback,
        // meaning the response is available before the receive loop even starts waiting.
        // This is the exact scenario that caused hangs before the continuation-first fix.
        let server = MockRoonServer()
        let connection = server.createConnection(extensionInfo: extensionInfo)

        try await connection.connect()

        // If this hangs, the bug is back
        let transport = TransportService(connection: connection)
        await transport.selectZone(id: "zone-1")
        try await transport.play()

        // If we get here, the fast response path works
        let commands = server.receivedCommands
        #expect(!commands.isEmpty)
    }

    @Test("Repeated fast sends don't drop responses (prevents bug d767495)")
    func repeatedFastSendsDontDrop() async throws {
        let server = MockRoonServer()
        let connection = server.createConnection(extensionInfo: extensionInfo)

        try await connection.connect()

        let transport = TransportService(connection: connection)
        await transport.selectZone(id: "zone-1")

        // Send 10 rapid commands — all should complete without hanging
        for _ in 0..<10 {
            try await transport.play()
        }

        let commands = server.receivedCommands.filter { $0.method == "control" }
        #expect(commands.count == 10, "All 10 commands should have completed")
    }

    @Test("Send timeout fires when mock stops responding")
    func sendTimeoutFires() async throws {
        // Use MockRoonServer for connect(), then disable auto-responses for the timeout test
        let server = MockRoonServer()
        let connection = server.createConnection(extensionInfo: extensionInfo)

        try await connection.connect()

        // Remove the onSend callback so subsequent sends get no response
        server.transport.onSend = nil

        // Send a command with a very short timeout — no auto-response will come
        do {
            _ = try await connection.send(
                path: RoonService.path(RoonService.transport, "control"),
                body: ["control": "play", "zone_or_output_id": "zone-1"],
                timeout: .milliseconds(100)
            )
            Issue.record("Expected timeout error")
        } catch let error as ConnectionError {
            #expect(error == .timeout)
        }
    }
}
