import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

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

/// Thread-safe container for discovered cores
private final class DiscoveryState: @unchecked Sendable {
    private let lock = NSLock()
    private var _discovered: [DiscoveredCore] = []
    private var _isRunning = true

    var discovered: [DiscoveredCore] {
        lock.lock()
        defer { lock.unlock() }
        return _discovered
    }

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isRunning
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        _isRunning = false
    }

    func addCore(_ core: DiscoveredCore) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if !_discovered.contains(where: { $0.host == core.host && $0.port == core.port }) {
            _discovered.append(core)
            return true
        }
        return false
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        _discovered.removeAll()
        _isRunning = true
    }
}

/// Actor for discovering Roon Cores via SOOD protocol
///
/// SOOD (Simple Out-Of-band Discovery) uses UDP multicast/broadcast to find Roon Cores
/// on the local network. This implementation uses POSIX sockets for reliable UDP handling.
///
/// Note: Some Roon Core configurations may have discovery disabled or blocked by firewall.
/// In those cases, use direct connection with known host/port instead.
public actor SOODDiscovery {
    // MARK: - Configuration

    private let config: DiscoveryConfig

    // MARK: - State

    private let state = DiscoveryState()
    private var discoveryInProgress = false

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
    public func discover() async throws -> [DiscoveredCore] {
        guard !discoveryInProgress else {
            throw DiscoveryError.socketError("discovery already in progress")
        }

        discoveryInProgress = true
        state.reset()

        defer {
            discoveryInProgress = false
            state.stop()
        }

        return try await performDiscovery()
    }

    /// Cancel any ongoing discovery
    public func cancel() {
        state.stop()
    }

    // MARK: - Private Implementation

    private func performDiscovery() async throws -> [DiscoveredCore] {
        // Create UDP socket
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else {
            throw DiscoveryError.socketError("failed to create socket: \(String(cString: strerror(errno)))")
        }

        defer { close(sock) }

        // Enable broadcast
        var broadcastEnable: Int32 = 1
        if setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout<Int32>.size)) < 0 {
            throw DiscoveryError.socketError("failed to enable broadcast: \(String(cString: strerror(errno)))")
        }

        // Enable address reuse
        var reuseAddr: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        // Bind to any available port (we'll receive responses on this port)
        var bindAddr = sockaddr_in()
        bindAddr.sin_family = sa_family_t(AF_INET)
        bindAddr.sin_port = 0 // Any port
        bindAddr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &bindAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(sock, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if bindResult < 0 {
            throw DiscoveryError.socketError("failed to bind socket: \(String(cString: strerror(errno)))")
        }

        // Set socket to non-blocking
        let flags = fcntl(sock, F_GETFL, 0)
        _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

        // Create query data
        let transactionId = UUID().uuidString
        let queryData = SOODProtocol.encodeQuery(transactionId: transactionId)

        // Set up broadcast address
        var broadcastAddr = sockaddr_in()
        broadcastAddr.sin_family = sa_family_t(AF_INET)
        broadcastAddr.sin_port = UInt16(Self.SOOD_PORT).bigEndian
        broadcastAddr.sin_addr.s_addr = inet_addr("255.255.255.255")

        // Set up multicast address
        var multicastAddr = sockaddr_in()
        multicastAddr.sin_family = sa_family_t(AF_INET)
        multicastAddr.sin_port = UInt16(Self.SOOD_PORT).bigEndian
        multicastAddr.sin_addr.s_addr = inet_addr(Self.MULTICAST_IP)

        let startTime = Date()
        let deadline = startTime.addingTimeInterval(config.timeout)
        var lastQueryTime = Date.distantPast

        // Buffer for receiving responses
        var recvBuffer = [UInt8](repeating: 0, count: 65536)
        var senderAddr = sockaddr_in()
        var senderAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        while Date() < deadline && !Task.isCancelled && state.isRunning {
            // If stopOnFirst and we found one, return immediately
            if config.stopOnFirst && !state.discovered.isEmpty {
                break
            }

            // Send periodic queries
            if Date().timeIntervalSince(lastQueryTime) >= config.queryInterval {
                // Send to broadcast
                queryData.withUnsafeBytes { bytes in
                    withUnsafePointer(to: &broadcastAddr) { ptr in
                        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                            _ = sendto(sock, bytes.baseAddress, queryData.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }

                // Send to multicast
                queryData.withUnsafeBytes { bytes in
                    withUnsafePointer(to: &multicastAddr) { ptr in
                        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                            _ = sendto(sock, bytes.baseAddress, queryData.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }

                lastQueryTime = Date()
            }

            // Try to receive data (non-blocking)
            let bytesRead = withUnsafeMutablePointer(to: &senderAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    recvfrom(sock, &recvBuffer, recvBuffer.count, 0, sockaddrPtr, &senderAddrLen)
                }
            }

            if bytesRead > 0 {
                let data = Data(bytes: recvBuffer, count: bytesRead)

                // Extract sender IP
                var ipStr = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &senderAddr.sin_addr, &ipStr, socklen_t(INET_ADDRSTRLEN))
                let sourceIP = String(decoding: ipStr.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)

                processIncomingData(data, sourceIP: sourceIP)
            }

            // Small sleep to avoid busy-waiting
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        return state.discovered
    }

    private nonisolated func processIncomingData(_ data: Data, sourceIP: String) {
        guard let message = SOODProtocol.decode(
            data: data,
            sourceIP: sourceIP,
            sourcePort: Int(Self.SOOD_PORT)
        ) else {
            return
        }

        // Only process response messages, not queries
        guard message.type == .response else { return }

        let host = message.sourceIP ?? sourceIP

        // Extract core info
        let coreId = message.properties["_corid"]?.flatMap { $0 }
        let displayName = message.properties["_displayname"]?.flatMap { $0 }
        let transactionId = message.properties["_tid"]?.flatMap { $0 } ?? UUID().uuidString

        // Get HTTP port (default 9100)
        var httpPort = Self.ROON_HTTP_PORT
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

        if state.addCore(core) {
            print("Discovered Roon Core: \(core.displayName ?? core.host) at \(core.host):\(core.port)")
        }
    }
}
