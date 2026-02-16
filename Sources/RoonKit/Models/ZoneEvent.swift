import Foundation

/// Events received from zone subscription
public enum ZoneEvent: Sendable {
    /// Initial subscription with all zones
    case subscribed(zones: [Zone])

    /// Zones were added
    case zonesAdded([Zone])

    /// Zones were removed (by ID)
    case zonesRemoved([String])

    /// Zones were changed (full zone data)
    case zonesChanged([Zone])

    /// Seek position changed (lightweight update)
    case zonesSeekChanged([ZoneSeekUpdate])
}

/// Lightweight seek position update
public struct ZoneSeekUpdate: Sendable, Equatable {
    public let zoneId: String
    public let seekPosition: Double
    public let queueTimeRemaining: Double

    public init(zoneId: String, seekPosition: Double, queueTimeRemaining: Double) {
        self.zoneId = zoneId
        self.seekPosition = seekPosition
        self.queueTimeRemaining = queueTimeRemaining
    }

    public init?(from dict: [String: Any]) {
        guard let zoneId = dict["zone_id"] as? String else {
            return nil
        }

        self.zoneId = zoneId
        self.seekPosition = dict["seek_position"] as? Double ?? 0
        self.queueTimeRemaining = dict["queue_time_remaining"] as? Double ?? 0
    }
}

extension ZoneEvent {
    /// Parse ZoneEvents from a subscription response.
    ///
    /// A single Roon `Changed` response can contain **multiple** event types
    /// simultaneously (e.g., `zones_removed` + `zones_added` + `zones_changed`
    /// when outputs are grouped). All present fields are returned as separate events.
    /// Order matters: removed → added → changed → seek, matching the logical sequence.
    public static func from(response: RoonResponse) -> [ZoneEvent] {
        guard let body = response.body else { return [] }

        switch response.name {
        case "Subscribed":
            // Initial subscription response
            if let zonesArray = body["zones"] as? [[String: Any]] {
                let zones = zonesArray.compactMap { Zone(from: $0) }
                return [.subscribed(zones: zones)]
            }
            return [.subscribed(zones: [])]

        case "Changed":
            // A single Changed message can contain multiple event types.
            // Process all present fields — grouping operations send removed + added + changed together.
            var events: [ZoneEvent] = []

            if let removedIds = body["zones_removed"] as? [String], !removedIds.isEmpty {
                events.append(.zonesRemoved(removedIds))
            }

            if let addedArray = body["zones_added"] as? [[String: Any]], !addedArray.isEmpty {
                let zones = addedArray.compactMap { Zone(from: $0) }
                events.append(.zonesAdded(zones))
            }

            if let changedArray = body["zones_changed"] as? [[String: Any]], !changedArray.isEmpty {
                let zones = changedArray.compactMap { Zone(from: $0) }
                events.append(.zonesChanged(zones))
            }

            if let seekArray = body["zones_seek_changed"] as? [[String: Any]], !seekArray.isEmpty {
                let updates = seekArray.compactMap { ZoneSeekUpdate(from: $0) }
                events.append(.zonesSeekChanged(updates))
            }

            return events

        default:
            return []
        }
    }
}
