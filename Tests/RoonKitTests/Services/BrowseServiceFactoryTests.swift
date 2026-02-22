import Testing
@testable import RoonKit

/// Tests for the BrowseService factory method on RoonClient.
///
/// Verifies that createBrowseService() returns independent BrowseService instances
/// that don't interfere with the client's built-in browse property.
@Suite("BrowseService Factory Tests")
struct BrowseServiceFactoryTests {

    @Test("createBrowseService returns a BrowseService instance")
    func factoryReturnsValidService() async {
        let client = RoonClient(
            host: "192.168.1.100",
            port: 9100,
            extensionId: "com.test.roonkit",
            displayName: "Test Client",
            displayVersion: "1.0.0",
            publisher: "Test Publisher",
            email: "test@example.com"
        )

        let service = await client.createBrowseService()

        // Service should be non-nil and usable
        let level = await service.currentLevel
        #expect(level == 0)
    }

    @Test("Multiple factory calls return different service instances")
    func multipleCallsReturnDifferentInstances() async {
        let client = RoonClient(
            host: "192.168.1.100",
            port: 9100,
            extensionId: "com.test.roonkit",
            displayName: "Test Client",
            displayVersion: "1.0.0",
            publisher: "Test Publisher",
            email: "test@example.com"
        )

        let service1 = await client.createBrowseService()
        let service2 = await client.createBrowseService()

        // Verify they are different actor instances by checking object identity
        // (actors are reference types)
        #expect(service1 !== service2)
    }

    @Test("Factory-created service is independent from client.browse")
    func factoryServiceIsIndependentFromBuiltIn() async {
        let client = RoonClient(
            host: "192.168.1.100",
            port: 9100,
            extensionId: "com.test.roonkit",
            displayName: "Test Client",
            displayVersion: "1.0.0",
            publisher: "Test Publisher",
            email: "test@example.com"
        )

        let factoryService = await client.createBrowseService()
        let builtInService = await client.browse

        // Verify they are different actor instances
        #expect(factoryService !== builtInService)
    }

    @Test("Factory service initializes with zero current level")
    func factoryServiceStartsAtZeroLevel() async {
        let client = RoonClient(
            host: "192.168.1.100",
            port: 9100,
            extensionId: "com.test.roonkit",
            displayName: "Test Client",
            displayVersion: "1.0.0",
            publisher: "Test Publisher",
            email: "test@example.com"
        )

        let service = await client.createBrowseService()
        let level = await service.currentLevel

        #expect(level == 0)
    }

    @Test("Factory service has nil current list initially")
    func factoryServiceHasNilListInitially() async {
        let client = RoonClient(
            host: "192.168.1.100",
            port: 9100,
            extensionId: "com.test.roonkit",
            displayName: "Test Client",
            displayVersion: "1.0.0",
            publisher: "Test Publisher",
            email: "test@example.com"
        )

        let service = await client.createBrowseService()
        let list = await service.currentList

        #expect(list == nil)
    }
}
