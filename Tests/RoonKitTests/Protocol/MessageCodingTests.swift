import Testing
import Foundation
@testable import RoonKit

// Helper to check if Data contains a string
fileprivate extension Data {
    func containsString(_ str: String) -> Bool {
        guard let text = String(data: self, encoding: .utf8) else { return false }
        return text.contains(str)
    }
}

@Suite("MessageCoding Tests")
struct MessageCodingTests {

    // MARK: - Encoding Tests

    @Test("Encode request without body")
    func encodeRequestWithoutBody() throws {
        let request = RoonRequest(
            requestId: 0,
            path: "com.roonlabs.registry:1/info"
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("MOO/1 REQUEST com.roonlabs.registry:1/info"))
        #expect(encoded.containsString("Request-Id: 0"))
        #expect(!encoded.containsString("Content-Length"))
        #expect(!encoded.containsString("Content-Type"))
    }

    @Test("Encode request with JSON body")
    func encodeRequestWithBody() throws {
        let request = RoonRequest(
            requestId: 5,
            path: "com.roonlabs.transport:2/control",
            body: ["zone_or_output_id": "zone123", "control": "play"]
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("MOO/1 REQUEST com.roonlabs.transport:2/control"))
        #expect(encoded.containsString("Request-Id: 5"))
        #expect(encoded.containsString("Content-Type: application/json"))
        #expect(encoded.containsString("Content-Length:"))
        #expect(encoded.containsString("zone123"))
        #expect(encoded.containsString("play"))
    }

    // MARK: - Decoding Tests

    @Test("Decode COMPLETE response without body")
    func decodeCompleteWithoutBody() throws {
        let message = """
            MOO/1 COMPLETE Success
            Request-Id: 0

            """

        let response = try MessageCoding.decode(message)

        #expect(response.verb == .complete)
        #expect(response.requestId == 0)
        #expect(response.name == "Success")
        #expect(response.body == nil)
        #expect(response.isSuccess)
        #expect(response.isComplete)
        #expect(!response.isContinuation)
    }

    @Test("Decode COMPLETE response with JSON body")
    func decodeCompleteWithBody() throws {
        let message = """
            MOO/1 COMPLETE Success
            Request-Id: 1
            Content-Length: 45
            Content-Type: application/json

            {"core_id":"abc123","display_name":"My Core"}
            """

        let response = try MessageCoding.decode(message)

        #expect(response.verb == .complete)
        #expect(response.requestId == 1)
        #expect(response.name == "Success")
        #expect(response.body?["core_id"] as? String == "abc123")
        #expect(response.body?["display_name"] as? String == "My Core")
    }

    @Test("Decode CONTINUE response for subscription")
    func decodeContinueResponse() throws {
        let message = """
            MOO/1 CONTINUE Subscribed
            Request-Id: 2
            Content-Type: application/json
            Content-Length: 20

            {"zones":[]}
            """

        let response = try MessageCoding.decode(message)

        #expect(response.verb == .continue)
        #expect(response.requestId == 2)
        #expect(response.name == "Subscribed")
        #expect(response.isContinuation)
        #expect(!response.isComplete)
        #expect(response.isSuccess)
    }

    @Test("Decode error response")
    func decodeErrorResponse() throws {
        let message = """
            MOO/1 COMPLETE InvalidRequest
            Request-Id: 3
            Content-Type: application/json
            Content-Length: 30

            {"error":"unknown service"}
            """

        let response = try MessageCoding.decode(message)

        #expect(response.verb == .complete)
        #expect(response.name == "InvalidRequest")
        #expect(!response.isSuccess)
        #expect(response.errorMessage == "unknown service")
    }

    @Test("Decode response with multi-word name")
    func decodeMultiWordName() throws {
        let message = """
            MOO/1 COMPLETE Network Error
            Request-Id: 4

            """

        let response = try MessageCoding.decode(message)

        #expect(response.name == "Network Error")
    }

    // MARK: - Incoming Request Tests

    @Test("Decode incoming REQUEST message")
    func decodeIncomingRequest() throws {
        let message = """
            MOO/1 REQUEST com.roonlabs.ping:1/ping
            Request-Id: 1

            """

        let decoded = try MessageCoding.decodeMessage(message)

        if case .request(let request) = decoded {
            #expect(request.requestId == 1)
            #expect(request.service == "com.roonlabs.ping:1")
            #expect(request.name == "ping")
            #expect(request.body == nil)
        } else {
            Issue.record("Expected incoming request, got response")
        }
    }

    @Test("Encode COMPLETE response")
    func encodeCompleteResponse() throws {
        let encoded = try MessageCoding.encodeResponse(requestId: 5, name: "Success")

        #expect(encoded.containsString("MOO/1 COMPLETE Success"))
        #expect(encoded.containsString("Request-Id: 5"))
    }

    @Test("Encode COMPLETE response with body")
    func encodeCompleteResponseWithBody() throws {
        let encoded = try MessageCoding.encodeResponse(
            requestId: 3,
            name: "Success",
            body: ["result": "ok"]
        )

        #expect(encoded.containsString("MOO/1 COMPLETE Success"))
        #expect(encoded.containsString("Request-Id: 3"))
        #expect(encoded.containsString("Content-Type: application/json"))
        #expect(encoded.containsString("result"))
    }

    // MARK: - Error Cases

    @Test("Decode fails on invalid format")
    func decodeInvalidFormat() throws {
        let message = "not a valid message"

        #expect(throws: MessageCodingError.self) {
            try MessageCoding.decode(message)
        }
    }

    @Test("Decode fails on missing request ID")
    func decodeMissingRequestId() throws {
        let message = """
            MOO/1 COMPLETE Success

            """

        #expect(throws: MessageCodingError.self) {
            try MessageCoding.decode(message)
        }
    }

    @Test("Decode fails on invalid verb")
    func decodeInvalidVerb() throws {
        let message = """
            MOO/1 INVALID Success
            Request-Id: 0

            """

        #expect(throws: MessageCodingError.self) {
            try MessageCoding.decode(message)
        }
    }

    // MARK: - Round-trip Tests

    @Test("Request service and method extraction")
    func requestServiceMethodExtraction() {
        let request = RoonRequest(
            requestId: 0,
            path: "com.roonlabs.transport:2/control"
        )

        #expect(request.service == "com.roonlabs.transport:2")
        #expect(request.method == "control")
    }

    @Test("Request method extraction with path without slash")
    func requestMethodExtractionNoSlash() {
        let request = RoonRequest(
            requestId: 0,
            path: "com.roonlabs.registry:1"
        )

        #expect(request.service == "com.roonlabs.registry:1")
        #expect(request.method == "")
    }

    @Test("RoonService path builder")
    func servicePathBuilder() {
        let path = RoonService.path(RoonService.transport, "control")
        #expect(path == "com.roonlabs.transport:2/control")
    }
}
