import Foundation

/// Represents the current state of the connection to a Roon Core.
public enum ConnectionState: Sendable, Equatable {
    /// Not connected to any Roon Core
    case disconnected

    /// Attempting to establish WebSocket connection
    case connecting

    /// WebSocket connected, performing registration handshake
    case registering

    /// Connected but waiting for user to authorize extension in Roon settings
    case awaitingAuthorization

    /// Fully connected and registered with Roon Core
    case connected(coreId: String, coreName: String)

    /// Connection lost, will attempt reconnection
    case reconnecting(attempt: Int)

    /// Connection failed with an error
    case failed(ConnectionError)

    /// Whether the connection is in a state that can send messages
    public var canSendMessages: Bool {
        if case .connected = self {
            return true
        }
        return false
    }

    /// Whether the connection is attempting to connect or reconnect
    public var isConnecting: Bool {
        switch self {
        case .connecting, .registering, .reconnecting:
            return true
        default:
            return false
        }
    }
}

/// Errors that can occur during connection
public enum ConnectionError: Error, Sendable, Equatable {
    /// Failed to establish WebSocket connection
    case connectionFailed(String)

    /// WebSocket connection was closed unexpectedly
    case connectionClosed(code: Int, reason: String?)

    /// Registration with Roon Core failed
    case registrationFailed(String)

    /// Invalid URL provided
    case invalidURL

    /// Connection timed out
    case timeout

    /// Maximum reconnection attempts exceeded
    case maxReconnectAttemptsExceeded

    /// Extension needs to be authorized in Roon settings
    case awaitingAuthorization
}

extension ConnectionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "connection failed: \(message)"
        case .connectionClosed(let code, let reason):
            if let reason = reason {
                return "connection closed with code \(code): \(reason)"
            }
            return "connection closed with code \(code)"
        case .registrationFailed(let message):
            return "registration failed: \(message)"
        case .invalidURL:
            return "invalid URL"
        case .timeout:
            return "connection timed out"
        case .maxReconnectAttemptsExceeded:
            return "maximum reconnection attempts exceeded"
        case .awaitingAuthorization:
            return "extension awaiting authorization in Roon"
        }
    }
}
