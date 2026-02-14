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

@Suite("MessageCoding Edge Cases")
struct MessageCodingEdgeCasesTests {

    // MARK: - Encoding Edge Cases

    @Test("Encode request with large request ID")
    func encodeRequestLargeId() throws {
        let request = RoonRequest(
            requestId: 999999,
            path: "com.roonlabs.transport:2/control"
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("Request-Id: 999999"))
    }

    @Test("Encode request with complex JSON body")
    func encodeRequestComplexJson() throws {
        let request = RoonRequest(
            requestId: 1,
            path: "com.roonlabs.browse:1/browse",
            body: [
                "browse_key": "root",
                "offset": 0,
                "count": 50,
                "multi_session_key": ["session": "123", "key": "nested"]
            ]
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("browse_key"))
        #expect(encoded.containsString("multi_session_key"))
        #expect(String(data: encoded, encoding: .utf8)?.contains("session") ?? false)
    }

    @Test("Encode request with empty dict body")
    func encodeRequestEmptyDictBody() throws {
        let request = RoonRequest(
            requestId: 5,
            path: "com.roonlabs.registry:1/ping",
            body: [:]
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("Content-Type: application/json"))
        #expect(encoded.containsString("Content-Length:"))
    }

    @Test("Encode request with special characters in path")
    func encodeRequestSpecialPath() throws {
        let request = RoonRequest(
            requestId: 1,
            path: "com.roonlabs.service:1/method_with_underscores"
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("method_with_underscores"))
    }

    @Test("Encode response with empty body dict")
    func encodeResponseEmptyBody() throws {
        let encoded = try MessageCoding.encodeResponse(
            requestId: 1,
            name: "Success",
            body: [:]
        )

        #expect(encoded.containsString("MOO/1 COMPLETE Success"))
        #expect(encoded.containsString("Request-Id: 1"))
        #expect(encoded.containsString("Content-Type: application/json"))
    }

    @Test("Encode response with name containing spaces")
    func encodeResponseNameWithSpaces() throws {
        let encoded = try MessageCoding.encodeResponse(
            requestId: 2,
            name: "Network Error"
        )

        #expect(encoded.containsString("Network Error"))
    }

    // MARK: - Decoding Edge Cases

    @Test("Decode response with extra whitespace in header values")
    func decodeExtraWhitespace() throws {
        let message = """
            MOO/1 COMPLETE Success
            Request-Id:    42
            Content-Type:   application/json
            Content-Length: 5

            {}
            """

        let response = try MessageCoding.decode(message)

        #expect(response.requestId == 42)
        #expect(response.name == "Success")
    }

    @Test("Decode response with no blank line before body")
    func decodeNoBlankLineBeforeBody() throws {
        let message = """
            MOO/1 COMPLETE Success
            Request-Id: 1
            Content-Type: application/json
            Content-Length: 2

            {}
            """

        let response = try MessageCoding.decode(message)

        #expect(response.requestId == 1)
        #expect(response.body != nil)
    }

    @Test("Decode response with JSON containing newlines")
    func decodeJsonWithNewlines() throws {
        let json = """
            {
              "key": "value",
              "nested": {
                "inner": "data"
              }
            }
            """
        let message = """
            MOO/1 COMPLETE Success
            Request-Id: 1
            Content-Type: application/json
            Content-Length: \(json.count)

            \(json)
            """

        let response = try MessageCoding.decode(message)

        #expect(response.body?["key"] as? String == "value")
        #expect(response.body?["nested"] != nil)
    }

    @Test("Decode response with case-sensitive verb")
    func decodeVerbCaseSensitive() throws {
        let message = """
            MOO/1 COMPLETE Success
            Request-Id: 1

            """

        let response = try MessageCoding.decode(message)

        #expect(response.verb == .complete)
    }

    @Test("Decode response with request ID zero")
    func decodeRequestIdZero() throws {
        let message = """
            MOO/1 COMPLETE Success
            Request-Id: 0

            """

        let response = try MessageCoding.decode(message)

        #expect(response.requestId == 0)
    }

    @Test("Decode response with negative request ID")
    func decodeNegativeRequestId() throws {
        let message = """
            MOO/1 COMPLETE Success
            Request-Id: -1

            """

        let response = try MessageCoding.decode(message)

        #expect(response.requestId == -1)
    }

    @Test("Decode incoming REQUEST message with body")
    func decodeIncomingRequestWithBody() throws {
        let message = """
            MOO/1 REQUEST com.roonlabs.ping:1/ping
            Request-Id: 10
            Content-Type: application/json
            Content-Length: 11

            {"ping":"me"}
            """

        let decoded = try MessageCoding.decodeMessage(message)

        if case .request(let request) = decoded {
            #expect(request.requestId == 10)
            #expect(request.service == "com.roonlabs.ping:1")
            #expect(request.name == "ping")
            #expect(request.body != nil)
        } else {
            Issue.record("Expected incoming request")
        }
    }

    @Test("Decode response with multiple blank lines before body")
    func decodeMultipleBlankLines() throws {
        let message = """
            MOO/1 COMPLETE Success
            Request-Id: 1
            Content-Type: application/json
            Content-Length: 5


            {}
            """

        let response = try MessageCoding.decode(message)

        #expect(response.requestId == 1)
    }

