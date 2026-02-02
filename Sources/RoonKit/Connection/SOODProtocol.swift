import Foundation

/// SOOD Protocol handler for encoding/decoding UDP discovery messages
enum SOODProtocol {
    // MARK: - Constants

    private static let HEADER = "SOOD"
    private static let VERSION: UInt8 = 2
    private static let QUERY_TYPE: UInt8 = UInt8(ascii: "Q")
    private static let RESPONSE_TYPE: UInt8 = UInt8(ascii: "X")

    // MARK: - Types

    struct Message: Sendable {
        let type: MessageType
        let properties: [String: String?]
        let sourceIP: String?
        let sourcePort: Int?

        enum MessageType: Sendable {
            case query
            case response
        }
    }

    // MARK: - Encoding

    /// Encode a discovery query with the given transaction ID
    static func encodeQuery(transactionId: String) -> Data {
        var buffer = Data(capacity: 256)

        // Header: "SOOD\x02Q"
        buffer.append(contentsOf: HEADER.utf8)
        buffer.append(VERSION)
        buffer.append(QUERY_TYPE)

        // Properties: _tid=<transactionId>
        let properties = ["_tid": transactionId]

        for (name, value) in properties {
            encodeProperty(buffer: &buffer, name: name, value: value)
        }

        return buffer
    }

    /// Encode a single property in SOOD format
    private static func encodeProperty(buffer: inout Data, name: String, value: String?) {
        // Property format:
        // 1 byte: name length
        // N bytes: name (UTF-8)
        // 2 bytes: value length (big-endian)
        // M bytes: value (UTF-8) or null indicator

        let nameData = name.data(using: .utf8) ?? Data()
        guard nameData.count < 256 else { return }

        buffer.append(UInt8(nameData.count))
        buffer.append(contentsOf: nameData)

        if let value = value {
            let valueData = value.data(using: .utf8) ?? Data()
            let valueLength = UInt16(valueData.count)
            buffer.append(UInt8(valueLength >> 8))
            buffer.append(UInt8(valueLength & 0xFF))
            buffer.append(contentsOf: valueData)
        } else {
            // NULL value: length = 0xFFFF
            buffer.append(0xFF)
            buffer.append(0xFF)
        }
    }

    // MARK: - Decoding

    /// Decode a SOOD message from data received on the network
    static func decode(data: Data, sourceIP: String?, sourcePort: Int?) -> Message? {
        guard data.count >= 6 else { return nil }

        // Check header
        let headerData = data.subdata(in: 0..<4)
        guard let header = String(data: headerData, encoding: .utf8), header == HEADER else {
            return nil
        }

        // Check version
        guard data[4] == VERSION else { return nil }

        // Check message type
        let messageType: Message.MessageType
        switch data[5] {
        case QUERY_TYPE:
            messageType = .query
        case RESPONSE_TYPE:
            messageType = .response
        default:
            return nil
        }

        // Parse properties
        var properties: [String: String?] = [:]
        var pos = 6
        var replyAddr: String? = sourceIP
        var replyPort: Int? = sourcePort

        while pos < data.count {
            // Read property name
            guard pos < data.count else { break }
            let nameLength = Int(data[pos])
            pos += 1

            guard nameLength > 0 && pos + nameLength <= data.count else { break }
            let nameData = data.subdata(in: pos..<pos + nameLength)
            guard let name = String(data: nameData, encoding: .utf8) else { break }
            pos += nameLength

            // Read property value length (2 bytes, big-endian)
            guard pos + 2 <= data.count else { break }
            let valueLengthHigh = Int(data[pos])
            let valueLengthLow = Int(data[pos + 1])
            let valueLength = (valueLengthHigh << 8) | valueLengthLow
            pos += 2

            // Read property value
            let value: String?
            if valueLength == 0xFFFF {
                value = nil
            } else if valueLength == 0 {
                value = ""
            } else {
                guard pos + valueLength <= data.count else { break }
                let valueData = data.subdata(in: pos..<pos + valueLength)
                value = String(data: valueData, encoding: .utf8)
                pos += valueLength
            }

            // Special handling for reply address/port
            if name == "_replyaddr" {
                replyAddr = value
            } else if name == "_replyport" {
                replyPort = value.flatMap(Int.init)
            } else {
                properties[name] = value
            }
        }

        return Message(
            type: messageType,
            properties: properties,
            sourceIP: replyAddr,
            sourcePort: replyPort
        )
    }
}
