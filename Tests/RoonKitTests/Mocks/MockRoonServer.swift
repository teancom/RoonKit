import Foundation
import Synchronization
@testable import RoonKit

/// A mock Roon Core server that auto-responds to MOO protocol messages.
///
/// Solves the timing problem in async tests: when `RoonConnection.connect()` spawns
/// `Task.detached { receiveLoop() }`, the receive loop needs responses to be available
/// before the actor's `send()` returns. The mock server intercepts `send()` via the
/// transport's `onSend` callback, parses the MOO request, generates the appropriate
/// response, and injects it via `injectMessage()` — all synchronously before the
/// receive loop needs the data.
///
/// Usage:
/// ```swift
/// let server = MockRoonServer()
/// let connection = server.createConnection()
/// try await connection.connect()
/// // connection is now fully registered with the mock server
/// ```
final class MockRoonServer: @unchecked Sendable {

    /// The underlying mock transport
    let transport: MockWebSocketTransport

    // MARK: - Configurable State (set before connect)

    /// Zones to return in zone subscription responses
    nonisolated(unsafe) var zones: [[String: Any]]

    /// Outputs to return in output subscription responses
    nonisolated(unsafe) var outputs: [[String: Any]]

    /// Queue items to return in queue subscription responses
    nonisolated(unsafe) var queueItems: [[String: Any]]

    /// Core ID returned during registration
    nonisolated(unsafe) var coreId: String

    /// Core display name returned during registration
    nonisolated(unsafe) var coreName: String

    /// Token returned during registration
    nonisolated(unsafe) var token: String

    // MARK: - Tracked State

    private struct TrackedState {
        var zoneSubscriptionRequestId: Int?
        var outputSubscriptionRequestId: Int?
        var queueSubscriptionRequestId: Int?
        var receivedCommands: [ReceivedCommand] = []
    }

    private let tracked = Mutex(TrackedState())

    /// Request ID of the active zone subscription (set by auto-responder)
    var zoneSubscriptionRequestId: Int? {
        tracked.withLock { $0.zoneSubscriptionRequestId }
    }

    /// Request ID of the active output subscription (set by auto-responder)
    var outputSubscriptionRequestId: Int? {
        tracked.withLock { $0.outputSubscriptionRequestId }
    }

    /// Request ID of the active queue subscription (set by auto-responder)
    var queueSubscriptionRequestId: Int? {
        tracked.withLock { $0.queueSubscriptionRequestId }
    }

    /// Commands received from the client, for test assertions
    var receivedCommands: [ReceivedCommand] {
        tracked.withLock { $0.receivedCommands }
    }

    // MARK: - Initialization

    init(
        zones: [[String: Any]]? = nil,
        outputs: [[String: Any]]? = nil,
        queueItems: [[String: Any]]? = nil,
        coreId: String = "test-core",
        coreName: String = "Test Core",
        token: String = "test-token"
    ) {
        self.transport = MockWebSocketTransport()
        self.coreId = coreId
        self.coreName = coreName
        self.token = token
        self.zones = zones ?? [MockResponses.sampleZone()]
        self.outputs = outputs ?? [MockResponses.sampleOutput()]
        self.queueItems = queueItems ?? [MockResponses.sampleQueueItem()]

        // Hook into transport sends to auto-respond
        self.transport.onSend = { [weak self] data in
            self?.handleClientMessage(data)
        }
    }

    // MARK: - Connection Factory

    /// Create a `RoonConnection` wired to this mock server
    func createConnection(
        extensionInfo: ExtensionInfo = ExtensionInfo(
            extensionId: "com.test.app",
            displayName: "Test App",
            displayVersion: "1.0.0",
            publisher: "Test",
            email: "test@test.com"
        ),
        tokenStorage: TokenStorage = InMemoryTokenStorage(),
        reconnectorConfig: ReconnectorConfig = ReconnectorConfig(
            baseDelay: 0.01, maxDelay: 0.05, maxJitter: 0, maxAttempts: 3
        ),
        keepaliveTimeout: Duration = .seconds(15)
    ) -> RoonConnection {
        RoonConnection(
            host: "mock-host",
            port: 9100,
            extensionInfo: extensionInfo,
            tokenStorage: tokenStorage,
            reconnectorConfig: reconnectorConfig,
            keepaliveTimeout: keepaliveTimeout,
            transportFactory: { [transport] _ in transport }
        )
    }

    // MARK: - Test Helpers

    /// Inject a zone subscription event (e.g., "Changed", "Subscribed")
    func injectZoneEvent(name: String, zones: [[String: Any]]) {
        guard let requestId = zoneSubscriptionRequestId else { return }
        let key = name == "Changed" ? "zones_changed" : "zones"
        let response = MockResponses.continueResponse(
            requestId: requestId,
            name: name,
            body: [key: zones]
        )
        transport.injectMessage(.data(response.data(using: .utf8)!))
    }

    /// Inject an output subscription event
    func injectOutputEvent(name: String, outputs: [[String: Any]]) {
        guard let requestId = outputSubscriptionRequestId else { return }
        let key = name == "Changed" ? "outputs_changed" : "outputs"
        let response = MockResponses.continueResponse(
            requestId: requestId,
            name: name,
            body: [key: outputs]
        )
        transport.injectMessage(.data(response.data(using: .utf8)!))
    }

    /// Simulate a connection drop by injecting an error into the receive loop
    func simulateConnectionDrop() {
        transport.injectError(URLError(.networkConnectionLost))
    }

