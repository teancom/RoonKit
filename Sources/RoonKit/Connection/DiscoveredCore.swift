import Foundation

/// Represents a Roon Core discovered via SOOD protocol
public struct DiscoveredCore: Sendable, Equatable, Hashable {
    /// Host IP address or hostname
    public let host: String

    /// Port number (typically 9100)
    public let port: Int

    /// Core ID from SOOD response (if available)
    public let coreId: String?

    /// Display name from SOOD response (if available)
    public let displayName: String?

    /// Transaction ID used in discovery
    public let transactionId: String

    /// Date/time when this core was discovered
    public let discoveredAt: Date

    public init(
        host: String,
        port: Int,
        coreId: String? = nil,
        displayName: String? = nil,
        transactionId: String,
        discoveredAt: Date = Date()
    ) {
        self.host = host
        self.port = port
        self.coreId = coreId
        self.displayName = displayName
        self.transactionId = transactionId
        self.discoveredAt = discoveredAt
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(host)
        hasher.combine(port)
    }
}
