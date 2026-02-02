import Foundation

/// Errors that can occur during SOOD discovery
public enum DiscoveryError: Error, Sendable, Equatable {
    /// No Roon Cores were found during discovery
    case noCoresFound

    /// Discovery timed out before any cores were found
    case timeout

    /// Socket error during discovery
    case socketError(String)

    /// Error parsing SOOD response
    case parseError(String)

    /// Network is unavailable
    case networkUnavailable
}

extension DiscoveryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noCoresFound:
            return "no Roon cores found"
        case .timeout:
            return "discovery timed out"
        case .socketError(let message):
            return "socket error: \(message)"
        case .parseError(let message):
            return "parse error: \(message)"
        case .networkUnavailable:
            return "network unavailable"
        }
    }
}
