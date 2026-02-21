import Foundation
import Testing
@testable import RoonKit

@Suite("Keepalive Watchdog Tests", .serialized)
struct KeepaliveWatchdogTests {

    /// Short timeout for fast test execution
    private static let timeout: Duration = .milliseconds(200)

    // MARK: - Watchdog Fires on Silence

    @Test("Watchdog closes transport when no messages arrive")
    func watchdogFiresOnSilence() async throws {
        let server = MockRoonServer()
        let connection = server.createConnection(keepaliveTimeout: Self.timeout)

        try await connection.connect()
        let state = await connection.state
        #expect(state == .connected(coreId: "test-core", coreName: "Test Core"))

        // Watch the state stream for a failed transition (happens before reconnect)
        let stateStream = await connection.stateStream
        let sawFailure = Task {
            for await s in stateStream {
                if case .failed = s { return true }
                if case .reconnecting = s { return true }
            }
            return false
        }

        // Wait for watchdog to fire
        let result = try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask { await sawFailure.value }
            group.addTask {
                try await Task.sleep(for: Self.timeout * 4)
                return false  // timed out without seeing failure
            }
            let first = try await group.next()!
            group.cancelAll()
            return first
        }

        #expect(result == true, "Watchdog should have triggered a failed/reconnecting state")
    }

    // MARK: - Activity Prevents Watchdog

    @Test("Watchdog does not fire while messages keep arriving")
    func watchdogDoesNotFireWithActivity() async throws {
        let server = MockRoonServer()
        let connection = server.createConnection(keepaliveTimeout: Self.timeout)

        try await connection.connect()

        // Send pings faster than the watchdog timeout to keep it alive
        let pingTask = Task {
            var requestId = 100
            while !Task.isCancelled {
                try await Task.sleep(for: Self.timeout / 4)
                let ping = "MOO/1 REQUEST com.roonlabs.ping:1/ping\nRequest-Id: \(requestId)\n"
                server.transport.injectMessage(.data(ping.data(using: .utf8)!))
                requestId += 1
            }
        }

        // Wait well past the timeout — connection should stay alive
        try await Task.sleep(for: Self.timeout * 3)
        pingTask.cancel()

        let state = await connection.state
        #expect(state == .connected(coreId: "test-core", coreName: "Test Core"))
    }

    // MARK: - Disconnect Cancels Watchdog

    @Test("Disconnect cancels watchdog without spurious close")
    func watchdogCancelledOnDisconnect() async throws {
        let server = MockRoonServer()
        let connection = server.createConnection(keepaliveTimeout: Self.timeout)

        try await connection.connect()
        await connection.disconnect()

        let state = await connection.state
        #expect(state == .disconnected)

        // Wait past the timeout — watchdog should NOT fire and change state
        try await Task.sleep(for: Self.timeout * 2)

        let stateAfterWait = await connection.state
        #expect(stateAfterWait == .disconnected)
    }
}
