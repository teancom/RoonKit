import Foundation

/// Events received from queue subscription
public enum QueueEvent: Sendable {
    /// Initial subscription with queue items
    case subscribed(items: [QueueItem])

    /// Queue changed with updated items
    case changed(items: [QueueItem])
}

extension QueueEvent {
    /// Parse a QueueEvent from a subscription response
    public static func from(response: RoonResponse) -> QueueEvent? {
        guard let body = response.body else { return nil }

        switch response.name {
        case "Subscribed":
            // Initial subscription response
            if let itemsArray = body["items"] as? [[String: Any]] {
                let items = itemsArray.compactMap { QueueItem(from: $0) }
                return .subscribed(items: items)
            }
            return .subscribed(items: [])

        case "Changed":
            // Queue changed
            if let itemsArray = body["items"] as? [[String: Any]] {
                let items = itemsArray.compactMap { QueueItem(from: $0) }
                return .changed(items: items)
            }
            return nil

        default:
            return nil
        }
    }
}
