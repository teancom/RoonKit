import Testing
@testable import RoonKit

@Suite("ConnectionState Tests")
struct ConnectionStateTests {

    @Test("Disconnected state properties")
    func disconnectedStateProperties() {
        let state = ConnectionState.disconnected

        #expect(!state.canSendMessages)
        #expect(!state.isConnecting)
    }

    @Test("Connecting state properties")
    func connectingStateProperties() {
        let state = ConnectionState.connecting

        #expect(!state.canSendMessages)
        #expect(state.isConnecting)
    }

    @Test("Registering state properties")
    func registeringStateProperties() {
        let state = ConnectionState.registering

        #expect(!state.canSendMessages)
        #expect(state.isConnecting)
    }

    @Test("Connected state properties")
    func connectedStateProperties() {
        let state = ConnectionState.connected(coreId: "abc123", coreName: "My Core")

        #expect(state.canSendMessages)
        #expect(!state.isConnecting)
    }

    @Test("Reconnecting state properties")
    func reconnectingStateProperties() {
        let state = ConnectionState.reconnecting(attempt: 3)

        #expect(!state.canSendMessages)
        #expect(state.isConnecting)
    }

    @Test("Failed state properties")
    func failedStateProperties() {
        let state = ConnectionState.failed(.timeout)

        #expect(!state.canSendMessages)
        #expect(!state.isConnecting)
    }

    @Test("ConnectionState is Equatable")
    func connectionStateEquatable() {
        let state1 = ConnectionState.connected(coreId: "abc", coreName: "Core")
        let state2 = ConnectionState.connected(coreId: "abc", coreName: "Core")
        let state3 = ConnectionState.connected(coreId: "xyz", coreName: "Other")

        #expect(state1 == state2)
        #expect(state1 != state3)
    }
}

@Suite("ConnectionError Tests")
struct ConnectionErrorTests {

    @Test("Error descriptions are lowercase fragments")
    func errorDescriptionsAreLowercaseFragments() {
        let errors: [ConnectionError] = [
            .connectionFailed("server unreachable"),
            .connectionClosed(code: 1000, reason: "normal closure"),
            .connectionClosed(code: 1006, reason: nil),
            .registrationFailed("invalid extension"),
            .invalidURL,
            .timeout,
            .maxReconnectAttemptsExceeded
        ]

        for error in errors {
            let description = error.errorDescription ?? ""
            // Should start with lowercase (following error message convention)
            let firstChar = description.first ?? "A"
            #expect(firstChar.isLowercase, "Error description should start lowercase: \(description)")
        }
    }

    @Test("ConnectionError is Equatable")
    func connectionErrorEquatable() {
        #expect(ConnectionError.timeout == ConnectionError.timeout)
        #expect(ConnectionError.invalidURL != ConnectionError.timeout)
        #expect(ConnectionError.connectionFailed("a") == ConnectionError.connectionFailed("a"))
        #expect(ConnectionError.connectionFailed("a") != ConnectionError.connectionFailed("b"))
    }
}
