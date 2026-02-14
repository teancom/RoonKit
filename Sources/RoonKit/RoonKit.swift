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
