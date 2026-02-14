import Foundation

/// Service for browsing the Roon library
public actor BrowseService {
    private let connection: RoonConnection
    private let zoneId: () async -> String?

    /// Unique session key for multi-session browsing (nil for single-session mode)
    /// Most applications should use single-session mode (the default)
    private var sessionKey: String?

    /// Current hierarchy being browsed
    private var currentHierarchy: String = "browse"

    /// Current level in the browse hierarchy
    public private(set) var currentLevel: Int = 0

    /// Current list metadata
    public private(set) var currentList: BrowseListInfo?

    /// Create a browse service
    /// - Parameters:
    ///   - connection: The Roon connection to use
    ///   - zoneIdProvider: Closure that returns the current zone ID for playback actions
    public init(connection: RoonConnection, zoneIdProvider: @escaping () async -> String?) {
        self.connection = connection
        self.zoneId = zoneIdProvider
        self.sessionKey = nil  // Single-session mode by default
    }

    // MARK: - Browse Operations

    /// Start browsing a hierarchy
    /// - Parameter hierarchy: The hierarchy to browse (albums, artists, etc.)
    /// - Returns: Browse result with list metadata
    public func browse(hierarchy: BrowseHierarchy) async throws -> BrowseResult {
        return try await browseImpl(hierarchy: hierarchy.rawValue, popAll: true)
    }

    /// Navigate to an item
    /// - Parameter itemKey: The item key to navigate to
    /// - Returns: Browse result with list metadata or action result
    public func browse(itemKey: String) async throws -> BrowseResult {
        return try await browseImpl(itemKey: itemKey)
    }

    /// Search the library
    /// - Parameters:
    ///   - query: Search query string
    ///   - hierarchy: Optional hierarchy to search within (default: general search)
    /// - Returns: Browse result with search results
    public func search(query: String, hierarchy: BrowseHierarchy = .search) async throws -> BrowseResult {
        return try await browseImpl(hierarchy: hierarchy.rawValue, input: query, popAll: true)
    }

    /// Go back one level
    /// - Returns: Browse result for previous level
    public func back() async throws -> BrowseResult {
        return try await browseImpl(popLevels: 1)
    }

    /// Go back to root of current hierarchy
    /// - Returns: Browse result for root level
    public func backToRoot() async throws -> BrowseResult {
        return try await browseImpl(popAll: true)
    }

    /// Refresh the current list
    /// - Returns: Browse result with refreshed data
    public func refresh() async throws -> BrowseResult {
        return try await browseImpl(refreshList: true)
    }

    /// Update the stored display offset for the current list
    /// - Parameter offset: The display offset to store
    /// - Returns: Browse result
    public func setDisplayOffset(_ offset: Int) async throws -> BrowseResult {
        return try await browseImpl(setDisplayOffset: offset)
    }

    // MARK: - Load Operations

    /// Load items from the current list
    /// - Parameters:
    ///   - offset: Starting offset (default: 0)
    ///   - count: Number of items to load (default: 100)
    ///   - setDisplayOffset: Update the stored display offset for this list (optional)
    /// - Returns: Load result with items and metadata
    public func load(offset: Int = 0, count: Int = 100, setDisplayOffset: Int? = nil) async throws -> LoadResult {
        return try await loadImpl(level: nil, offset: offset, count: count, setDisplayOffset: setDisplayOffset)
    }

    /// Load items from a specific level
    /// - Parameters:
    ///   - level: The level to load from
    ///   - offset: Starting offset (default: 0)
    ///   - count: Number of items to load (default: 100)
    ///   - setDisplayOffset: Update the stored display offset for this list (optional)
    /// - Returns: Load result with items and metadata
    public func load(level: Int, offset: Int = 0, count: Int = 100, setDisplayOffset: Int? = nil) async throws -> LoadResult {
        return try await loadImpl(level: level, offset: offset, count: count, setDisplayOffset: setDisplayOffset)
    }

    /// Load all items from the current list (use with caution for large lists)
    /// - Parameter pageSize: Items per page (default: 100)
    /// - Returns: Array of all items
    public func loadAll(pageSize: Int = 100) async throws -> [BrowseItem] {
        var allItems: [BrowseItem] = []
        var offset = 0

        while true {
            let result = try await load(offset: offset, count: pageSize)
            allItems.append(contentsOf: result.items)

            if allItems.count >= result.list.count || result.items.isEmpty {
                break
            }

            offset += result.items.count
        }

        return allItems
    }

    // MARK: - Action Execution

    /// Execute an action item (play, add to queue, etc.)
    /// - Parameter itemKey: The item key of the action to execute
    /// - Returns: Browse result (may contain message)
    public func executeAction(itemKey: String) async throws -> BrowseResult {
        return try await browseImpl(itemKey: itemKey)
    }

    // MARK: - Private Implementation

    private func browseImpl(
        hierarchy: String? = nil,
        itemKey: String? = nil,
        input: String? = nil,
        popAll: Bool? = nil,
        popLevels: Int? = nil,
        refreshList: Bool? = nil,
        setDisplayOffset: Int? = nil
    ) async throws -> BrowseResult {
        var body: [String: Any] = [:]

        // Only include multi_session_key if in multi-session mode
        if let sessionKey = sessionKey {
            body["multi_session_key"] = sessionKey
        }

        if let hierarchy = hierarchy {
            body["hierarchy"] = hierarchy
            currentHierarchy = hierarchy
        } else {
            body["hierarchy"] = currentHierarchy
        }
        if let setDisplayOffset = setDisplayOffset {
            body["set_display_offset"] = setDisplayOffset
        }
        if let itemKey = itemKey {
            body["item_key"] = itemKey
        }
        if let input = input {
            body["input"] = input
        }
        if let popAll = popAll {
            body["pop_all"] = popAll
        }
        if let popLevels = popLevels {
            body["pop_levels"] = popLevels
        }
        if let refreshList = refreshList {
            body["refresh_list"] = refreshList
        }

        // Add zone ID for playback actions
        if let zoneId = await zoneId() {
            body["zone_or_output_id"] = zoneId
        }

        let response = try await connection.send(
            path: RoonService.path(RoonService.browse, "browse"),
            body: body
        )

        guard response.isSuccess, let responseBody = response.body else {
            throw BrowseError.browseFailed(response.errorMessage ?? "unknown error")
        }

        return parseBrowseResponse(responseBody)
    }

    private func loadImpl(level: Int?, offset: Int, count: Int, setDisplayOffset: Int? = nil) async throws -> LoadResult {
        var body: [String: Any] = [
            "hierarchy": currentHierarchy,
            "offset": offset,
            "count": count
        ]

        // Only include multi_session_key if in multi-session mode
        if let sessionKey = sessionKey {
            body["multi_session_key"] = sessionKey
        }

        if let level = level {
            body["level"] = level
        }
        if let setDisplayOffset = setDisplayOffset {
            body["set_display_offset"] = setDisplayOffset
        }

        let response = try await connection.send(
            path: RoonService.path(RoonService.browse, "load"),
            body: body
        )

        guard response.isSuccess, let responseBody = response.body else {
            throw BrowseError.loadFailed(response.errorMessage ?? "unknown error")
        }

        return parseLoadResponse(responseBody, requestedOffset: offset)
    }

    private func parseBrowseResponse(_ body: [String: Any]) -> BrowseResult {
        let actionString = body["action"] as? String ?? "none"
        let action = BrowseAction(rawValue: actionString) ?? .none

        var list: BrowseListInfo?
        if let listDict = body["list"] as? [String: Any] {
            list = BrowseListInfo(from: listDict)
            currentList = list
            currentLevel = list?.level ?? 0
        }

        var item: BrowseItem?
        if let itemDict = body["item"] as? [String: Any] {
            item = BrowseItem(from: itemDict)
        }

        let message = body["message"] as? String
        let isError = body["is_error"] as? Bool ?? false

        return BrowseResult(
            action: action,
            list: list,
            item: item,
            message: message,
            isError: isError
        )
    }

    private func parseLoadResponse(_ body: [String: Any], requestedOffset: Int) -> LoadResult {
        let itemsArray = body["items"] as? [[String: Any]] ?? []
        let items = itemsArray.compactMap { BrowseItem(from: $0) }

        let offset = body["offset"] as? Int ?? requestedOffset

        let list: BrowseListInfo
        if let listDict = body["list"] as? [String: Any],
           let parsedList = BrowseListInfo(from: listDict) {
            list = parsedList
            currentList = parsedList
            currentLevel = parsedList.level
        } else if let currentList = currentList {
            list = currentList
        } else {
            list = BrowseListInfo(title: "Unknown", count: items.count)
        }

        return LoadResult(items: items, offset: offset, list: list)
    }

    // MARK: - Session Management

    /// Reset the browse session (starts fresh)
    public func resetSession() {
        if sessionKey != nil {
            sessionKey = UUID().uuidString
        }
        currentHierarchy = "browse"
        currentLevel = 0
        currentList = nil
    }

    /// Enable multi-session mode for browsing multiple hierarchies simultaneously
    /// Most applications should use single-session mode (the default)
    public func enableMultiSessionMode() {
        if sessionKey == nil {
            sessionKey = UUID().uuidString
        }
    }

    /// Disable multi-session mode (return to single-session mode)
    public func disableMultiSessionMode() {
        sessionKey = nil
    }

    /// Whether multi-session mode is enabled
    public var isMultiSessionMode: Bool {
        sessionKey != nil
    }
}

/// Errors from browse service operations
public enum BrowseError: Error, Sendable {
    case browseFailed(String)
    case loadFailed(String)
}

extension BrowseError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .browseFailed(let message):
            return "browse failed: \(message)"
        case .loadFailed(let message):
            return "load failed: \(message)"
        }
    }
}
