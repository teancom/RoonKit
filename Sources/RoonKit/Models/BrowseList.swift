import Foundation

/// Metadata about a browse list
public struct BrowseListInfo: Sendable, Equatable {
    public let title: String
    public let count: Int
    public let subtitle: String?
    public let imageKey: String?
    public let level: Int
    public let displayOffset: Int?
    public let hint: String?

    public init(
        title: String,
        count: Int,
        subtitle: String? = nil,
        imageKey: String? = nil,
        level: Int = 0,
        displayOffset: Int? = nil,
        hint: String? = nil
    ) {
        self.title = title
        self.count = count
        self.subtitle = subtitle
        self.imageKey = imageKey
        self.level = level
        self.displayOffset = displayOffset
        self.hint = hint
    }

    public init?(from dict: [String: Any]) {
        guard let title = dict["title"] as? String,
              let count = dict["count"] as? Int else {
            return nil
        }

        self.title = title
        self.count = count
        self.subtitle = dict["subtitle"] as? String
        self.imageKey = dict["image_key"] as? String
        self.level = dict["level"] as? Int ?? 0
        self.displayOffset = dict["display_offset"] as? Int
        self.hint = dict["hint"] as? String
    }
}

/// Result of a browse operation
public struct BrowseResult: Sendable {
    /// The action to take (list, message, none, etc.)
    public let action: BrowseAction

    /// List metadata (when action is .list)
    public let list: BrowseListInfo?

    /// Current item (for navigation context)
    public let item: BrowseItem?

    /// Message to display (when action is .message)
    public let message: String?

    /// Whether the message is an error
    public let isError: Bool

    public init(
        action: BrowseAction,
        list: BrowseListInfo? = nil,
        item: BrowseItem? = nil,
        message: String? = nil,
        isError: Bool = false
    ) {
        self.action = action
        self.list = list
        self.item = item
        self.message = message
        self.isError = isError
    }
}

/// Action type from browse response
public enum BrowseAction: String, Sendable {
    case list
    case message
    case none
    case replaceItem = "replace_item"
    case removeItem = "remove_item"
}

/// Result of a load operation (paginated items)
public struct LoadResult: Sendable {
    public let items: [BrowseItem]
    public let offset: Int
    public let list: BrowseListInfo

    public init(items: [BrowseItem], offset: Int, list: BrowseListInfo) {
        self.items = items
        self.offset = offset
        self.list = list
    }
}

/// Browse hierarchies available in Roon
public enum BrowseHierarchy: String, Sendable {
    case browse
    case playlists
    case settings
    case internetRadio = "internet_radio"
    case albums
    case artists
    case genres
    case composers
    case search
}
