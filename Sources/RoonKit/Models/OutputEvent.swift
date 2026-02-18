import Foundation

/// Events received from output subscription
public enum OutputEvent: Sendable {
    /// Initial subscription with all outputs
    case subscribed(outputs: [Output])

    /// Outputs were added
    case outputsAdded([Output])

    /// Outputs were removed (by ID)
    case outputsRemoved([String])

    /// Outputs were changed (full output data)
    case outputsChanged([Output])
}

extension OutputEvent {
    /// Parse OutputEvents from a subscription response.
    ///
    /// A single Roon `Changed` response can contain **multiple** event types
    /// simultaneously (e.g., `outputs_removed` + `outputs_added` when outputs
    /// are grouped/ungrouped). All present fields are returned as separate events.
    /// Order matters: removed → added → changed, matching the logical sequence.
    public static func from(response: RoonResponse) -> [OutputEvent] {
        guard let body = response.body else { return [] }

        switch response.name {
        case "Subscribed":
            // Initial subscription response
            if let outputsArray = body["outputs"] as? [[String: Any]] {
                let outputs = outputsArray.compactMap { Output(from: $0) }
                return [.subscribed(outputs: outputs)]
            }
            return [.subscribed(outputs: [])]

        case "Changed":
            // A single Changed message can contain multiple event types.
            // Process all present fields — grouping operations send removed + added together.
            var events: [OutputEvent] = []

            if let removedIds = body["outputs_removed"] as? [String], !removedIds.isEmpty {
                events.append(.outputsRemoved(removedIds))
            }

            if let addedArray = body["outputs_added"] as? [[String: Any]], !addedArray.isEmpty {
                let outputs = addedArray.compactMap { Output(from: $0) }
                events.append(.outputsAdded(outputs))
            }

            if let changedArray = body["outputs_changed"] as? [[String: Any]], !changedArray.isEmpty {
                let outputs = changedArray.compactMap { Output(from: $0) }
                events.append(.outputsChanged(outputs))
            }

            return events

        default:
            return []
        }
    }
}
