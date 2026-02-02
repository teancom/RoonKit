import Foundation

/// Errors that can occur during message encoding/decoding
public enum MessageCodingError: Error, Sendable {
    case invalidFormat(String)
    case missingRequestId
    case invalidRequestId
    case invalidVerb(String)
    case jsonEncodingFailed(String)
    case jsonDecodingFailed(String)
}

extension MessageCodingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let details):
            return "invalid message format: \(details)"
        case .missingRequestId:
            return "missing Request-Id header"
        case .invalidRequestId:
            return "invalid Request-Id value"
        case .invalidVerb(let verb):
            return "invalid verb: \(verb)"
        case .jsonEncodingFailed(let details):
            return "JSON encoding failed: \(details)"
        case .jsonDecodingFailed(let details):
            return "JSON decoding failed: \(details)"
        }
    }
}

/// Encodes and decodes MOO/1 protocol messages
public enum MessageCoding {

    // MARK: - Encoding

    /// Encode a request into MOO/1 format for sending over WebSocket as binary data
    public static func encode(_ request: RoonRequest) throws -> Data {
        var header = "MOO/1 REQUEST \(request.path)\n"
        header += "Request-Id: \(request.requestId)\n"

        if let body = request.body {
            let jsonData = try encodeJSON(body)
            header += "Content-Length: \(jsonData.count)\n"
            header += "Content-Type: application/json\n"
            header += "\n"

            guard let headerData = header.data(using: .utf8) else {
                throw MessageCodingError.invalidFormat("failed to encode header as UTF-8")
            }
            return headerData + jsonData
        } else {
            header += "\n"
            guard let headerData = header.data(using: .utf8) else {
                throw MessageCodingError.invalidFormat("failed to encode header as UTF-8")
            }
            return headerData
        }
    }

    /// Encode a COMPLETE response to an incoming request
    public static func encodeResponse(requestId: Int, name: String, body: [String: Any]? = nil) throws -> Data {
        var header = "MOO/1 COMPLETE \(name)\n"
        header += "Request-Id: \(requestId)\n"

        if let body = body {
            let jsonData = try encodeJSON(body)
            header += "Content-Length: \(jsonData.count)\n"
            header += "Content-Type: application/json\n"
            header += "\n"

            guard let headerData = header.data(using: .utf8) else {
                throw MessageCodingError.invalidFormat("failed to encode header as UTF-8")
            }
            return headerData + jsonData
        } else {
            header += "\n"
            guard let headerData = header.data(using: .utf8) else {
                throw MessageCodingError.invalidFormat("failed to encode header as UTF-8")
            }
            return headerData
        }
    }

    /// Encode a request into MOO/1 format for sending over WebSocket (legacy string version)
    @available(*, deprecated, message: "Use encode(_ request:) -> Data instead")
    public static func encodeAsString(_ request: RoonRequest) throws -> String {
        var message = "MOO/1 REQUEST \(request.path)\n"
        message += "Request-Id: \(request.requestId)\n"

        if let body = request.body {
            let jsonData = try encodeJSON(body)
            message += "Content-Length: \(jsonData.count)\n"
            message += "Content-Type: application/json\n"
            message += "\n"
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                message += jsonString
            }
        } else {
            message += "\n"
        }

