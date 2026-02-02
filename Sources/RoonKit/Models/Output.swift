import Foundation

/// Volume control type
public enum VolumeType: String, Sendable, Codable {
    case db
    case number
    case incremental
}

/// Volume control information for an output
public struct VolumeControl: Sendable, Equatable {
    public let type: VolumeType
    public let min: Double
    public let max: Double
    public let value: Double
    public let step: Double
    public let isMuted: Bool

    public init(
        type: VolumeType,
        min: Double,
        max: Double,
        value: Double,
        step: Double,
        isMuted: Bool
    ) {
        self.type = type
        self.min = min
        self.max = max
        self.value = value
        self.step = step
        self.isMuted = isMuted
    }

    public init?(from dict: [String: Any]) {
        guard let typeString = dict["type"] as? String,
              let type = VolumeType(rawValue: typeString) else {
            return nil
        }

        self.type = type
        self.min = dict["min"] as? Double ?? 0
        self.max = dict["max"] as? Double ?? 100
        self.value = dict["value"] as? Double ?? 0
        self.step = dict["step"] as? Double ?? 1
        self.isMuted = dict["is_muted"] as? Bool ?? false
    }
}

/// Source control status
public enum SourceControlStatus: String, Sendable, Codable {
    case selected
    case deselected
    case standby
    case indeterminate
}

/// Source control for an output
public struct SourceControl: Sendable, Equatable {
    public let displayName: String
    public let status: SourceControlStatus
    public let supportsStandby: Bool
    public let controlKey: String

    public init?(from dict: [String: Any]) {
        guard let displayName = dict["display_name"] as? String,
              let statusString = dict["status"] as? String,
              let status = SourceControlStatus(rawValue: statusString),
              let controlKey = dict["control_key"] as? String else {
            return nil
        }

        self.displayName = displayName
        self.status = status
        self.supportsStandby = dict["supports_standby"] as? Bool ?? false
        self.controlKey = controlKey
    }
}

/// A physical audio output device
public struct Output: Sendable, Identifiable, Equatable {
    public let id: String
    public let zoneId: String
    public let displayName: String
    public let state: PlaybackState
    public let volume: VolumeControl?
    public let sourceControls: [SourceControl]

    public var outputId: String { id }

    public init(
        id: String,
        zoneId: String,
        displayName: String,
        state: PlaybackState = .stopped,
        volume: VolumeControl? = nil,
        sourceControls: [SourceControl] = []
    ) {
        self.id = id
        self.zoneId = zoneId
        self.displayName = displayName
        self.state = state
        self.volume = volume
        self.sourceControls = sourceControls
    }

    public init?(from dict: [String: Any]) {
        guard let outputId = dict["output_id"] as? String,
              let zoneId = dict["zone_id"] as? String,
              let displayName = dict["display_name"] as? String else {
            return nil
        }

        self.id = outputId
        self.zoneId = zoneId
        self.displayName = displayName

        if let stateString = dict["state"] as? String,
           let state = PlaybackState(rawValue: stateString) {
            self.state = state
        } else {
            self.state = .stopped
        }

        if let volumeDict = dict["volume"] as? [String: Any] {
            self.volume = VolumeControl(from: volumeDict)
        } else {
            self.volume = nil
        }

        if let sourceControlsArray = dict["source_controls"] as? [[String: Any]] {
            self.sourceControls = sourceControlsArray.compactMap { SourceControl(from: $0) }
        } else {
            self.sourceControls = []
        }
    }
}
