import Foundation

/// Events received from queue subscription
public enum QueueEvent: Sendable {
    /// Initial subscription with queue items
    case subscribed(items: [QueueItem])

    /// Full queue replacement
    case changed(items: [QueueItem])

    /// Items modified in-place (same queue_item_id, updated metadata)
    case itemsChanged([QueueItem])

    /// Items added to queue
    case itemsAdded([QueueItem])

    /// Items removed from queue (by queue_item_id)
    case itemsRemoved([Int])
}

extension QueueEvent {
    /// Parse a QueueEvent from a subscription response.
    ///
    /// Note: Roon's queue subscription is snapshot-only — the initial Subscribed
    /// response contains the full queue, but no Changed CONTINUE messages are sent
    /// for subsequent queue mutations. The incremental cases below are kept for
    /// correctness in case future Roon versions add them.
    public static func from(response: RoonResponse) -> QueueEvent? {
        guard let body = response.body else { return nil }

        switch response.name {
        case "Subscribed":
            // Initial subscription response — full items list
            if let itemsArray = body["items"] as? [[String: Any]] {
                let items = itemsArray.compactMap { QueueItem(from: $0) }
                return .subscribed(items: items)
            }
            return .subscribed(items: [])

        case "Changed":
            // Full replacement (if Roon sends complete list)
            if let itemsArray = body["items"] as? [[String: Any]] {
                let items = itemsArray.compactMap { QueueItem(from: $0) }
                return .changed(items: items)
            }

            // Incremental: items removed (array of queue_item_ids)
            if let removedIds = body["items_removed"] as? [Int], !removedIds.isEmpty {
                return .itemsRemoved(removedIds)
            }

            // Incremental: items added
            if let addedArray = body["items_added"] as? [[String: Any]], !addedArray.isEmpty {
                let items = addedArray.compactMap { QueueItem(from: $0) }
                if !items.isEmpty {
                    return .itemsAdded(items)
                }
            }

            // Incremental: items changed (updated metadata)
            if let changedArray = body["items_changed"] as? [[String: Any]], !changedArray.isEmpty {
                let items = changedArray.compactMap { QueueItem(from: $0) }
                if !items.isEmpty {
                    return .itemsChanged(items)
                }
            }

            return nil

        default:
            return nil
        }
    }
}