    /// Reset tracked state (commands, subscription IDs)
    func reset() {
        tracked.withLock { s in
            s.receivedCommands.removeAll()
            s.zoneSubscriptionRequestId = nil
            s.outputSubscriptionRequestId = nil
            s.queueSubscriptionRequestId = nil
        }
    }

    // MARK: - Auto-Response Engine

    /// Parse a client MOO message and generate the appropriate response
    private func handleClientMessage(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }

        // Parse the MOO request
        guard let decoded = try? MessageCoding.decodeMessage(text),
              case .request(let request) = decoded else {
            return
        }

        let requestId = request.requestId
        let service = request.service
        let method = request.name

        // Route based on service and method
        switch (service, method) {

        // --- Registration Handshake ---

        case (RoonService.registry, "info"):
            respondCoreInfo(requestId: requestId)

        case (RoonService.registry, "register"):
            respondRegistered(requestId: requestId)

        // --- Zone Subscriptions ---

        case (RoonService.transport, "subscribe_zones"):
            tracked.withLock { $0.zoneSubscriptionRequestId = requestId }
            respondZoneSubscribed(requestId: requestId)

        case (RoonService.transport, "unsubscribe_zones"):
            tracked.withLock { $0.zoneSubscriptionRequestId = nil }
            respondSuccess(requestId: requestId)

        // --- Output Subscriptions ---

        case (RoonService.transport, "subscribe_outputs"):
            tracked.withLock { $0.outputSubscriptionRequestId = requestId }
            respondOutputSubscribed(requestId: requestId)

        case (RoonService.transport, "unsubscribe_outputs"):
            tracked.withLock { $0.outputSubscriptionRequestId = nil }
            respondSuccess(requestId: requestId)

        // --- Queue Subscriptions ---

        case (RoonService.transport, "subscribe_queue"):
            tracked.withLock { $0.queueSubscriptionRequestId = requestId }
            respondQueueSubscribed(requestId: requestId)

        case (RoonService.transport, "unsubscribe_queue"):
            tracked.withLock { $0.queueSubscriptionRequestId = nil }
            respondSuccess(requestId: requestId)

        // --- Transport Commands ---

        case (RoonService.transport, let cmd) where isTransportCommand(cmd):
            recordCommand(service: service, method: cmd, body: request.body, requestId: requestId)
            respondSuccess(requestId: requestId)

        // --- Browse ---

        case (RoonService.browse, "browse"):
            respondSuccess(requestId: requestId)

        case (RoonService.browse, "load"):
            respondSuccess(requestId: requestId)

        default:
            respondSuccess(requestId: requestId)
        }
    }

    private func isTransportCommand(_ method: String) -> Bool {
        let commands: Set<String> = [
            "control", "change_volume", "mute", "mute_all", "seek",
            "change_settings", "standby", "toggle_standby", "convenience_switch",
            "transfer_zone", "group_outputs", "ungroup_outputs",
            "pause_all", "get_zones", "get_outputs", "play_from_here"
        ]
        return commands.contains(method)
    }

    private func recordCommand(service: String, method: String, body: [String: Any]?, requestId: Int) {
        let command = ReceivedCommand(
            service: service,
            method: method,
            body: body,
            requestId: requestId
        )
        tracked.withLock { $0.receivedCommands.append(command) }
    }

    // MARK: - Response Generators

    private func respondCoreInfo(requestId: Int) {
        let body = "{\"core_id\":\"\(coreId)\",\"display_name\":\"\(coreName)\",\"display_version\":\"1.8.0\"}"
        let response = """
            MOO/1 COMPLETE Success
            Request-Id: \(requestId)
            Content-Type: application/json
            Content-Length: \(body.utf8.count)

            \(body)
            """
        transport.injectMessage(.data(response.data(using: .utf8)!))
    }

    private func respondRegistered(requestId: Int) {
        let body = "{\"core_id\":\"\(coreId)\",\"display_name\":\"\(coreName)\",\"display_version\":\"1.8.0\",\"token\":\"\(token)\",\"provided_services\":[\"com.roonlabs.transport:2\"]}"
        let response = """
            MOO/1 COMPLETE Registered
            Request-Id: \(requestId)
            Content-Type: application/json
            Content-Length: \(body.utf8.count)

            \(body)
            """
        transport.injectMessage(.data(response.data(using: .utf8)!))
    }

    private func respondZoneSubscribed(requestId: Int) {
        let response = MockResponses.zoneSubscribed(zones: zones, requestId: requestId)
        transport.injectMessage(.data(response.data(using: .utf8)!))
    }

    private func respondOutputSubscribed(requestId: Int) {
        let response = MockResponses.outputSubscribed(outputs: outputs, requestId: requestId)
        transport.injectMessage(.data(response.data(using: .utf8)!))
    }

    private func respondQueueSubscribed(requestId: Int) {
        let response = MockResponses.queueSubscribed(items: queueItems, requestId: requestId)
        transport.injectMessage(.data(response.data(using: .utf8)!))
    }

    private func respondSuccess(requestId: Int) {
        let response = MockResponses.success(requestId: requestId)
        transport.injectMessage(.data(response.data(using: .utf8)!))
    }
}

/// A transport command received by the mock server, for test assertions.
struct ReceivedCommand: Sendable {
    let service: String
    let method: String
    nonisolated(unsafe) let body: [String: Any]?
    let requestId: Int
}
