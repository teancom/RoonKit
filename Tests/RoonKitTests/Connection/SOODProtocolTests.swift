import XCTest
@testable import RoonKit

final class SOODProtocolTests: XCTestCase {
    // MARK: - Query Encoding Tests

    func testEncodeQuery() {
        let transactionId = "test-tid-12345"
        let data = SOODProtocol.encodeQuery(transactionId: transactionId)

        // Verify header
        XCTAssertGreaterThanOrEqual(data.count, 6)
        let headerData = data.subdata(in: 0..<4)
        let header = String(data: headerData, encoding: .utf8)
        XCTAssertEqual(header, "SOOD")

        // Verify version
        XCTAssertEqual(data[4], 2)

        // Verify message type (Q for query)
        XCTAssertEqual(data[5], UInt8(ascii: "Q"))
    }

    func testEncodeQueryContainsTransactionId() {
        let transactionId = "abc-123"
        let data = SOODProtocol.encodeQuery(transactionId: transactionId)

        // The data should contain the transaction ID somewhere
        let dataString = String(data: data, encoding: .utf8)
        XCTAssertTrue(dataString?.contains(transactionId) ?? false)
    }

    // MARK: - Response Decoding Tests

    func testDecodeValidResponse() {
        // Create a minimal valid SOOD response
        var data = Data()
        data.append(contentsOf: "SOOD".utf8)
        data.append(2)  // Version
        data.append(UInt8(ascii: "X"))  // Response type

        // Add a simple property: _corid = "abc123"
        let propName = "_corid"
        let propValue = "abc123"

        data.append(UInt8(propName.count))
        data.append(contentsOf: propName.utf8)

        let valueLength = UInt16(propValue.count)
        data.append(UInt8(valueLength >> 8))
        data.append(UInt8(valueLength & 0xFF))
        data.append(contentsOf: propValue.utf8)

        let message = SOODProtocol.decode(data: data, sourceIP: "192.168.1.100", sourcePort: 9003)

        XCTAssertNotNil(message)
        XCTAssertEqual(message?.type, .response)
        XCTAssertEqual(message?.properties["_corid"], "abc123")
        XCTAssertEqual(message?.sourceIP, "192.168.1.100")
        XCTAssertEqual(message?.sourcePort, 9003)
    }

    func testDecodeQuery() {
        // Create a minimal valid SOOD query
        var data = Data()
        data.append(contentsOf: "SOOD".utf8)
        data.append(2)  // Version
        data.append(UInt8(ascii: "Q"))  // Query type

        let message = SOODProtocol.decode(data: data, sourceIP: "192.168.1.100", sourcePort: 9003)

        XCTAssertNotNil(message)
        XCTAssertEqual(message?.type, .query)
    }

    func testDecodeMultipleProperties() {
        // Create response with multiple properties
        var data = Data()
        data.append(contentsOf: "SOOD".utf8)
        data.append(2)
        data.append(UInt8(ascii: "X"))

        // Property 1: _corid = "core123"
        data.append(UInt8("_corid".count))
        data.append(contentsOf: "_corid".utf8)
        data.append(0)
        data.append(UInt8("core123".count))
        data.append(contentsOf: "core123".utf8)

        // Property 2: _displayname = "My Roon Core"
        data.append(UInt8("_displayname".count))
        data.append(contentsOf: "_displayname".utf8)
        data.append(0)
        data.append(UInt8("My Roon Core".count))
        data.append(contentsOf: "My Roon Core".utf8)

        let message = SOODProtocol.decode(data: data, sourceIP: "192.168.1.100", sourcePort: 9003)

        XCTAssertNotNil(message)
        XCTAssertEqual(message?.properties["_corid"], "core123")
        XCTAssertEqual(message?.properties["_displayname"], "My Roon Core")
    }

    func testDecodeWithReplyAddress() {
        var data = Data()
        data.append(contentsOf: "SOOD".utf8)
        data.append(2)
        data.append(UInt8(ascii: "X"))

        // _replyaddr should override sourceIP
        let propName = "_replyaddr"
        let propValue = "192.168.1.50"
        data.append(UInt8(propName.count))
        data.append(contentsOf: propName.utf8)
        data.append(0)
        data.append(UInt8(propValue.count))
        data.append(contentsOf: propValue.utf8)

        let message = SOODProtocol.decode(data: data, sourceIP: "10.0.0.1", sourcePort: 9003)

        XCTAssertNotNil(message)
        XCTAssertEqual(message?.sourceIP, "192.168.1.50")
    }

