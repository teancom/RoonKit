import Foundation
import Testing
@testable import RoonKit

@Suite("TokenStorage Tests")
struct TokenStorageTests {

    @Test("InMemoryTokenStorage stores and retrieves tokens")
    func inMemoryStoreAndRetrieve() {
        let storage = InMemoryTokenStorage()

        storage.saveToken("token123", forCoreId: "core-abc")

        #expect(storage.token(forCoreId: "core-abc") == "token123")
        #expect(storage.token(forCoreId: "core-xyz") == nil)
    }

    @Test("InMemoryTokenStorage removes specific token")
    func inMemoryRemoveSpecific() {
        let storage = InMemoryTokenStorage()

        storage.saveToken("token1", forCoreId: "core1")
        storage.saveToken("token2", forCoreId: "core2")

        storage.removeToken(forCoreId: "core1")

        #expect(storage.token(forCoreId: "core1") == nil)
        #expect(storage.token(forCoreId: "core2") == "token2")
    }

    @Test("InMemoryTokenStorage removes all tokens")
    func inMemoryRemoveAll() {
        let storage = InMemoryTokenStorage()

        storage.saveToken("token1", forCoreId: "core1")
        storage.saveToken("token2", forCoreId: "core2")

        storage.removeAllTokens()

        #expect(storage.token(forCoreId: "core1") == nil)
        #expect(storage.token(forCoreId: "core2") == nil)
    }

    @Test("InMemoryTokenStorage overwrites existing token")
    func inMemoryOverwrite() {
        let storage = InMemoryTokenStorage()

        storage.saveToken("old-token", forCoreId: "core1")
        storage.saveToken("new-token", forCoreId: "core1")

        #expect(storage.token(forCoreId: "core1") == "new-token")
    }

    @Test("UserDefaultsTokenStorage uses correct key prefix")
    func userDefaultsKeyPrefix() {
        let defaults = UserDefaults(suiteName: "test-suite")!
        defaults.removePersistentDomain(forName: "test-suite")

        let storage = UserDefaultsTokenStorage(
            defaults: defaults,
            keyPrefix: "test.prefix."
        )

        storage.saveToken("token123", forCoreId: "core-abc")

        // Verify token is stored with correct prefix
        #expect(defaults.string(forKey: "test.prefix.core-abc") == "token123")

        // Clean up
        defaults.removePersistentDomain(forName: "test-suite")
    }
}
