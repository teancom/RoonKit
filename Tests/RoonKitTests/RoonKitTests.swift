import Testing
@testable import RoonKit

@Suite("RoonKit Tests")
struct RoonKitTests {

    @Test("Library version is defined")
    func libraryVersionIsDefined() {
        #expect(!RoonKit.version.isEmpty)
        #expect(RoonKit.version == "0.1.0")
    }
}
