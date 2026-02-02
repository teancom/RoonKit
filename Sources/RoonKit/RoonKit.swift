/// RoonKit: Swift library for controlling Roon music systems
///
/// ## Overview
/// RoonKit provides a clean, async/await API for controlling Roon music players.
///
/// ## Basic Usage
/// ```swift
/// let connection = RoonConnection(
///     host: "192.168.1.100",
///     extensionInfo: ExtensionInfo(
///         extensionId: "com.example.myapp",
///         displayName: "My App",
///         displayVersion: "1.0.0",
///         publisher: "Example",
///         email: "dev@example.com"
///     )
/// )
/// try await connection.connect()
/// ```
public enum RoonKit {
    /// Library version
    public static let version = "0.1.0"
}

// MARK: - Models

/// Alias for Zone model
public typealias _Zone = Zone

/// Alias for Output model
public typealias _Output = Output

/// Alias for NowPlaying model
public typealias _NowPlaying = NowPlaying

/// Alias for PlaybackState enum
public typealias _PlaybackState = PlaybackState

/// Alias for LoopMode enum
public typealias _LoopMode = LoopMode

/// Alias for ZoneSettings model
public typealias _ZoneSettings = ZoneSettings

/// Alias for VolumeControl model
public typealias _VolumeControl = VolumeControl

/// Alias for VolumeType enum
public typealias _VolumeType = VolumeType

/// Alias for DisplayLines model
public typealias _DisplayLines = DisplayLines

/// Alias for ZoneEvent enum
public typealias _ZoneEvent = ZoneEvent

/// Alias for ZoneSeekUpdate model
public typealias _ZoneSeekUpdate = ZoneSeekUpdate

// MARK: - Browse

/// Alias for BrowseItem model
public typealias _BrowseItem = BrowseItem

/// Alias for BrowseItemHint enum
public typealias _BrowseItemHint = BrowseItemHint

/// Alias for BrowseListInfo model
public typealias _BrowseListInfo = BrowseListInfo

/// Alias for BrowseResult model
public typealias _BrowseResult = BrowseResult

/// Alias for BrowseAction enum
public typealias _BrowseAction = BrowseAction

/// Alias for LoadResult model
public typealias _LoadResult = LoadResult

/// Alias for BrowseHierarchy enum
public typealias _BrowseHierarchy = BrowseHierarchy

/// Alias for InputPrompt model
public typealias _InputPrompt = InputPrompt

/// Alias for BrowseService
public typealias _BrowseService = BrowseService

/// Alias for BrowseError enum
public typealias _BrowseError = BrowseError

// MARK: - Services

/// Alias for TransportService
public typealias _TransportService = TransportService

/// Alias for TransportError enum
public typealias _TransportError = TransportError

// MARK: - Client

/// Alias for RoonClient
public typealias _RoonClient = RoonClient

// MARK: - Discovery

/// Alias for DiscoveredCore model
public typealias _DiscoveredCore = DiscoveredCore

/// Alias for DiscoveryError enum
public typealias _DiscoveryError = DiscoveryError

/// Alias for DiscoveryConfig struct
public typealias _DiscoveryConfig = DiscoveryConfig

/// Alias for SOODDiscovery actor
public typealias _SOODDiscovery = SOODDiscovery
