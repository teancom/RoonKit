import Foundation
import Synchronization
@testable import RoonKit

/// Mock WebSocket transport for testing.
///
/// Thread-Safety Design: This mock uses `Mutex` synchronization because `RoonConnection.connect()`
/// spawns `Task.detached { receiveLoop() }` which calls `transport.receive()` from a different isolation
/// context than the actor's `send()` calls. Both paths access `messagesToReceive` and
/// `receiveContinuation`, creating a data race without synchronization.
///
/// The `onSend` callback enables `MockRoonServer` to intercept outgoing MOO requests and inject
/// responses before the receive loop needs them, solving the actor reentrancy timing problem.
final class MockWebSocketTransport: WebSocketTransport, @unchecked Sendable {

    private struct State {
        var sentMessages: [String] = []
        var sentData: [Data] = []
        var messagesToReceive: [Result<WebSocketMessage, Error>] = []
        var isClosed: Bool = false
        var closeCode: URLSessionWebSocketTask.CloseCode?
        var receiveContinuation: CheckedContinuation<WebSocketMessage, Error>?
    }

    private let state = Mutex(State())

    /// Whether the mock should throw when empty (true) or wait for messages (false)
    nonisolated(unsafe) var throwWhenEmpty: Bool = false

    /// Callback invoked when data is sent through this transport.
    /// MockRoonServer hooks into this to intercept outgoing requests and auto-respond.
    nonisolated(unsafe) var onSend: (@Sendable (Data) -> Void)?

    /// Messages sent through this transport (as strings for easy inspection)
    var sentMessages: [String] {
        state.withLock { $0.sentMessages }
    }

    /// Binary data sent through this transport
    var sentData: [Data] {
        state.withLock { $0.sentData }
    }

    /// Whether the transport is closed
    var isClosed: Bool {
        state.withLock { $0.isClosed }
    }

    /// Close code received
    var closeCode: URLSessionWebSocketTask.CloseCode? {
        state.withLock { $0.closeCode }
    }

    func send(_ data: Data) async throws {
        state.withLock {
            $0.sentData.append(data)
            if let text = String(data: data, encoding: .utf8) {
                $0.sentMessages.append(text)
            }
        }

        // Call onSend outside the lock to avoid deadlocks
        // (the callback may call injectMessage which also takes the lock)
        onSend?(data)
    }

    func sendText(_ text: String) async throws {
        state.withLock {
            $0.sentMessages.append(text)
        }

        onSend?(text.data(using: .utf8) ?? Data())
    }

