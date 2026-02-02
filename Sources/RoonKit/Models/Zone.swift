import Foundation

/// Playback state of a zone
public enum PlaybackState: String, Sendable, Codable {
    case playing
    case paused
    case loading
    case stopped
}

/// Loop mode for a zone
public enum LoopMode: String, Sendable, Codable {
    case disabled
    case loop
    case loopOne = "loop_one"

    /// Next mode in cycle (for toggle behavior)
    public var next: LoopMode {
        switch self {
        case .disabled: return .loop
        case .loop: return .loopOne
        case .loopOne: return .disabled
        }
    }
}

/// Zone settings (shuffle, loop, auto-radio)
public struct ZoneSettings: Sendable, Codable, Equatable {
    public let shuffle: Bool
    public let loop: LoopMode
    public let autoRadio: Bool

    enum CodingKeys: String, CodingKey {
        case shuffle
        case loop
        case autoRadio = "auto_radio"
    }

    public init(shuffle: Bool = false, loop: LoopMode = .disabled, autoRadio: Bool = false) {
        self.shuffle = shuffle
        self.loop = loop
        self.autoRadio = autoRadio
    }
}

/// A Roon playback zone
public struct Zone: Sendable, Identifiable, Equatable {
    public let id: String
    public let displayName: String
    public let outputs: [Output]
    public let state: PlaybackState
    public let seekPosition: Double?
    public let queueItemsRemaining: Int
    public let queueTimeRemaining: Double
    public let settings: ZoneSettings
    public let nowPlaying: NowPlaying?

    // Capability flags
    public let isPreviousAllowed: Bool
    public let isNextAllowed: Bool
    public let isPauseAllowed: Bool
    public let isPlayAllowed: Bool
    public let isSeekAllowed: Bool

    public var zoneId: String { id }

    public init(
        id: String,
        displayName: String,
        outputs: [Output] = [],
        state: PlaybackState = .stopped,
        seekPosition: Double? = nil,
        queueItemsRemaining: Int = 0,
        queueTimeRemaining: Double = 0,
        settings: ZoneSettings = ZoneSettings(),
        nowPlaying: NowPlaying? = nil,
        isPreviousAllowed: Bool = false,
        isNextAllowed: Bool = false,
        isPauseAllowed: Bool = false,
        isPlayAllowed: Bool = false,
        isSeekAllowed: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.outputs = outputs
        self.state = state
        self.seekPosition = seekPosition
        self.queueItemsRemaining = queueItemsRemaining
        self.queueTimeRemaining = queueTimeRemaining
        self.settings = settings
        self.nowPlaying = nowPlaying
        self.isPreviousAllowed = isPreviousAllowed
        self.isNextAllowed = isNextAllowed
        self.isPauseAllowed = isPauseAllowed
        self.isPlayAllowed = isPlayAllowed
        self.isSeekAllowed = isSeekAllowed
    }
}

extension Zone {
    /// Parse a Zone from Roon's JSON response
    public init?(from dict: [String: Any]) {
        guard let zoneId = dict["zone_id"] as? String,
              let displayName = dict["display_name"] as? String else {
            return nil
        }

        self.id = zoneId
        self.displayName = displayName

        // Parse outputs
        if let outputsArray = dict["outputs"] as? [[String: Any]] {
            self.outputs = outputsArray.compactMap { Output(from: $0) }
        } else {
            self.outputs = []
        }

        // Parse state
        if let stateString = dict["state"] as? String,
           let state = PlaybackState(rawValue: stateString) {
            self.state = state
        } else {
            self.state = .stopped
        }

        self.seekPosition = dict["seek_position"] as? Double
        self.queueItemsRemaining = dict["queue_items_remaining"] as? Int ?? 0
        self.queueTimeRemaining = dict["queue_time_remaining"] as? Double ?? 0

        // Parse settings
        if let settingsDict = dict["settings"] as? [String: Any] {
            let shuffle = settingsDict["shuffle"] as? Bool ?? false
            let loopString = settingsDict["loop"] as? String ?? "disabled"
            let loop = LoopMode(rawValue: loopString) ?? .disabled
            let autoRadio = settingsDict["auto_radio"] as? Bool ?? false
            self.settings = ZoneSettings(shuffle: shuffle, loop: loop, autoRadio: autoRadio)
        } else {
            self.settings = ZoneSettings()
        }

        // Parse now_playing
        if let nowPlayingDict = dict["now_playing"] as? [String: Any] {
            self.nowPlaying = NowPlaying(from: nowPlayingDict)
        } else {
            self.nowPlaying = nil
        }

        // Parse capability flags
        self.isPreviousAllowed = dict["is_previous_allowed"] as? Bool ?? false
        self.isNextAllowed = dict["is_next_allowed"] as? Bool ?? false
        self.isPauseAllowed = dict["is_pause_allowed"] as? Bool ?? false
        self.isPlayAllowed = dict["is_play_allowed"] as? Bool ?? false
        self.isSeekAllowed = dict["is_seek_allowed"] as? Bool ?? false
    }
}
