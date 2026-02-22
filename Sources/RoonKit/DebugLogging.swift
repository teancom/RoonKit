import Foundation
import os

/// Controls whether verbose diagnostic logging is persisted to the system log.
///
/// When enabled, verbose log calls emit at `.info` level (persisted, visible
/// in `log show`). When disabled, they emit at `.debug` level (never persisted,
/// only visible in real-time `log stream --level debug`).
///
/// Toggle via Settings → Debug Logging, or programmatically:
///     DebugLogging.isEnabled = true
///
/// Usage at call sites (string interpolation must be at the direct call site
/// due to Apple's `OSLogMessage` compiler magic):
///
///     log.log(level: DebugLogging.verboseLevel, "detail=\(value, privacy: .public)")
///
/// View logs:
///     log show --predicate 'subsystem CONTAINS "roonkit"' --last 10m --info
public enum DebugLogging {
    private static let key = "roonkit.debugLogging"

    public static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// The `OSLogType` to use for verbose diagnostic messages.
    /// Returns `.info` (persisted) when debug logging is enabled,
    /// `.debug` (never persisted) when disabled.
    public static var verboseLevel: OSLogType {
        isEnabled ? .info : .debug
    }
}
