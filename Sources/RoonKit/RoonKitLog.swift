import Foundation

/// Provides a host-derived logger subsystem for all RoonKit loggers.
///
/// When hosted in an app, the subsystem includes the host's bundle
/// identifier plus `.roonkit` (e.g., `"com.example.app.roonkit"`). In test runners or contexts
/// without a bundle identifier, falls back to `"com.roonkit"`.
enum RoonKitLog {
    static let subsystem: String = {
        if let bundleId = Bundle.main.bundleIdentifier {
            return "\(bundleId).roonkit"
        }
        return "com.roonkit"
    }()
}
