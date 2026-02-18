import Foundation

/// Actor managing the WebSocket connection to a Roon Core
public actor RoonConnection {

    // MARK: - Configuration

    /// Host address of the Roon Core
    public let host: String

    /// Port number (typically 9100)
    public let port: Int

    /// Extension information for registration
    public let extensionInfo: ExtensionInfo

    // MARK: - State

    /// Current connection state
    public private(set) var state: ConnectionState = .disconnected

    /// WebSocket transport (injectable for testing)
    private var transport: WebSocketTransport?

    /// Factory for creating transports (injectable for testing)
    private let transportFactory: @Sendable (URL) -> WebSocketTransport

    /// Counter for generating unique request IDs
    private var nextRequestId: Int = 0

    /// Pending requests awaiting responses
    private var pendingRequests: [Int: CheckedContinuation<RoonResponse, Error>] = [:]

    /// Tracks pings received while waiting for registration response
    /// After 2 pings without a register response, we're clearly awaiting authorization
    private var pingsWhileRegistering: Int = 0
    private var isWaitingForRegisterResponse: Bool = false

    /// Active subscriptions
    private var subscriptions: [Int: AsyncStream<RoonResponse>.Continuation] = [:]

    /// Stream for state changes
    private var stateStreamContinuation: AsyncStream<ConnectionState>.Continuation?

    /// Task handling incoming messages
    private var receiveTask: Task<Void, Never>?

    /// Token storage for authentication persistence
    private let tokenStorage: TokenStorage

    /// Reconnector for automatic reconnection
    private let reconnector: Reconnector

    /// Task handling reconnection
    private var reconnectTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Create a connection to a Roon Core
    /// - Parameters:
    ///   - host: IP address or hostname of the Roon Core
    ///   - port: Port number (default 9100)
    ///   - extensionInfo: Information about this extension
    ///   - tokenStorage: Storage for authentication tokens (default: UserDefaults)
    ///   - reconnectorConfig: Configuration for automatic reconnection
    public init(
        host: String,
        port: Int = 9100,
        extensionInfo: ExtensionInfo,
        tokenStorage: TokenStorage = UserDefaultsTokenStorage(),
        reconnectorConfig: ReconnectorConfig = .default
    ) {
        self.host = host
        self.port = port
        self.extensionInfo = extensionInfo
        self.tokenStorage = tokenStorage
        self.reconnector = Reconnector(config: reconnectorConfig)
        self.transportFactory = { url in
            URLSessionWebSocketTransport(url: url)
        }
    }

    /// Create a connection with custom dependencies (for testing)
    internal init(
        host: String,
        port: Int = 9100,
        extensionInfo: ExtensionInfo,
        tokenStorage: TokenStorage = InMemoryTokenStorage(),
        reconnectorConfig: ReconnectorConfig = .default,
        transportFactory: @escaping @Sendable (URL) -> WebSocketTransport
    ) {
        self.host = host
        self.port = port
        self.extensionInfo = extensionInfo
        self.tokenStorage = tokenStorage
        self.reconnector = Reconnector(config: reconnectorConfig)
        self.transportFactory = transportFactory
    }

    // MARK: - Connection Lifecycle

    /// Connect to the Roon Core
    public func connect() async throws {
        // Only allow connecting from disconnected or failed states.
        // Bail if already connected, connecting, or reconnecting.
        switch state {
        case .disconnected, .failed, .reconnecting:
            break
        default:
            return
        }

        updateState(.connecting)

        let urlString = "ws://\(host):\(port)/api"
        guard let url = URL(string: urlString) else {
            updateState(.failed(.invalidURL))
            throw ConnectionError.invalidURL
        }

        transport = transportFactory(url)
        updateState(.registering)

        // Start receiving messages
        receiveTask = Task.detached { [weak self] in
            await self?.receiveLoop()
        }

        // Perform registration handshake
        do {
            try await performRegistration()
        } catch {
            disconnect()
            throw error
        }
    }

    /// Perform the registration handshake with the Roon Core
    /// Number of pings to receive before concluding we're awaiting authorization
    private static let pingsBeforeAuthTimeout = 2

    private func performRegistration() async throws {
        // Reset ping tracking
        pingsWhileRegistering = 0
        isWaitingForRegisterResponse = false

        // Step 1: Get core info
        let infoResponse = try await send(path: RoonService.path(RoonService.registry, "info"))

        guard infoResponse.isSuccess,
              let coreId = infoResponse.body?["core_id"] as? String else {
            throw ConnectionError.registrationFailed("failed to get core info")
        }

        // Step 2: Register extension
        let savedToken = tokenStorage.token(forCoreId: coreId)
        let registrationRequest = RegistrationRequest(
            extensionInfo: extensionInfo,
            requiredServices: [RoonService.transport, RoonService.browse],
            optionalServices: [],
            providedServices: [RoonService.ping],  // Must provide ping service
            token: savedToken
        )

        // Mark that we're waiting for register response - ping handler will detect auth wait
        isWaitingForRegisterResponse = true
        defer { isWaitingForRegisterResponse = false }

        let registerResponse = try await send(
            path: RoonService.path(RoonService.registry, "register"),
            body: registrationRequest.toDictionary(),
            timeout: Self.registrationTimeout
        )

        guard registerResponse.name == "Registered",
              let registration = RegistrationResponse(from: registerResponse.body) else {
            let errorMsg = registerResponse.errorMessage ?? "registration rejected"
            throw ConnectionError.registrationFailed(errorMsg)
        }

        // Step 3: Save token for future connections
        tokenStorage.saveToken(registration.token, forCoreId: registration.coreId)

        // Step 4: Update state to connected
        await reconnector.reset()
        updateState(.connected(coreId: registration.coreId, coreName: registration.displayName))
    }

    /// Disconnect from the Roon Core
    public func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil

        receiveTask?.cancel()
        receiveTask = nil

        transport?.close(code: .goingAway, reason: nil)
        transport = nil

        // Cancel all pending requests
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: ConnectionError.connectionClosed(code: 1000, reason: "disconnected"))
        }
        pendingRequests.removeAll()

        // Close all subscriptions
        for (_, continuation) in subscriptions {
            continuation.finish()
        }
        subscriptions.removeAll()

        nextRequestId = 0
        updateState(.disconnected)
    }

    // MARK: - Sending Requests

    /// Default timeout for send requests
    public static let defaultSendTimeout: Duration = .seconds(30)

    /// Extended timeout for registration (user may need to authorize in Roon UI)
    private static let registrationTimeout: Duration = .seconds(300)

    /// Send a request and wait for the response
    /// - Parameters:
    ///   - path: The service path (e.g., "com.roonlabs.transport:1/control")
    ///   - body: Optional request body
    ///   - timeout: How long to wait for a response before throwing `.timeout`
    public func send(
        path: String,
        body: [String: Any]? = nil,
        timeout: Duration = RoonConnection.defaultSendTimeout
    ) async throws -> RoonResponse {
        guard let transport = transport else {
            throw ConnectionError.connectionFailed("not connected")
        }

        let requestId = nextRequestId
        nextRequestId += 1

        let request = RoonRequest(requestId: requestId, path: path, body: body)
        let encodedData = try MessageCoding.encode(request)

        // Why this structure is not straightforward:
        //
        // The naive approach — `try await transport.send()` then
        // `withCheckedThrowingContinuation` — has an actor reentrancy race.
        // `transport.send()` suspends, and during that suspension the receive
        // loop (also actor-isolated) can deliver the response. If the
        // continuation isn't registered in `pendingRequests` yet,
        // `handleMessage` silently drops the response and the caller hangs.
        //
        // Fix: register the continuation FIRST, then send. We exploit the
        // fact that `withCheckedThrowingContinuation`'s closure runs
        // synchronously on the actor — `pendingRequests[requestId]` is set
        // before any other actor-isolated code can interleave. The actual
        // send happens in a child Task spawned from that closure (because
        // the closure is synchronous and `transport.send()` is async).
        //
        // Three things race to complete the continuation: normal response
        // delivery, send failure, and timeout. Each uses
        // `removeValue(forKey:) != nil` as an atomic claim — only the first
        // to remove the key resumes the continuation, preventing
        // double-resume crashes.
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[requestId] = continuation

            Task {
                do {
                    try await transport.send(encodedData)
                } catch {
                    if self.pendingRequests.removeValue(forKey: requestId) != nil {
                        continuation.resume(throwing: error)
                    }
                }
            }

            Task {
                try? await Task.sleep(for: timeout)
                if self.pendingRequests.removeValue(forKey: requestId) != nil {
                    continuation.resume(throwing: ConnectionError.timeout)
                }
            }
        }
    }

    /// Subscribe to a service, returning a stream of responses
    public func subscribe(path: String, body: [String: Any]? = nil) async throws -> AsyncStream<RoonResponse> {
        guard let transport = transport else {
            throw ConnectionError.connectionFailed("not connected")
        }

        let requestId = nextRequestId
        nextRequestId += 1

        let request = RoonRequest(requestId: requestId, path: path, body: body)
        let encodedData = try MessageCoding.encode(request)

        let stream = AsyncStream<RoonResponse> { continuation in
            self.subscriptions[requestId] = continuation

            continuation.onTermination = { @Sendable _ in
                Task { await self.removeSubscription(requestId) }
            }
        }

        // Send as binary data (required by Roon MOO protocol)
        try await transport.send(encodedData)

        return stream
    }

    private func removeSubscription(_ requestId: Int) {
        subscriptions.removeValue(forKey: requestId)
    }

    // MARK: - State Stream

    /// Stream of connection state changes
    ///
    /// Each call to this property creates a new stream and replaces any previous stream.
    /// Only the most recent stream will receive state updates. If you need to share
    /// state updates across multiple consumers, create the stream once and share it.
    ///
    /// - Warning: Only one active stream can receive updates at a time. Creating a second stream
    ///   will cause the first stream to stop receiving updates.
    public var stateStream: AsyncStream<ConnectionState> {
        AsyncStream { continuation in
            // Finish the previous stream so its consumer's `for await` terminates
            // instead of hanging forever.
            self.stateStreamContinuation?.finish()
            self.stateStreamContinuation = continuation
            continuation.yield(self.state)
        }
    }

    private func updateState(_ newState: ConnectionState) {
        state = newState
        stateStreamContinuation?.yield(newState)
    }

    /// Enable automatic reconnection on connection loss
    public func enableAutoReconnect() {
        // Reconnection is triggered from receiveLoop when connection is lost
    }

    /// Attempt to reconnect after connection loss
    private func attemptReconnect() async {
        guard !Task.isCancelled else { return }

        await reconnector.start()

        while await reconnector.isReconnecting {
            let attempt = await reconnector.currentAttempt + 1
            updateState(.reconnecting(attempt: attempt))

            do {
                try await reconnector.waitForNextAttempt()

                // Clean up old connection
                transport?.close(code: .goingAway, reason: nil)
                transport = nil

                // Try to reconnect
                try await connect()

                // If we get here, connection succeeded
                await reconnector.stop()
                return
            } catch ConnectionError.maxReconnectAttemptsExceeded {
                updateState(.failed(.maxReconnectAttemptsExceeded))
                await reconnector.stop()
                return
            } catch {
                // Continue trying
                continue
            }
        }
    }

    // MARK: - Message Receiving

    private func receiveLoop() async {
        guard let transport = transport else {
            return
        }

        while !Task.isCancelled {
            do {
                let message = try await transport.receive()

                switch message {
                case .text(let text):
                    // Convert text to data and handle as binary
                    if let data = text.data(using: .utf8) {
                        try await handleMessage(data)
                    }
                case .data(let data):
                    // Roon sends responses as binary frames
                    try await handleMessage(data)
                }
            } catch {
                // Resume all pending request continuations so callers don't hang forever
                let connectionError = ConnectionError.connectionClosed(code: 1006, reason: error.localizedDescription)
                for (_, continuation) in pendingRequests {
                    continuation.resume(throwing: connectionError)
                }
                pendingRequests.removeAll()

                // Finish all subscription streams so consumers (e.g. zone subscriptions)
                // can detect the disconnection and re-subscribe after reconnection
                for (_, continuation) in subscriptions {
                    continuation.finish()
                }
                subscriptions.removeAll()

                if !Task.isCancelled {
                    let wasConnected = state.canSendMessages
                    updateState(.failed(.connectionClosed(code: 1006, reason: error.localizedDescription)))

                    // Trigger reconnection if we were previously connected
                    if wasConnected {
                        reconnectTask = Task { [weak self] in
                            await self?.attemptReconnect()
                        }
                    }
                }
                break
            }
        }
    }

    private func handleMessage(_ data: Data) async throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw MessageCodingError.invalidFormat("failed to decode message as UTF-8")
        }

        let decoded = try MessageCoding.decodeMessage(text)

        switch decoded {
        case .request(let incomingRequest):
            try await handleIncomingRequest(incomingRequest)

        case .response(let response):
            // Check for pending request
            if let continuation = pendingRequests.removeValue(forKey: response.requestId) {
                continuation.resume(returning: response)
                return
            }

            // Check for subscription
            if let continuation = subscriptions[response.requestId] {
                continuation.yield(response)

                // If this is a COMPLETE, close the subscription
                if response.isComplete {
                    continuation.finish()
                    subscriptions.removeValue(forKey: response.requestId)
                }
                return
            }
        }
    }

    /// Handle incoming requests from Roon (e.g., ping)
    private func handleIncomingRequest(_ request: IncomingRequest) async throws {
        guard let transport = transport else {
            return
        }

        // Handle ping service
        if request.service == RoonService.ping && request.name == "ping" {
            let response = try MessageCoding.encodeResponse(requestId: request.requestId, name: "Success")
            try await transport.send(response)

            // Track pings while waiting for registration
            if isWaitingForRegisterResponse {
                pingsWhileRegistering += 1

                // After receiving enough pings without a register response,
                // we know Roon is waiting for user authorization
                // Update state to notify UI, but keep connection alive
                if pingsWhileRegistering == Self.pingsBeforeAuthTimeout {
                    updateState(.awaitingAuthorization)
                    // Don't cancel the pending request - keep waiting for the actual response
                    // which will come when the user authorizes in Roon
                }
            }
            return
        }

        // Unknown request - send error
        let errorResponse = try MessageCoding.encodeResponse(
            requestId: request.requestId,
            name: "InvalidRequest",
            body: ["error": "unknown request: \(request.service)/\(request.name)"]
        )
        try await transport.send(errorResponse)
    }
}

/// Information about the extension registering with Roon
public struct ExtensionInfo: Sendable {
    public let extensionId: String
    public let displayName: String
    public let displayVersion: String
    public let publisher: String
    public let email: String
    public let website: String?

    public init(
        extensionId: String,
        displayName: String,
        displayVersion: String,
        publisher: String,
        email: String,
        website: String? = nil
    ) {
        self.extensionId = extensionId
        self.displayName = displayName
        self.displayVersion = displayVersion
        self.publisher = publisher
        self.email = email
        self.website = website
    }
}
