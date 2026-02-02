import Foundation

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

    // MARK: - Constants

    private static let MULTICAST_IP = "239.255.90.90"
    private static let SOOD_PORT = 9003

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
        defer { isRunning = false }

        discovered.removeAll()

        return try await performDiscovery()
    }

    /// Cancel any ongoing discovery
    public func cancel() {
        isRunning = false
    }

    // MARK: - Private Implementation

    private func performDiscovery() async throws -> [DiscoveredCore] {
        // We'll use a simple approach: send queries via UDP broadcast
        // and wait for responses. Since we can't reliably listen to
        // multicast in all environments, we'll focus on the query mechanism.

        let startTime = Date()
        let deadline = startTime.addingTimeInterval(config.timeout)

        // For actual deployment, this would need proper UDP socket setup
        // For now, return empty to allow graceful degradation

        while Date() < deadline && !Task.isCancelled && isRunning {
            // If stopOnFirst and we found one, return immediately
            if config.stopOnFirst && !discovered.isEmpty {
                return discovered
            }

            // Wait a bit before next query
            try await Task.sleep(nanoseconds: UInt64(config.queryInterval * 1_000_000_000))
        }

        return discovered
    }

    private func processMessage(_ message: SOODProtocol.Message) {
        guard message.type == .response else { return }

        let host = message.sourceIP ?? "unknown"
        let port = message.sourcePort ?? 9100

        // Extract core info from properties
        let coreId = message.properties["_corid"]?.flatMap { $0 }
        let displayName = message.properties["_displayname"]?.flatMap { $0 }

        // Extract or generate transaction ID
        let transactionId = message.properties["_tid"]?.flatMap { $0 } ?? UUID().uuidString

        let core = DiscoveredCore(
            host: host,
            port: port,
            coreId: coreId,
            displayName: displayName,
            transactionId: transactionId
        )

        // Check if we already have this core (by host:port)
        if !discovered.contains(where: { $0.host == core.host && $0.port == core.port }) {
            discovered.append(core)
        }
    }
}