    func testDecodeWithReplyPort() {
        var data = Data()
        data.append(contentsOf: "SOOD".utf8)
        data.append(2)
        data.append(UInt8(ascii: "X"))

        // _replyport should override sourcePort
        let propName = "_replyport"
        let propValue = "9101"
        data.append(UInt8(propName.count))
        data.append(contentsOf: propName.utf8)
        data.append(0)
        data.append(UInt8(propValue.count))
        data.append(contentsOf: propValue.utf8)

        let message = SOODProtocol.decode(data: data, sourceIP: "192.168.1.100", sourcePort: 9003)

        XCTAssertNotNil(message)
        XCTAssertEqual(message?.sourcePort, 9101)
    }

    func testDecodeNullProperty() {
        var data = Data()
        data.append(contentsOf: "SOOD".utf8)
        data.append(2)
        data.append(UInt8(ascii: "X"))

        // Property with null value (0xFFFF)
        data.append(UInt8("_optional".count))
        data.append(contentsOf: "_optional".utf8)
        data.append(0xFF)
        data.append(0xFF)

        let message = SOODProtocol.decode(data: data, sourceIP: "192.168.1.100", sourcePort: 9003)

        XCTAssertNotNil(message)
        // For null values, the property is still in the dictionary but has a nil value
        XCTAssertTrue(message?.properties.keys.contains("_optional") ?? false)
        XCTAssertNil(message?.properties["_optional"] ?? "")
    }

    func testDecodeEmptyProperty() {
        var data = Data()
        data.append(contentsOf: "SOOD".utf8)
        data.append(2)
        data.append(UInt8(ascii: "X"))

        // Property with empty value (length = 0)
        data.append(UInt8("_empty".count))
        data.append(contentsOf: "_empty".utf8)
        data.append(0)
        data.append(0)

        let message = SOODProtocol.decode(data: data, sourceIP: "192.168.1.100", sourcePort: 9003)

        XCTAssertNotNil(message)
        XCTAssertEqual(message?.properties["_empty"], "")
    }

    func testDecodeInvalidHeader() {
        var data = Data()
        data.append(contentsOf: "NOPE".utf8)
        data.append(2)
        data.append(UInt8(ascii: "X"))

        let message = SOODProtocol.decode(data: data, sourceIP: "192.168.1.100", sourcePort: 9003)
        XCTAssertNil(message)
    }

    func testDecodeInvalidVersion() {
        var data = Data()
        data.append(contentsOf: "SOOD".utf8)
        data.append(3)  // Wrong version
        data.append(UInt8(ascii: "X"))

        let message = SOODProtocol.decode(data: data, sourceIP: "192.168.1.100", sourcePort: 9003)
        XCTAssertNil(message)
    }

    func testDecodeTooShort() {
        let data = Data([0, 1, 2])  // Too short
        let message = SOODProtocol.decode(data: data, sourceIP: "192.168.1.100", sourcePort: 9003)
        XCTAssertNil(message)
    }

    func testDecodeInvalidMessageType() {
        var data = Data()
        data.append(contentsOf: "SOOD".utf8)
        data.append(2)
        data.append(UInt8(ascii: "Z"))  // Invalid type

        let message = SOODProtocol.decode(data: data, sourceIP: "192.168.1.100", sourcePort: 9003)
        XCTAssertNil(message)
    }

    // MARK: - Round-trip Tests

    func testRoundTripQuery() {
        let transactionId = "test-roundtrip-123"
        let encoded = SOODProtocol.encodeQuery(transactionId: transactionId)

        // Decode as if we received our own query
        let message = SOODProtocol.decode(data: encoded, sourceIP: nil, sourcePort: nil)

        XCTAssertNotNil(message)
        XCTAssertEqual(message?.type, .query)
        XCTAssertEqual(message?.properties["_tid"], transactionId)
    }
}
