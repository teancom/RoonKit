import Foundation

/// Main entry point for controlling Roon music systems
public actor RoonClient {
    /// Host address of the Roon Core
    public let host: String

    /// Port number (typically 9100)
    public let port: Int

    /// Extension information
    public let extensionInfo: ExtensionInfo

    /// The underlying connection to Roon Core
    public let connection: RoonConnection

    /// Transport service for playback control
    public lazy var transport: TransportService = {
        TransportService(connection: connection)
    }()

    /// Browse service for library navigation
    public lazy var browse: BrowseService = {
        BrowseService(connection: connection) { [weak self] in
            await self?.transport.selectedZoneId
        }
    }()

    /// Image service for fetching album art and other images
    public lazy var images: ImageService = {
        ImageService(host: host, port: port)
    }()

    /// Current connection state
    public var state: ConnectionState {
        get async { await connection.state }
    }

    /// Stream of connection state changes
    public var stateStream: AsyncStream<ConnectionState> {
        get async { await connection.stateStream }
    }

    /// Create a Roon client
    /// - Parameters:
    ///   - host: IP address or hostname of the Roon Core
    ///   - port: Port number (default 9100)
    ///   - extensionId: Unique identifier for this extension
    ///   - displayName: Display name shown in Roon
    ///   - displayVersion: Version string shown in Roon
    ///   - publisher: Publisher name
    ///   - email: Contact email
    public init(
        host: String,
        port: Int = 9100,
        extensionId: String,
        displayName: String,
        displayVersion: String,
        publisher: String,
        email: String
    ) {
        self.host = host
        self.port = port
        self.extensionInfo = ExtensionInfo(
            extensionId: extensionId,
            displayName: displayName,
            displayVersion: displayVersion,
            publisher: publisher,
            email: email
        )
        self.connection = RoonConnection(
            host: host,
            port: port,
            extensionInfo: extensionInfo
        )
    }

    /// Connect to the Roon Core
    public func connect() async throws {
        try await connection.connect()
    }

    /// Disconnect from the Roon Core
    public func disconnect() async {
        await connection.disconnect()
    }

    // MARK: - Convenience Methods

    /// Subscribe to zone updates
    public func subscribeZones() async throws -> AsyncStream<ZoneEvent> {
        try await transport.subscribeZones()
    }

    /// Get all known zones
    public var zones: [Zone] {
        get async {
            await Array(transport.zones.values)
        }
    }

    /// Select a zone for playback commands
    public func selectZone(id: String) async {
        await transport.selectZone(id: id)
    }

    /// Get the currently selected zone
    public var selectedZone: Zone? {
        get async {
            await transport.selectedZone
        }
    }

    // MARK: - Playback Control Convenience

    /// Play the selected zone
    public func play() async throws {
        try await transport.play()
    }

    /// Pause the selected zone
    public func pause() async throws {
        try await transport.pause()
    }

    /// Toggle play/pause
    public func playPause() async throws {
        try await transport.playPause()
    }

    /// Stop playback
    public func stop() async throws {
        try await transport.stop()
    }

    /// Skip to next track
    public func next() async throws {
        try await transport.next()
    }

    /// Skip to previous track
    public func previous() async throws {
        try await transport.previous()
    }

    // MARK: - Browse Convenience

    /// Browse albums
    public func browseAlbums() async throws -> BrowseResult {
        try await browse.browse(hierarchy: .albums)
    }

    /// Browse artists
    public func browseArtists() async throws -> BrowseResult {
        try await browse.browse(hierarchy: .artists)
    }

    /// Browse playlists
    public func browsePlaylists() async throws -> BrowseResult {
        try await browse.browse(hierarchy: .playlists)
    }

    /// Search the library
    public func search(query: String) async throws -> BrowseResult {
        try await browse.search(query: query)
    }
}
