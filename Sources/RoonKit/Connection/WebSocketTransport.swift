import Foundation

/// Protocol abstracting WebSocket operations for testability
public protocol WebSocketTransport: Sendable {
    /// Send binary data (required for Roon MOO protocol)
    func send(_ data: Data) async throws

    /// Send a text message (legacy, deprecated)
    func sendText(_ text: String) async throws

    /// Receive the next message
    func receive() async throws -> WebSocketMessage

    /// Send a ping and wait for pong
    func sendPing() async throws

    /// Close the connection
    func close(code: URLSessionWebSocketTask.CloseCode, reason: Data?)
}

/// Message received from WebSocket
public enum WebSocketMessage: Sendable {
    case text(String)
    case data(Data)
}

/// Real WebSocket transport using URLSessionWebSocketTask.
/// Safe as `@unchecked Sendable` because `task` and `session` are immutable (`let`) and
/// `URLSessionWebSocketTask`'s async methods are internally synchronized.
public final class URLSessionWebSocketTransport: WebSocketTransport, @unchecked Sendable {
    private let task: URLSessionWebSocketTask
    private let session: URLSession
    private let ownsSession: Bool

    public init(url: URL, session: URLSession? = nil) {
        self.ownsSession = (session == nil)
        self.session = session ?? URLSession(configuration: .default)
        self.task = self.session.webSocketTask(with: url)
        task.resume()
    }

    public func send(_ data: Data) async throws {
        try await task.send(.data(data))
    }

    public func sendText(_ text: String) async throws {
        try await task.send(.string(text))
    }

    public func receive() async throws -> WebSocketMessage {
        let message = try await task.receive()
        switch message {
        case .string(let text):
            return .text(text)
        case .data(let data):
            return .data(data)
        @unknown default:
            throw WebSocketTransportError.unknownMessageType
        }
    }

    public func sendPing() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.sendPing { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func close(code: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        task.cancel(with: code, reason: reason)
        // Invalidate self-created sessions to release internal URLSession references.
        // Skip invalidation for externally-provided sessions (caller owns their lifecycle).
        if ownsSession {
            session.invalidateAndCancel()
        }
    }
}

/// Errors specific to WebSocket transport
public enum WebSocketTransportError: Error, Sendable {
    case unknownMessageType
}

extension WebSocketTransportError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unknownMessageType:
            return "unknown WebSocket message type"
        }
    }
}
