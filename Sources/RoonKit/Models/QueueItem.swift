import Foundation

/// A track in the playback queue
public struct QueueItem: Sendable, Identifiable, Equatable {
    public let id: Int
    public let length: Double?
    public let imageKey: String?
    public let title: String
    public let subtitle: String?
    public let artist: String?
    public let album: String?

    public init(
        id: Int,
        length: Double? = nil,
        imageKey: String? = nil,
        title: String,
        subtitle: String? = nil,
        artist: String? = nil,
        album: String? = nil
    ) {
        self.id = id
        self.length = length
        self.imageKey = imageKey
        self.title = title
        self.subtitle = subtitle
        self.artist = artist
        self.album = album
    }

    public init?(from dict: [String: Any]) {
        guard let queueItemId = dict["queue_item_id"] as? Int else {
            return nil
        }

        self.id = queueItemId
        self.length = dict["length"] as? Double
        self.imageKey = dict["image_key"] as? String

        // Parse display info from one_line, two_line, or three_line
        if let threeLine = dict["three_line"] as? [String: Any] {
            self.title = threeLine["line1"] as? String ?? "Unknown"
            self.subtitle = threeLine["line2"] as? String
            self.artist = threeLine["line2"] as? String
            self.album = threeLine["line3"] as? String
        } else if let twoLine = dict["two_line"] as? [String: Any] {
            self.title = twoLine["line1"] as? String ?? "Unknown"
            self.subtitle = twoLine["line2"] as? String
            self.artist = twoLine["line2"] as? String
            self.album = nil
        } else if let oneLine = dict["one_line"] as? [String: Any] {
            self.title = oneLine["line1"] as? String ?? "Unknown"
            self.subtitle = nil
            self.artist = nil
            self.album = nil
        } else {
            self.title = "Unknown"
            self.subtitle = nil
            self.artist = nil
            self.album = nil
        }
    }
}
