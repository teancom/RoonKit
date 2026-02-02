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
    /// Parse an OutputEvent from a subscription response
    public static func from(response: RoonResponse) -> OutputEvent? {
        guard let body = response.body else { return nil }

        switch response.name {
        case "Subscribed":
            // Initial subscription response
            if let outputsArray = body["outputs"] as? [[String: Any]] {
                let outputs = outputsArray.compactMap { Output(from: $0) }
                return .subscribed(outputs: outputs)
            }
            return .subscribed(outputs: [])

        case "Changed":
            // Incremental update
            if let removedIds = body["outputs_removed"] as? [String], !removedIds.isEmpty {
                return .outputsRemoved(removedIds)
            }

            if let addedArray = body["outputs_added"] as? [[String: Any]], !addedArray.isEmpty {
                let outputs = addedArray.compactMap { Output(from: $0) }
                return .outputsAdded(outputs)
            }

            if let changedArray = body["outputs_changed"] as? [[String: Any]], !changedArray.isEmpty {
                let outputs = changedArray.compactMap { Output(from: $0) }
                return .outputsChanged(outputs)
            }

            return nil

        default:
            return nil
        }
    }
}