    // MARK: - Error Cases

    @Test("Decode fails with invalid MOO version")
    func decodeInvalidVersion() throws {
        let message = """
            MOO/2 COMPLETE Success
            Request-Id: 1

            """

        #expect(throws: MessageCodingError.self) {
            try MessageCoding.decode(message)
        }
    }

    @Test("Decode fails with missing verb")
    func decodeMissingVerb() throws {
        let message = """
            MOO/1 Success
            Request-Id: 1

            """

        #expect(throws: MessageCodingError.self) {
            try MessageCoding.decode(message)
        }
    }

    @Test("Decode ignores lines without colons in header")
    func decodeIgnoresInvalidHeaderLines() throws {
        let message = """
            MOO/1 COMPLETE Success
            InvalidHeader
            Request-Id: 1

            """

        let response = try MessageCoding.decode(message)

        // Invalid header lines are silently ignored
        #expect(response.requestId == 1)
        #expect(response.name == "Success")
    }

    @Test("Decode fails with non-numeric request ID")
    func decodeNonNumericRequestId() throws {
        let message = """
            MOO/1 COMPLETE Success
            Request-Id: abc

            """

        #expect(throws: MessageCodingError.self) {
            try MessageCoding.decode(message)
        }
    }

    @Test("Decode fails on completely empty message")
    func decodeEmptyMessage() throws {
        let message = ""

        #expect(throws: MessageCodingError.self) {
            try MessageCoding.decode(message)
        }
    }

    @Test("Decode fails with only whitespace")
    func decodeOnlyWhitespace() throws {
        let message = """


            """

        #expect(throws: MessageCodingError.self) {
            try MessageCoding.decode(message)
        }
    }

    // MARK: - Response Type Detection

    @Test("Response isSuccess for Subscribed")
    func responseIsSuccessSubscribed() throws {
        let message = """
            MOO/1 CONTINUE Subscribed
            Request-Id: 1

            """

        let response = try MessageCoding.decode(message)

        #expect(response.isSuccess == true)
        #expect(response.isContinuation == true)
    }

    @Test("Response isSuccess for Registered")
    func responseIsSuccessRegistered() throws {
        let message = """
            MOO/1 COMPLETE Registered
            Request-Id: 1

            """

        let response = try MessageCoding.decode(message)

        #expect(response.isSuccess == true)
    }

    @Test("Response isSuccess for Changed")
    func responseIsSuccessChanged() throws {
        let message = """
            MOO/1 CONTINUE Changed
            Request-Id: 1

            """

        let response = try MessageCoding.decode(message)

        #expect(response.isSuccess == true)
        #expect(response.isContinuation == true)
    }

    @Test("Response isSuccess false for error")
    func responseIsSuccessFalseError() throws {
        let message = """
            MOO/1 COMPLETE InvalidService
            Request-Id: 1

            """

        let response = try MessageCoding.decode(message)

        #expect(response.isSuccess == false)
    }

    @Test("Error message extraction from body")
    func errorMessageFromBody() throws {
        let message = """
            MOO/1 COMPLETE InvalidRequest
            Request-Id: 1
            Content-Type: application/json
            Content-Length: 30

            {"error":"unknown service"}
            """

        let response = try MessageCoding.decode(message)

        #expect(response.errorMessage == "unknown service")
    }

    @Test("Error message fallback to name")
    func errorMessageFallbackToName() throws {
        let message = """
            MOO/1 COMPLETE Timeout
            Request-Id: 1

            """

        let response = try MessageCoding.decode(message)

        #expect(response.errorMessage == "Timeout")
    }

    // MARK: - Content-Type Handling

    @Test("Decode response without content type")
    func decodeNoContentType() throws {
        let message = """
            MOO/1 COMPLETE Success
            Request-Id: 1

            """

        let response = try MessageCoding.decode(message)

        #expect(response.contentType == nil)
        #expect(response.body == nil)
    }

    @Test("Decode response with non-JSON content type")
    func decodeNonJsonContentType() throws {
        let message = """
            MOO/1 COMPLETE Success
            Request-Id: 1
            Content-Type: text/plain
            Content-Length: 5

            hello
            """

        let response = try MessageCoding.decode(message)

        #expect(response.contentType == "text/plain")
        #expect(response.body == nil)
        #expect(response.rawBody != nil)
    }

    // MARK: - RoonService Constants

    @Test("RoonService constants")
    func roonServiceConstants() {
        #expect(RoonService.registry == "com.roonlabs.registry:1")
        #expect(RoonService.transport == "com.roonlabs.transport:2")
        #expect(RoonService.browse == "com.roonlabs.browse:1")
        #expect(RoonService.image == "com.roonlabs.image:1")
        #expect(RoonService.status == "com.roonlabs.status:1")
        #expect(RoonService.pairing == "com.roonlabs.pairing:1")
        #expect(RoonService.ping == "com.roonlabs.ping:1")
    }

    @Test("RoonService path builder")
    func roonServicePathBuilder() {
        #expect(RoonService.path(RoonService.transport, "play") == "com.roonlabs.transport:2/play")
        #expect(RoonService.path(RoonService.browse, "browse") == "com.roonlabs.browse:1/browse")
    }
}
