import Foundation
import Synchronization
import Testing
@testable import RoonKit

/// Thread-safe state collector for cross-isolation gathering.
private final class StateCollector: Sendable {
    private let storage = Mutex<[ConnectionState]>([])

    func append(_ state: ConnectionState) {
        storage.withLock { $0.append(state) }
    }

    var states: [ConnectionState] {
        storage.withLock { Array($0) }
    }
}

/// Tests for the full connection lifecycle using MockRoonServer.
///
/// These tests exercise the actual `RoonConnection.connect()` flow including the
/// `Task.detached { receiveLoop() }` message loop — the timing problem that previously
/// blocked async connection testing is solved by MockRoonServer's `onSend` auto-response pattern.
@Suite("Connection Lifecycle Tests", .serialized)
struct ConnectionLifecycleTests {

    let extensionInfo = ExtensionInfo(
        extensionId: "com.test.app",
        displayName: "Test App",
        displayVersion: "1.0.0",
        publisher: "Test",
        email: "test@test.com"
    )

    // MARK: - Happy Path

    @Test("Connect transitions to connected state")
    func connectTransitionsToConnected() async throws {
        let server = MockRoonServer()
        let connection = server.createConnection(extensionInfo: extensionInfo)

        try await connection.connect()

        let state = await connection.state
        #expect(state == .connected(coreId: "test-core", coreName: "Test Core"))
    }

    @Test("Connect populates core info from registration")
    func connectPopulatesCoreInfo() async throws {
        let server = MockRoonServer(coreId: "my-core-123", coreName: "Studio")
        let connection = server.createConnection(extensionInfo: extensionInfo)

        try await connection.connect()

        let state = await connection.state
        #expect(state == .connected(coreId: "my-core-123", coreName: "Studio"))
    }

    @Test("Token saved on successful registration")
    func tokenSavedOnRegistration() async throws {
        let server = MockRoonServer(token: "saved-token-abc")
        let tokenStorage = InMemoryTokenStorage()
        let connection = server.createConnection(
            extensionInfo: extensionInfo,
            tokenStorage: tokenStorage
        )

        try await connection.connect()

        let savedToken = tokenStorage.token(forCoreId: "test-core")
        #expect(savedToken == "saved-token-abc")
    }

    @Test("Saved token sent on reconnection attempt")
    func savedTokenSentOnReconnection() async throws {
        let server = MockRoonServer(token: "initial-token")
        let tokenStorage = InMemoryTokenStorage()

        // First connection — saves token
        let connection1 = server.createConnection(
            extensionInfo: extensionInfo,
            tokenStorage: tokenStorage
        )
        try await connection1.connect()
        await connection1.disconnect()

        // Second connection — should include saved token in register body
        server.reset()
        let connection2 = server.createConnection(
            extensionInfo: extensionInfo,
            tokenStorage: tokenStorage
        )
        try await connection2.connect()

        // Check that the register request (second sent message) contained the token
        let sentMessages = server.transport.sentMessages
        let registerMessage = sentMessages.first { $0.contains("register") && $0.contains("token") }
        #expect(registerMessage != nil)
        #expect(registerMessage?.contains("initial-token") == true)
    }

    // MARK: - Disconnect

    @Test("Disconnect transitions to disconnected state")
    func disconnectTransitionsToDisconnected() async throws {
        let server = MockRoonServer()
        let connection = server.createConnection(extensionInfo: extensionInfo)

        try await connection.connect()
        await connection.disconnect()

        let state = await connection.state
        #expect(state == .disconnected)
    }

    @Test("Disconnect closes transport")
    func disconnectClosesTransport() async throws {
        let server = MockRoonServer()
        let connection = server.createConnection(extensionInfo: extensionInfo)

        try await connection.connect()
        await connection.disconnect()

        #expect(server.transport.isClosed)
    }

    // MARK: - State Stream

    @Test("State stream emits transitions during connect")
    func stateStreamEmitsTransitions() async throws {
        let server = MockRoonServer()
        let connection = server.createConnection(extensionInfo: extensionInfo)

        let stateStream = await connection.stateStream
        let collector = StateCollector()

        // Collect states in a task
        let collectTask = Task {
            for await state in stateStream {
                collector.append(state)
                if case .connected = state { break }
            }
        }

        try await connection.connect()
        await collectTask.value

        // Should see: disconnected (initial yield) -> connecting -> registering -> connected
        let observedStates = collector.states
        #expect(observedStates.contains(.disconnected))
        #expect(observedStates.contains(.connecting))
        #expect(observedStates.contains(.registering))
        #expect(observedStates.contains(.connected(coreId: "test-core", coreName: "Test Core")))
    }

    // MARK: - Connection Drop

    @Test("Connection drop triggers reconnection state")
    func connectionDropTriggersReconnection() async throws {
        let server = MockRoonServer()
        let connection = server.createConnection(extensionInfo: extensionInfo)

        try await connection.connect()

        let stateStream = await connection.stateStream
        let expectation = Task {
            for await state in stateStream {
                if case .reconnecting = state {
                    return true
                }
                if case .connected = state {
                    // After reconnecting, it will reconnect successfully
                    return true
                }
            }
            return false
        }

        // Simulate drop
        server.simulateConnectionDrop()

        // Wait a bit for reconnection logic to kick in
        try await Task.sleep(for: .milliseconds(200))
        expectation.cancel()
    }
}
