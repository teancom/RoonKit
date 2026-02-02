import Foundation

/// Configuration for reconnection behavior
public struct ReconnectorConfig: Sendable {
    /// Initial delay before first reconnection attempt (seconds)
    public let baseDelay: TimeInterval

    /// Multiplier applied to delay after each failure
    public let multiplier: Double

    /// Maximum delay between reconnection attempts (seconds)
    public let maxDelay: TimeInterval

    /// Maximum jitter percentage (0.0 to 1.0) added to delay
    public let maxJitter: Double

    /// Maximum number of reconnection attempts (nil for unlimited)
    public let maxAttempts: Int?

    public init(
        baseDelay: TimeInterval = 1.0,
        multiplier: Double = 2.0,
        maxDelay: TimeInterval = 60.0,
        maxJitter: Double = 0.1,
        maxAttempts: Int? = nil
    ) {
        precondition(baseDelay > 0, "baseDelay must be positive (> 0)")
        precondition(multiplier > 0, "multiplier must be positive (> 0)")
        precondition(maxDelay > 0, "maxDelay must be positive (> 0)")
        precondition(maxJitter >= 0.0 && maxJitter <= 1.0, "maxJitter must be in range [0.0, 1.0]")
        precondition(maxAttempts == nil || maxAttempts! > 0, "maxAttempts must be positive or nil")

        self.baseDelay = baseDelay
        self.multiplier = multiplier
        self.maxDelay = maxDelay
        self.maxJitter = maxJitter
        self.maxAttempts = maxAttempts
    }

    /// Default configuration per design spec
    public static let `default` = ReconnectorConfig()
}

/// Manages reconnection attempts with exponential backoff
public actor Reconnector {
    private let config: ReconnectorConfig
    private var attemptCount: Int = 0
    private var isActive: Bool = false

    public init(config: ReconnectorConfig = .default) {
        self.config = config
    }

    /// Reset the reconnector after a successful connection
    public func reset() {
        attemptCount = 0
        isActive = false
    }

    /// Calculate delay for the next reconnection attempt
    /// Returns nil if max attempts exceeded
    public func nextDelay() -> TimeInterval? {
        attemptCount += 1

        // Check max attempts
        if let maxAttempts = config.maxAttempts, attemptCount > maxAttempts {
            return nil
        }

        // Calculate base delay with exponential backoff
        let exponentialDelay = config.baseDelay * pow(config.multiplier, Double(attemptCount - 1))

        // Cap at max delay
        let cappedDelay = min(exponentialDelay, config.maxDelay)

        // Add jitter (random 0% to maxJitter%)
        let jitter = cappedDelay * Double.random(in: 0...config.maxJitter)

        return cappedDelay + jitter
    }

    /// Current attempt number (1-based)
    public var currentAttempt: Int {
        attemptCount
    }

    /// Wait for the next reconnection delay
    /// Throws if max attempts exceeded
    public func waitForNextAttempt() async throws {
        guard let delay = nextDelay() else {
            throw ConnectionError.maxReconnectAttemptsExceeded
        }

        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    /// Start a reconnection sequence
    public func start() {
        isActive = true
    }

    /// Stop the reconnection sequence
    public func stop() {
        isActive = false
    }

    /// Whether reconnection is currently active
    public var isReconnecting: Bool {
        isActive
    }
}
