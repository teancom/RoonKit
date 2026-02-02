import Foundation
import Testing
@testable import RoonKit

@Suite("RegistrationTypes Tests")
struct RegistrationTypesTests {

    @Test("RegistrationRequest converts to dictionary")
    func registrationRequestToDictionary() {
        let extensionInfo = ExtensionInfo(
            extensionId: "com.test.app",
            displayName: "Test App",
            displayVersion: "1.0.0",
            publisher: "Test Publisher",
            email: "test@example.com",
            website: "https://example.com"
        )

        let request = RegistrationRequest(
            extensionInfo: extensionInfo,
            requiredServices: [RoonService.transport],
            optionalServices: [RoonService.browse],
            providedServices: [],
            token: "saved-token"
        )

        let dict = request.toDictionary()

        #expect(dict["extension_id"] as? String == "com.test.app")
        #expect(dict["display_name"] as? String == "Test App")
        #expect(dict["display_version"] as? String == "1.0.0")
        #expect(dict["publisher"] as? String == "Test Publisher")
        #expect(dict["email"] as? String == "test@example.com")
        #expect(dict["website"] as? String == "https://example.com")
        #expect(dict["required_services"] as? [String] == [RoonService.transport])
        #expect(dict["optional_services"] as? [String] == [RoonService.browse])
        #expect(dict["provided_services"] as? [String] == [])
        #expect(dict["token"] as? String == "saved-token")
    }

    @Test("RegistrationRequest omits nil website and token")
    func registrationRequestOmitsNil() {
        let extensionInfo = ExtensionInfo(
            extensionId: "com.test.app",
            displayName: "Test App",
            displayVersion: "1.0.0",
            publisher: "Test Publisher",
            email: "test@example.com"
        )

        let request = RegistrationRequest(extensionInfo: extensionInfo)
        let dict = request.toDictionary()

        #expect(dict["website"] == nil)
        #expect(dict["token"] == nil)
    }

    @Test("RegistrationResponse parses valid body")
    func registrationResponseParsesValidBody() {
        let body: [String: Any] = [
            "core_id": "core-123",
            "display_name": "My Roon Core",
            "display_version": "1.8.0",
            "token": "auth-token-xyz",
            "provided_services": ["com.roonlabs.transport:2"]
        ]

        let response = RegistrationResponse(from: body)

        #expect(response != nil)
        #expect(response?.coreId == "core-123")
        #expect(response?.displayName == "My Roon Core")
        #expect(response?.displayVersion == "1.8.0")
        #expect(response?.token == "auth-token-xyz")
        #expect(response?.providedServices == ["com.roonlabs.transport:2"])
    }

    @Test("RegistrationResponse returns nil for missing fields")
    func registrationResponseReturnsNilForMissingFields() {
        let incompleteBody: [String: Any] = [
            "core_id": "core-123",
            "display_name": "My Roon Core"
            // Missing display_version and token
        ]

        let response = RegistrationResponse(from: incompleteBody)

        #expect(response == nil)
    }

    @Test("RegistrationResponse returns nil for nil body")
    func registrationResponseReturnsNilForNilBody() {
        let response = RegistrationResponse(from: nil)

        #expect(response == nil)
    }

    @Test("RegistrationResponse handles missing provided_services")
    func registrationResponseHandlesMissingProvidedServices() {
        let body: [String: Any] = [
            "core_id": "core-123",
            "display_name": "My Roon Core",
            "display_version": "1.8.0",
            "token": "auth-token"
            // No provided_services
        ]

        let response = RegistrationResponse(from: body)

        #expect(response != nil)
        #expect(response?.providedServices == [])
    }

    @Test("CoreInfo decodes from JSON")
    func coreInfoDecodesFromJSON() throws {
        let json = """
            {
                "core_id": "core-abc",
                "display_name": "Living Room Core",
                "display_version": "2.0.0"
            }
            """.data(using: .utf8)!

        let coreInfo = try JSONDecoder().decode(CoreInfo.self, from: json)

        #expect(coreInfo.coreId == "core-abc")
        #expect(coreInfo.displayName == "Living Room Core")
        #expect(coreInfo.displayVersion == "2.0.0")
    }
}
