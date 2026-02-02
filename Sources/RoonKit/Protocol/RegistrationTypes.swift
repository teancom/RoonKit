import Foundation

/// Information about a Roon Core received during registration
public struct CoreInfo: Sendable, Codable {
    public let coreId: String
    public let displayName: String
    public let displayVersion: String

    enum CodingKeys: String, CodingKey {
        case coreId = "core_id"
        case displayName = "display_name"
        case displayVersion = "display_version"
    }
}

/// Request body for extension registration
public struct RegistrationRequest: Sendable {
    public let extensionId: String
    public let displayName: String
    public let displayVersion: String
    public let publisher: String
    public let email: String
    public let website: String?
    public let requiredServices: [String]
    public let optionalServices: [String]
    public let providedServices: [String]
    public let token: String?

    public init(
        extensionInfo: ExtensionInfo,
        requiredServices: [String] = [],
        optionalServices: [String] = [],
        providedServices: [String] = [],
        token: String? = nil
    ) {
        self.extensionId = extensionInfo.extensionId
        self.displayName = extensionInfo.displayName
        self.displayVersion = extensionInfo.displayVersion
        self.publisher = extensionInfo.publisher
        self.email = extensionInfo.email
        self.website = extensionInfo.website
        self.requiredServices = requiredServices
        self.optionalServices = optionalServices
        self.providedServices = providedServices
        self.token = token
    }

    /// Convert to dictionary for JSON encoding
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "extension_id": extensionId,
            "display_name": displayName,
            "display_version": displayVersion,
            "publisher": publisher,
            "email": email,
            "required_services": requiredServices,
            "optional_services": optionalServices,
            "provided_services": providedServices
        ]

        if let website = website {
            dict["website"] = website
        }

        if let token = token {
            dict["token"] = token
        }

        return dict
    }
}

/// Response from successful registration
public struct RegistrationResponse: Sendable {
    public let coreId: String
    public let displayName: String
    public let displayVersion: String
    public let token: String
    public let providedServices: [String]

    public init?(from body: [String: Any]?) {
        guard let body = body,
              let coreId = body["core_id"] as? String,
              let displayName = body["display_name"] as? String,
              let displayVersion = body["display_version"] as? String,
              let token = body["token"] as? String else {
            return nil
        }

        self.coreId = coreId
        self.displayName = displayName
        self.displayVersion = displayVersion
        self.token = token
        self.providedServices = body["provided_services"] as? [String] ?? []
    }
}