    func receive() async throws -> WebSocketMessage {
        // Fast path: message already queued
        let queued: Result<WebSocketMessage, Error>? = state.withLock { s in
            if !s.messagesToReceive.isEmpty {
                return s.messagesToReceive.removeFirst()
            }
            return nil
        }
        if let queued { return try queued.get() }

        // If throwWhenEmpty is set (for simple tests), throw immediately
        if throwWhenEmpty {
            throw ConnectionError.connectionClosed(code: 1000, reason: "no more mock messages")
        }

        // Otherwise wait for a message to be injected
        return try await withCheckedThrowingContinuation { continuation in
            // Check again in case a message was injected between the fast path and here
            let immediateResult: Result<WebSocketMessage, Error>? = self.state.withLock { s in
                if !s.messagesToReceive.isEmpty {
                    return s.messagesToReceive.removeFirst()
                }
                s.receiveContinuation = continuation
                return nil
            }
            if let immediateResult {
                do {
                    continuation.resume(returning: try immediateResult.get())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func sendPing() async throws {
        // No-op for testing
    }

    func close(code: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let continuation = state.withLock { s -> CheckedContinuation<WebSocketMessage, Error>? in
            s.isClosed = true
            s.closeCode = code
            let c = s.receiveContinuation
            s.receiveContinuation = nil
            return c
        }

        continuation?.resume(throwing: URLError(.cancelled))
    }

    /// Inject a message to be received
    func injectMessage(_ message: WebSocketMessage) {
        let continuation = state.withLock { s -> CheckedContinuation<WebSocketMessage, Error>? in
            if let c = s.receiveContinuation {
                s.receiveContinuation = nil
                return c
            } else {
                s.messagesToReceive.append(.success(message))
                return nil
            }
        }

        continuation?.resume(returning: message)
    }

    /// Inject an error to be thrown from receive()
    func injectError(_ error: Error) {
        let continuation = state.withLock { s -> CheckedContinuation<WebSocketMessage, Error>? in
            if let c = s.receiveContinuation {
                s.receiveContinuation = nil
                return c
            } else {
                s.messagesToReceive.append(.failure(error))
                return nil
            }
        }

        continuation?.resume(throwing: error)
    }

    /// Get the last sent message
    var lastSentMessage: String? {
        state.withLock { $0.sentMessages.last }
    }

    /// Clear sent messages
    func clearSentMessages() {
        state.withLock { $0.sentMessages.removeAll() }
    }

    /// Pre-queue messages that will be returned from receive() before any continuation-based waiting.
    /// Useful for simple tests that don't need the auto-response pattern.
    func queueMessages(_ messages: [Result<WebSocketMessage, Error>]) {
        state.withLock { $0.messagesToReceive.append(contentsOf: messages) }
    }
}

/// Helper for creating mock responses
enum MockResponses {
    static func coreInfo(coreId: String = "test-core", coreName: String = "Test Core") -> String {
        let body = "{\"core_id\":\"\(coreId)\",\"display_name\":\"\(coreName)\",\"display_version\":\"1.8.0\"}"
        return """
            MOO/1 COMPLETE Success
            Request-Id: 0
            Content-Type: application/json
            Content-Length: \(body.utf8.count)

            \(body)
            """
    }

    static func registered(
        coreId: String = "test-core",
        coreName: String = "Test Core",
        token: String = "test-token"
    ) -> String {
        let body = "{\"core_id\":\"\(coreId)\",\"display_name\":\"\(coreName)\",\"display_version\":\"1.8.0\",\"token\":\"\(token)\",\"provided_services\":[\"com.roonlabs.transport:2\"]}"
        return """
            MOO/1 COMPLETE Registered
            Request-Id: 1
            Content-Type: application/json
            Content-Length: \(body.utf8.count)

            \(body)
            """
    }

    static func error(requestId: Int, name: String, message: String) -> String {
        """
        MOO/1 COMPLETE \(name)
        Request-Id: \(requestId)
        Content-Type: application/json
        Content-Length: 50

        {"error":"\(message)"}
        """
    }

    static func zoneSubscribed(zones: [[String: Any]] = [], requestId: Int = 2) -> String {
        let zonesJson = try? JSONSerialization.data(withJSONObject: zones)
        let zonesString = zonesJson.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let body = "{\"zones\":\(zonesString)}"
        return """
            MOO/1 CONTINUE Subscribed
            Request-Id: \(requestId)
            Content-Type: application/json
            Content-Length: \(body.utf8.count)

            \(body)
            """
    }

    static func zonesChanged(zones: [[String: Any]], requestId: Int = 2) -> String {
        let zonesJson = try? JSONSerialization.data(withJSONObject: zones)
        let zonesString = zonesJson.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let body = "{\"zones_changed\":\(zonesString)}"
        return """
            MOO/1 CONTINUE Changed
            Request-Id: \(requestId)
            Content-Type: application/json
            Content-Length: \(body.utf8.count)

            \(body)
            """
    }

    static func success(requestId: Int) -> String {
        """
        MOO/1 COMPLETE Success
        Request-Id: \(requestId)

        """
    }

    static func successWithBody(requestId: Int, body: [String: Any]) -> String {
        let bodyJson = try? JSONSerialization.data(withJSONObject: body)
        let bodyString = bodyJson.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return """
            MOO/1 COMPLETE Success
            Request-Id: \(requestId)
            Content-Type: application/json
            Content-Length: \(bodyString.utf8.count)

            \(bodyString)
            """
    }

    static func browseResult(requestId: Int, title: String, count: Int, level: Int = 0) -> String {
        """
        MOO/1 COMPLETE Success
        Request-Id: \(requestId)
        Content-Type: application/json
        Content-Length: 100

        {"action":"list","list":{"title":"\(title)","count":\(count),"level":\(level)}}
        """
    }

    static func loadResult(requestId: Int, items: [[String: Any]], offset: Int, count: Int) -> String {
        let itemsJson = try? JSONSerialization.data(withJSONObject: items)
        let itemsString = itemsJson.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        return """
            MOO/1 COMPLETE Success
            Request-Id: \(requestId)
            Content-Type: application/json
            Content-Length: 300

            {"items":\(itemsString),"offset":\(offset),"list":{"title":"Results","count":\(count),"level":0}}
            """
    }

    // MARK: - Output Responses

    static func outputSubscribed(outputs: [[String: Any]] = [], requestId: Int = 2) -> String {
        let json = try? JSONSerialization.data(withJSONObject: outputs)
        let outputsString = json.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let body = "{\"outputs\":\(outputsString)}"
        return """
            MOO/1 CONTINUE Subscribed
            Request-Id: \(requestId)
            Content-Type: application/json
            Content-Length: \(body.utf8.count)

            \(body)
            """
    }

    static func outputsChanged(outputs: [[String: Any]], requestId: Int = 2) -> String {
        let json = try? JSONSerialization.data(withJSONObject: outputs)
        let outputsString = json.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let body = "{\"outputs_changed\":\(outputsString)}"
        return """
            MOO/1 CONTINUE Changed
            Request-Id: \(requestId)
            Content-Type: application/json
            Content-Length: \(body.utf8.count)

            \(body)
            """
    }

    // MARK: - Queue Responses

    static func queueSubscribed(items: [[String: Any]] = [], requestId: Int = 2) -> String {
        let json = try? JSONSerialization.data(withJSONObject: items)
        let itemsString = json.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let body = "{\"items\":\(itemsString)}"
        return """
            MOO/1 CONTINUE Subscribed
            Request-Id: \(requestId)
            Content-Type: application/json
            Content-Length: \(body.utf8.count)

            \(body)
            """
    }

    // MARK: - Generic CONTINUE Builder

    static func continueResponse(requestId: Int, name: String, body: [String: Any]) -> String {
        let bodyJson = try? JSONSerialization.data(withJSONObject: body)
        let bodyString = bodyJson.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return """
            MOO/1 CONTINUE \(name)
            Request-Id: \(requestId)
            Content-Type: application/json
            Content-Length: \(bodyString.utf8.count)

            \(bodyString)
            """
    }

    // MARK: - Sample Data Builders

    static func sampleZone(
        id: String = "zone-1",
        name: String = "Living Room",
        state: String = "playing"
    ) -> [String: Any] {
        [
            "zone_id": id,
            "display_name": name,
            "state": state,
            "outputs": [
                [
                    "output_id": "output-1",
                    "zone_id": id,
                    "display_name": "Speaker",
                    "volume": [
                        "type": "db",
                        "min": -80.0,
                        "max": 0.0,
                        "value": -30.0,
                        "step": 1.0,
                        "is_muted": false
                    ]
                ]
            ],
            "settings": [
                "shuffle": false,
                "loop": "disabled",
                "auto_radio": false
            ],
            "now_playing": [
                "seek_position": 60.0,
                "length": 240.0,
                "one_line": ["line1": "Test Song"],
                "two_line": ["line1": "Test Song", "line2": "Test Artist"],
                "three_line": ["line1": "Test Song", "line2": "Test Artist", "line3": "Test Album"]
            ]
        ]
    }

    static func sampleOutput(
        id: String = "output-1",
        zoneId: String = "zone-1",
        name: String = "Speaker",
        volumeValue: Double = -30.0,
        isMuted: Bool = false,
        supportsStandby: Bool = false
    ) -> [String: Any] {
        var output: [String: Any] = [
            "output_id": id,
            "zone_id": zoneId,
            "display_name": name,
            "state": "playing",
            "volume": [
                "type": "db",
                "min": -80.0,
                "max": 0.0,
                "value": volumeValue,
                "step": 1.0,
                "is_muted": isMuted
            ]
        ]
        if supportsStandby {
            output["source_controls"] = [
                [
                    "display_name": name,
                    "status": "selected",
                    "supports_standby": true,
                    "control_key": "1"
                ]
            ]
        }
        return output
    }

    static func sampleQueueItem(
        id: Int = 1,
        title: String = "Test Song",
        artist: String = "Test Artist",
        album: String = "Test Album",
        length: Double = 240.0,
        imageKey: String? = "image-key-1"
    ) -> [String: Any] {
        var item: [String: Any] = [
            "queue_item_id": id,
            "length": length,
            "three_line": [
                "line1": title,
                "line2": artist,
                "line3": album
            ]
        ]
        if let imageKey {
            item["image_key"] = imageKey
        }
        return item
    }
}