        return message
    }

    // MARK: - Decoding

    /// Result of decoding a message - either a response or an incoming request
    public enum DecodedMessage {
        case response(RoonResponse)
        case request(IncomingRequest)
    }

    /// Decode a MOO/1 message received from WebSocket (for both requests and responses)
    public static func decodeMessage(_ message: String) throws -> DecodedMessage {
        // Split into header and body sections
        let parts = message.components(separatedBy: "\n\n")
        let headerSection = parts[0]
        let bodySection = parts.count > 1 ? parts.dropFirst().joined(separator: "\n\n") : nil

        // Parse header lines
        let headerLines = headerSection.components(separatedBy: "\n")
        guard let firstLine = headerLines.first else {
            throw MessageCodingError.invalidFormat("empty message")
        }

        // Parse first line: "MOO/1 VERB Name" or "MOO/1 VERB Service/Method"
        let firstLineParts = firstLine.components(separatedBy: " ")
        guard firstLineParts.count >= 3,
              firstLineParts[0] == "MOO/1" else {
            throw MessageCodingError.invalidFormat("invalid first line: \(firstLine)")
        }

        let verbStr = firstLineParts[1]
        let name = firstLineParts.dropFirst(2).joined(separator: " ")

        // Parse headers
        var headers: [String: String] = [:]
        for line in headerLines.dropFirst() {
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        // Extract Request-Id
        guard let requestIdString = headers["Request-Id"] else {
            throw MessageCodingError.missingRequestId
        }
        guard let requestId = Int(requestIdString) else {
            throw MessageCodingError.invalidRequestId
        }

        let contentType = headers["Content-Type"]

        // Parse body if present
        var body: [String: Any]?
        var rawBody: Data?

        if let bodySection = bodySection, !bodySection.isEmpty {
            if contentType == "application/json" {
                body = try decodeJSON(bodySection)
            } else {
                rawBody = bodySection.data(using: .utf8)
            }
        }

        // Handle REQUEST (incoming) vs COMPLETE/CONTINUE (response)
        if verbStr == "REQUEST" {
            // Parse service and method from name
            let pathParts = name.components(separatedBy: "/")
            let service = pathParts.first ?? name
            let method = pathParts.count > 1 ? pathParts.dropFirst().joined(separator: "/") : ""

            return .request(IncomingRequest(
                requestId: requestId,
                service: service,
                name: method,
                body: body
            ))
        } else {
            guard let verb = MessageVerb(rawValue: verbStr) else {
                throw MessageCodingError.invalidVerb(verbStr)
            }

            return .response(RoonResponse(
                verb: verb,
                requestId: requestId,
                name: name,
                contentType: contentType,
                body: body,
                rawBody: rawBody
            ))
        }
    }

    /// Decode a MOO/1 message received from WebSocket (responses only, for backward compatibility)
    public static func decode(_ message: String) throws -> RoonResponse {
        // Split into header and body sections
        let parts = message.components(separatedBy: "\n\n")
        let headerSection = parts[0]
        let bodySection = parts.count > 1 ? parts.dropFirst().joined(separator: "\n\n") : nil

        // Parse header lines
        let headerLines = headerSection.components(separatedBy: "\n")
        guard let firstLine = headerLines.first else {
            throw MessageCodingError.invalidFormat("empty message")
        }

        // Parse first line: "MOO/1 VERB Name"
        let firstLineParts = firstLine.components(separatedBy: " ")
        guard firstLineParts.count >= 3,
              firstLineParts[0] == "MOO/1" else {
            throw MessageCodingError.invalidFormat("invalid first line: \(firstLine)")
        }

        guard let verb = MessageVerb(rawValue: firstLineParts[1]) else {
            throw MessageCodingError.invalidVerb(firstLineParts[1])
        }

        let name = firstLineParts.dropFirst(2).joined(separator: " ")

        // Parse headers
        var headers: [String: String] = [:]
        for line in headerLines.dropFirst() {
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        // Extract Request-Id
        guard let requestIdString = headers["Request-Id"] else {
            throw MessageCodingError.missingRequestId
        }
        guard let requestId = Int(requestIdString) else {
            throw MessageCodingError.invalidRequestId
        }

        let contentType = headers["Content-Type"]

        // Parse body if present
        var body: [String: Any]?
        var rawBody: Data?

        if let bodySection = bodySection, !bodySection.isEmpty {
            if contentType == "application/json" {
                body = try decodeJSON(bodySection)
            } else {
                rawBody = bodySection.data(using: .utf8)
            }
        }

        return RoonResponse(
            verb: verb,
            requestId: requestId,
            name: name,
            contentType: contentType,
            body: body,
            rawBody: rawBody
        )
    }

    // MARK: - JSON Helpers

    private static func encodeJSON(_ value: [String: Any]) throws -> Data {
        do {
            return try JSONSerialization.data(withJSONObject: value, options: [])
        } catch {
            throw MessageCodingError.jsonEncodingFailed(error.localizedDescription)
        }
    }

    private static func decodeJSON(_ string: String) throws -> [String: Any]? {
        guard let data = string.data(using: .utf8) else {
            throw MessageCodingError.jsonDecodingFailed("invalid UTF-8")
        }

        do {
            let object = try JSONSerialization.jsonObject(with: data)
            return object as? [String: Any]
        } catch {
            throw MessageCodingError.jsonDecodingFailed(error.localizedDescription)
        }
    }
}
