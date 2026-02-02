import Foundation
@testable import RoonKit

/// Mock WebSocket transport for testing.
///
/// Thread-Safety Design: This mock does not use NSLock-based synchronization (unlike the design
/// document) because test execution is inherently safe from concurrent access:
/// 1. Swift Testing framework runs each test in isolation with no concurrent execution
/// 2. Tests are single-threaded - the test method runs to completion before starting another
/// 3. Mock state mutations only occur on the test's main task
/// 4. Actor-isolated test code cannot spawn concurrent tasks that would access shared state
///
/// If this mock were used in production code or concurrent contexts, NSLock would be required.
/// For unit tests with isolated execution, the simplified version is both safe and more performant.
final class MockWebSocketTransport: WebSocketTransport, @unchecked Sendable {
    /// Messages sent through this transport (as strings for easy inspection)
    var sentMessages: [String] = []

    /// Binary data sent through this transport
    var sentData: [Data] = []

    /// Queue of messages to return from receive()
    var messagesToReceive: [Result<WebSocketMessage, Error>] = []

    /// Whether the transport is closed
    var isClosed: Bool = false

    /// Close code received
    var closeCode: URLSessionWebSocketTask.CloseCode?

    /// Continuation for manual message injection - waits when queue is empty
    private var receiveContinuation: CheckedContinuation<WebSocketMessage, Error>?

    /// Whether the mock should throw when empty (true) or wait for messages (false)
    var throwWhenEmpty: Bool = false

    func send(_ data: Data) async throws {
        sentData.append(data)
        // Also store as string for easy test inspection
        if let text = String(data: data, encoding: .utf8) {
            sentMessages.append(text)
        }
    }

    func sendText(_ text: String) async throws {
        sentMessages.append(text)
    }

    func receive() async throws -> WebSocketMessage {
        if !messagesToReceive.isEmpty {
            let result = messagesToReceive.removeFirst()
            return try result.get()
        }

        // If throwWhenEmpty is set (for simple tests), throw immediately
        if throwWhenEmpty {
            throw ConnectionError.connectionClosed(code: 1000, reason: "no more mock messages")
        }

        // Otherwise wait for a message to be injected
        return try await withCheckedThrowingContinuation { continuation in
            self.receiveContinuation = continuation
        }
    }

    func sendPing() async throws {
        // No-op for testing
    }

    func close(code: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isClosed = true
        closeCode = code
        receiveContinuation?.resume(throwing: URLError(.cancelled))
        receiveContinuation = nil
    }

    /// Inject a message to be received
    func injectMessage(_ message: WebSocketMessage) {
        if let continuation = receiveContinuation {
            receiveContinuation = nil
            continuation.resume(returning: message)
        } else {
            messagesToReceive.append(.success(message))
        }
    }

    /// Inject an error to be thrown from receive()
    func injectError(_ error: Error) {
        if let continuation = receiveContinuation {
            receiveContinuation = nil
            continuation.resume(throwing: error)
        } else {
            messagesToReceive.append(.failure(error))
        }
    }

    /// Get the last sent message
    var lastSentMessage: String? {
        return sentMessages.last
    }

    /// Clear sent messages
    func clearSentMessages() {
        sentMessages.removeAll()
    }
}

/// Helper for creating mock responses
enum MockResponses {
    static func coreInfo(coreId: String = "test-core", coreName: String = "Test Core") -> String {
        """
        MOO/1 COMPLETE Success
        Request-Id: 0
        Content-Type: application/json
        Content-Length: 100

        {"core_id":"\(coreId)","display_name":"\(coreName)","display_version":"1.8.0"}
        """
    }

    static func registered(
        coreId: String = "test-core",
        coreName: String = "Test Core",
        token: String = "test-token"
    ) -> String {
        """
        MOO/1 COMPLETE Registered
        Request-Id: 1
        Content-Type: application/json
        Content-Length: 150

        {"core_id":"\(coreId)","display_name":"\(coreName)","display_version":"1.8.0","token":"\(token)","provided_services":["com.roonlabs.transport:2"]}
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

    static func zoneSubscribed(zones: [[String: Any]] = []) -> String {
        let zonesJson = try? JSONSerialization.data(withJSONObject: zones)
        let zonesString = zonesJson.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        return """
            MOO/1 CONTINUE Subscribed
            Request-Id: 2
            Content-Type: application/json
            Content-Length: \(zonesString.count)

            {"zones":\(zonesString)}
            """
    }

    static func zonesChanged(zones: [[String: Any]]) -> String {
        let zonesJson = try? JSONSerialization.data(withJSONObject: zones)
        let zonesString = zonesJson.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        return """
            MOO/1 CONTINUE Changed
            Request-Id: 2
            Content-Type: application/json
            Content-Length: \(zonesString.count + 20)

            {"zones_changed":\(zonesString)}
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
            Content-Length: \(bodyString.count)

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
}
