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
    /// Parse a ZoneEvent from a subscription response
    public static func from(response: RoonResponse) -> ZoneEvent? {
        guard let body = response.body else { return nil }

        switch response.name {
        case "Subscribed":
            // Initial subscription response
            if let zonesArray = body["zones"] as? [[String: Any]] {
                let zones = zonesArray.compactMap { Zone(from: $0) }
                return .subscribed(zones: zones)
            }
            return .subscribed(zones: [])

        case "Changed":
            // Incremental update
            if let removedIds = body["zones_removed"] as? [String], !removedIds.isEmpty {
                return .zonesRemoved(removedIds)
            }

            if let addedArray = body["zones_added"] as? [[String: Any]], !addedArray.isEmpty {
                let zones = addedArray.compactMap { Zone(from: $0) }
                return .zonesAdded(zones)
            }

            if let changedArray = body["zones_changed"] as? [[String: Any]], !changedArray.isEmpty {
                let zones = changedArray.compactMap { Zone(from: $0) }
                return .zonesChanged(zones)
            }

            if let seekArray = body["zones_seek_changed"] as? [[String: Any]], !seekArray.isEmpty {
                let updates = seekArray.compactMap { ZoneSeekUpdate(from: $0) }
                return .zonesSeekChanged(updates)
            }

            return nil

        default:
            return nil
        }
    }
}
