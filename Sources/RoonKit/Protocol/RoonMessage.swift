import Foundation

/// Verbs used in the MOO/1 protocol
public enum MessageVerb: String, Sendable {
    case request = "REQUEST"
    case complete = "COMPLETE"
    case `continue` = "CONTINUE"
}

/// A request message to send to Roon Core
public struct RoonRequest: Sendable {
    /// Unique identifier for correlating responses
    public let requestId: Int

    /// Service and method path (e.g., "com.roonlabs.transport:2/control")
    public let path: String

    /// Optional JSON body
    public nonisolated(unsafe) let body: [String: Any]?

    public init(requestId: Int, path: String, body: [String: Any]? = nil) {
        self.requestId = requestId
        self.path = path
        self.body = body
    }

    /// Service name extracted from path (e.g., "com.roonlabs.transport:2")
    public var service: String {
        if let slashIndex = path.firstIndex(of: "/") {
            return String(path[..<slashIndex])
        }
        return path
    }

    /// Method name extracted from path (e.g., "control")
    public var method: String {
        if let slashIndex = path.firstIndex(of: "/") {
            return String(path[path.index(after: slashIndex)...])
        }
        return ""
    }
}

/// A response message received from Roon Core
public struct RoonResponse: Sendable {
    /// The verb indicating response type
    public let verb: MessageVerb

    /// Request ID this response correlates to
    public let requestId: Int

    /// Response name (e.g., "Success", "Subscribed", "Changed", "InvalidRequest")
    public let name: String

    /// Optional content type of body
    public let contentType: String?

    /// Optional JSON body (nil for binary responses or empty bodies)
    public nonisolated(unsafe) let body: [String: Any]?

    /// Raw body data (for binary content like images)
    public let rawBody: Data?

    public init(
        verb: MessageVerb,
        requestId: Int,
        name: String,
        contentType: String? = nil,
        body: [String: Any]? = nil,
        rawBody: Data? = nil
    ) {
        self.verb = verb
        self.requestId = requestId
        self.name = name
        self.contentType = contentType
        self.body = body
        self.rawBody = rawBody
    }

    /// Whether this response indicates success
    public var isSuccess: Bool {
        name == "Success" || name == "Subscribed" || name == "Registered" || name == "Changed"
    }

    /// Whether this is a subscription update (more responses to follow)
    public var isContinuation: Bool {
        verb == .continue
    }

    /// Whether this is the final response for this request
    public var isComplete: Bool {
        verb == .complete
    }

    /// Extract error message if this is an error response
    public var errorMessage: String? {
        if isSuccess { return nil }
        if let error = body?["error"] as? String {
            return error
        }
        return name
    }
}

/// Common Roon service paths
public enum RoonService {
    public static let registry = "com.roonlabs.registry:1"
    public static let transport = "com.roonlabs.transport:2"
    public static let browse = "com.roonlabs.browse:1"
    public static let image = "com.roonlabs.image:1"
    public static let status = "com.roonlabs.status:1"
    public static let pairing = "com.roonlabs.pairing:1"
    public static let ping = "com.roonlabs.ping:1"

    /// Build a full path from service and method
    public static func path(_ service: String, _ method: String) -> String {
        "\(service)/\(method)"
    }
}

/// An incoming request from Roon Core (for services we provide)
public struct IncomingRequest: Sendable {
    /// Request ID for sending the response
    public let requestId: Int

    /// Service name (e.g., "com.roonlabs.ping:1")
    public let service: String

    /// Method name (e.g., "ping")
    public let name: String

    /// Optional JSON body
    public nonisolated(unsafe) let body: [String: Any]?

    public init(requestId: Int, service: String, name: String, body: [String: Any]? = nil) {
        self.requestId = requestId
        self.service = service
        self.name = name
        self.body = body
    }
}
