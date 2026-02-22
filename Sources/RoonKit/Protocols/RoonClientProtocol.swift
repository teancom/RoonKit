import Foundation

/// Protocol abstracting RoonClient for dependency injection and testing.
///
/// Consumers depend on this protocol rather than RoonClient directly,
/// allowing mock implementations for unit testing.
public protocol RoonClientProtocol: Actor {
    /// Host address of the Roon Core.
    var host: String { get }

    /// Port number of the Roon Core.
    var port: Int { get }

    /// Current connection state.
    var state: ConnectionState { get async }

    /// Stream of connection state changes.
    var stateStream: AsyncStream<ConnectionState> { get async }

    /// Connect to the Roon Core.
    func connect() async throws

    /// Disconnect from the Roon Core.
    func disconnect() async

    /// Subscribe to zone updates.
    func subscribeZones() async throws -> AsyncStream<ZoneEvent>

    /// Get all known zones.
    var zones: [Zone] { get async }

    /// Transport service for playback control.
    var transport: TransportService { get async }

    /// Browse service for library navigation.
    var browse: BrowseService { get async }

    /// Image service for fetching artwork.
    var images: ImageService { get async }

    /// Create an independent BrowseService instance.
    func createBrowseService() -> BrowseService
}

// MARK: - RoonClient Conformance

extension RoonClient: RoonClientProtocol {}
