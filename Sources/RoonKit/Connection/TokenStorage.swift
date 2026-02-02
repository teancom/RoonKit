import Foundation

/// Protocol for storing and retrieving authentication tokens
public protocol TokenStorage: Sendable {
    /// Get token for a specific core
    func token(forCoreId coreId: String) -> String?

    /// Save token for a specific core
    func saveToken(_ token: String, forCoreId coreId: String)

    /// Remove token for a specific core
    func removeToken(forCoreId coreId: String)

    /// Remove all stored tokens
    func removeAllTokens()
}

/// Token storage using UserDefaults
public final class UserDefaultsTokenStorage: TokenStorage, @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix: String

    public init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "com.roonkit.token."
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    public func token(forCoreId coreId: String) -> String? {
        precondition(!coreId.isEmpty, "coreId must not be empty to prevent key collisions")
        return defaults.string(forKey: keyPrefix + coreId)
    }

    public func saveToken(_ token: String, forCoreId coreId: String) {
        precondition(!coreId.isEmpty, "coreId must not be empty to prevent key collisions")
        defaults.set(token, forKey: keyPrefix + coreId)
    }

    public func removeToken(forCoreId coreId: String) {
        precondition(!coreId.isEmpty, "coreId must not be empty to prevent key collisions")
        defaults.removeObject(forKey: keyPrefix + coreId)
    }

    public func removeAllTokens() {
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}

/// In-memory token storage for testing
public final class InMemoryTokenStorage: TokenStorage, @unchecked Sendable {
    private var tokens: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func token(forCoreId coreId: String) -> String? {
        precondition(!coreId.isEmpty, "coreId must not be empty to prevent key collisions")
        lock.lock()
        defer { lock.unlock() }
        return tokens[coreId]
    }

    public func saveToken(_ token: String, forCoreId coreId: String) {
        precondition(!coreId.isEmpty, "coreId must not be empty to prevent key collisions")
        lock.lock()
        defer { lock.unlock() }
        tokens[coreId] = token
    }

    public func removeToken(forCoreId coreId: String) {
        precondition(!coreId.isEmpty, "coreId must not be empty to prevent key collisions")
        lock.lock()
        defer { lock.unlock() }
        tokens.removeValue(forKey: coreId)
    }

    public func removeAllTokens() {
        lock.lock()
        defer { lock.unlock() }
        tokens.removeAll()
    }
}
