import Foundation

/// Hint for how to display/interact with a browse item
public enum BrowseItemHint: String, Sendable, Codable {
    /// No special behavior
    case none = ""
    /// Item is an action (play, add to queue, etc.)
    case action
    /// Item opens an action list
    case actionList = "action_list"
    /// Item navigates to a list
    case list
    /// Item is a header/separator
    case header
}

/// Input prompt for search or text entry
public struct InputPrompt: Sendable, Equatable {
    public let prompt: String
    public let action: String
    public let value: String?
    public let isPassword: Bool

    public init(prompt: String, action: String, value: String? = nil, isPassword: Bool = false) {
        self.prompt = prompt
        self.action = action
        self.value = value
        self.isPassword = isPassword
    }

    public init?(from dict: [String: Any]) {
        guard let prompt = dict["prompt"] as? String,
              let action = dict["action"] as? String else {
            return nil
        }

        self.prompt = prompt
        self.action = action
        self.value = dict["value"] as? String
        self.isPassword = dict["is_password"] as? Bool ?? false
    }
}

/// An item in a browse list (album, artist, playlist, action, etc.)
public struct BrowseItem: Sendable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let imageKey: String?
    public let itemKey: String
    public let hint: BrowseItemHint
    public let inputPrompt: InputPrompt?

    public init(
        title: String,
        subtitle: String? = nil,
        imageKey: String? = nil,
        itemKey: String,
        hint: BrowseItemHint = .none,
        inputPrompt: InputPrompt? = nil
    ) {
        self.id = itemKey
        self.title = title
        self.subtitle = subtitle
        self.imageKey = imageKey
        self.itemKey = itemKey
        self.hint = hint
        self.inputPrompt = inputPrompt
    }

    public init?(from dict: [String: Any]) {
        guard let title = dict["title"] as? String,
              let itemKey = dict["item_key"] as? String else {
            return nil
        }

        self.id = itemKey
        self.title = title
        self.subtitle = dict["subtitle"] as? String
        self.imageKey = dict["image_key"] as? String
        self.itemKey = itemKey

        if let hintString = dict["hint"] as? String,
           let hint = BrowseItemHint(rawValue: hintString) {
            self.hint = hint
        } else {
            self.hint = .none
        }

        if let promptDict = dict["input_prompt"] as? [String: Any] {
            self.inputPrompt = InputPrompt(from: promptDict)
        } else {
            self.inputPrompt = nil
        }
    }

    /// Whether this item can be navigated into (has children)
    public var isNavigable: Bool {
        hint == .list || hint == .actionList
    }

    /// Whether this item is an action to execute
    public var isAction: Bool {
        hint == .action
    }

    /// Whether this item is a header/separator
    public var isHeader: Bool {
        hint == .header
    }

    /// Whether this item has an input prompt (search field)
    public var hasInputPrompt: Bool {
        inputPrompt != nil
    }
}
