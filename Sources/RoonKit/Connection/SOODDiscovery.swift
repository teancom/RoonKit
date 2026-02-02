import Foundation
import Network

/// Configuration for SOOD discovery
public struct DiscoveryConfig: Sendable {
    /// Timeout for discovery in seconds (default: 60)
    public let timeout: TimeInterval

    /// Interval between queries in seconds (default: 2)
    public let queryInterval: TimeInterval

    /// Stop discovery after finding first core (default: false)
    public let stopOnFirst: Bool

    public init(
        timeout: TimeInterval = 60.0,
        queryInterval: TimeInterval = 2.0,
        stopOnFirst: Bool = false
    ) {
        self.timeout = timeout
        self.queryInterval = queryInterval
        self.stopOnFirst = stopOnFirst
    }

    /// Default configuration
    public static let `default` = DiscoveryConfig()
}

/// Actor for discovering Roon Cores via SOOD protocol
public actor SOODDiscovery {
    // MARK: - Configuration

    private let config: DiscoveryConfig

    // MARK: - State

    private var discovered: [DiscoveredCore] = []
    private var isRunning = false
    private var listener: NWListener?
    private var connection: NWConnection?

    // MARK: - Constants

    private static let MULTICAST_IP = "239.255.90.90"
    private static let SOOD_PORT: UInt16 = 9003
    private static let ROON_HTTP_PORT = 9100

    // MARK: - Initialization

    /// Create a discovery instance with optional configuration
    public init(config: DiscoveryConfig = .default) {
        self.config = config
    }

    // MARK: - Public API

    /// Perform SOOD discovery for available Roon Cores
    ///
    /// This will send discovery queries and wait for responses until timeout.
    /// If stopOnFirst is enabled, will return immediately after finding one core.
    ///
    /// - Throws: DiscoveryError if discovery fails
    /// - Returns: Array of discovered cores (may be empty)
    public func discover() async throws -> [DiscoveredCore] {
        guard !isRunning else {
            throw DiscoveryError.socketError("discovery already in progress")
        }

        isRunning = true
        defer {
            isRunning = false
            cleanup()
        }

        discovered.removeAll()

        return try await performDiscovery()
    }

    /// Cancel any ongoing discovery
    public func cancel() {
        isRunning = false
        cleanup()
    }

    // MARK: - Private Implementation

    private func cleanup() {
        listener?.cancel()
        listener = nil
        connection?.cancel()
        connection = nil
    }

    private func performDiscovery() async throws -> [DiscoveredCore] {
        // Set up UDP listener to receive responses
        try await setupListener()

        let startTime = Date()
        let deadline = startTime.addingTimeInterval(config.timeout)
        let transactionId = UUID().uuidString

        // Send initial query
        await sendQuery(transactionId: transactionId)

        var lastQueryTime = Date()

        while Date() < deadline && !Task.isCancelled && isRunning {
            // If stopOnFirst and we found one, return immediately
            if config.stopOnFirst && !discovered.isEmpty {
                return discovered
            }

            // Send periodic queries
            if Date().timeIntervalSince(lastQueryTime) >= config.queryInterval {
                await sendQuery(transactionId: transactionId)
                lastQueryTime = Date()
            }

            // Small sleep to avoid busy-waiting
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        return discovered
    }

    private func setupListener() async throws {
        // Create UDP parameters
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        // Create listener on SOOD port
        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: Self.SOOD_PORT)!)
        } catch {
            // If we can't bind to SOOD port, try any available port
            listener = try NWListener(using: parameters)
        }

        guard let listener = listener else {
            throw DiscoveryError.socketError("Failed to create listener")
        }

        // Set up new connection handler
        listener.newConnectionHandler = { [weak self] newConnection in
            Task { [weak self] in
                await self?.handleConnection(newConnection)
            }
        }

        // Start listener
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                break // Listener is ready
            case .failed(let error):
                print("Listener failed: \(error)")
            default:
                break
            }
        }

        listener.start(queue: .global())

        // Wait a moment for listener to be ready
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveMessage(on: connection)
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .global())
    }

    private nonisolated func receiveMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                // Get source address from connection
                var sourceIP: String?
                if case let .hostPort(host, _) = connection.currentPath?.remoteEndpoint {
                    switch host {
                    case .ipv4(let addr):
                        sourceIP = "\(addr)"
                    case .ipv6(let addr):
                        sourceIP = "\(addr)"
                    default:
                        break
                    }
                }

                Task {
                    await self.processReceivedData(data, sourceIP: sourceIP)
                }
            }

            if error == nil {
                // Continue receiving
                self.receiveMessage(on: connection)
            }
        }
    }

    private func processReceivedData(_ data: Data, sourceIP: String?) {
        guard let message = SOODProtocol.decode(data: data, sourceIP: sourceIP, sourcePort: Int(Self.SOOD_PORT)) else {
            return
        }

        processMessage(message)
    }

    private func sendQuery(transactionId: String) async {
        let queryData = SOODProtocol.encodeQuery(transactionId: transactionId)

        // Send to multicast address
        let host = NWEndpoint.Host(Self.MULTICAST_IP)
        let port = NWEndpoint.Port(rawValue: Self.SOOD_PORT)!

        let connection = NWConnection(host: host, port: port, using: .udp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: queryData, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            case .failed, .cancelled:
                break
            default:
                break
            }
        }
        connection.start(queue: .global())

        // Also try broadcast on local network
        await sendBroadcast(data: queryData)
    }

    private func sendBroadcast(data: Data) async {
        // Send to broadcast address as well for networks where multicast might not work
        let broadcastHost = NWEndpoint.Host("255.255.255.255")
        let port = NWEndpoint.Port(rawValue: Self.SOOD_PORT)!

        let connection = NWConnection(host: broadcastHost, port: port, using: .udp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: data, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            case .failed, .cancelled:
                break
            default:
                break
            }
        }
        connection.start(queue: .global())
    }

    private func processMessage(_ message: SOODProtocol.Message) {
        guard message.type == .response else { return }

        let host = message.sourceIP ?? "unknown"
        // Roon HTTP API runs on port 9100 by default
        let port = message.sourcePort ?? Self.ROON_HTTP_PORT

        // Extract core info from properties
        let coreId = message.properties["_corid"]?.flatMap { $0 }
        let displayName = message.properties["_displayname"]?.flatMap { $0 }

        // Extract or generate transaction ID
        let transactionId = message.properties["_tid"]?.flatMap { $0 } ?? UUID().uuidString

        // Get HTTP port from properties if available
        var httpPort = port
        if let httpPortStr = message.properties["http_port"]?.flatMap({ $0 }),
           let parsedPort = Int(httpPortStr) {
            httpPort = parsedPort
        }

        let core = DiscoveredCore(
            host: host,
            port: httpPort,
            coreId: coreId,
            displayName: displayName,
            transactionId: transactionId
        )

        // Check if we already have this core (by host:port)
        if !discovered.contains(where: { $0.host == core.host && $0.port == core.port }) {
            discovered.append(core)
            print("Discovered Roon Core: \(core.displayName ?? core.host) at \(core.host):\(core.port)")
        }
    }
}
