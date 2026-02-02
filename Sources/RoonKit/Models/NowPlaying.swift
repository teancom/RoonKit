import Foundation

/// Display lines for now playing info
public struct DisplayLines: Sendable, Equatable {
    public let line1: String
    public let line2: String?
    public let line3: String?

    public init(line1: String, line2: String? = nil, line3: String? = nil) {
        self.line1 = line1
        self.line2 = line2
        self.line3 = line3
    }

    public init?(from dict: [String: Any]) {
        guard let line1 = dict["line1"] as? String else {
            return nil
        }
        self.line1 = line1
        self.line2 = dict["line2"] as? String
        self.line3 = dict["line3"] as? String
    }
}

/// Information about the currently playing track
public struct NowPlaying: Sendable, Equatable {
    /// Current seek position in seconds
    public let seekPosition: Double

    /// Track length in seconds
    public let length: Double

    /// Image key for fetching album art
    public let imageKey: String?

    /// Single line display (title only)
    public let oneLine: DisplayLines

    /// Two line display (title + artist)
    public let twoLine: DisplayLines

    /// Three line display (title + artist + album)
    public let threeLine: DisplayLines

    public init(
        seekPosition: Double = 0,
        length: Double = 0,
        imageKey: String? = nil,
        oneLine: DisplayLines,
        twoLine: DisplayLines,
        threeLine: DisplayLines
    ) {
        self.seekPosition = seekPosition
        self.length = length
        self.imageKey = imageKey
        self.oneLine = oneLine
        self.twoLine = twoLine
        self.threeLine = threeLine
    }

    public init?(from dict: [String: Any]) {
        self.seekPosition = dict["seek_position"] as? Double ?? 0
        self.length = dict["length"] as? Double ?? 0
        self.imageKey = dict["image_key"] as? String

        guard let oneLineDict = dict["one_line"] as? [String: Any],
              let oneLine = DisplayLines(from: oneLineDict),
              let twoLineDict = dict["two_line"] as? [String: Any],
              let twoLine = DisplayLines(from: twoLineDict),
              let threeLineDict = dict["three_line"] as? [String: Any],
              let threeLine = DisplayLines(from: threeLineDict) else {
            return nil
        }

        self.oneLine = oneLine
        self.twoLine = twoLine
        self.threeLine = threeLine
    }

    /// Title of the currently playing track
    public var title: String {
        threeLine.line1
    }

    /// Artist of the currently playing track
    public var artist: String? {
        threeLine.line2
    }

    /// Album of the currently playing track
    public var album: String? {
        threeLine.line3
    }

    /// Progress as a percentage (0.0 to 1.0)
    public var progress: Double {
        guard length > 0 else { return 0 }
        return min(1.0, max(0.0, seekPosition / length))
    }

    /// Remaining time in seconds
    public var remainingTime: Double {
        max(0, length - seekPosition)
    }
}
