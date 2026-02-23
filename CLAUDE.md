# RoonKit

Last verified: 2026-02-23

## What This Is

Host-agnostic Swift library for controlling Roon music systems. Single-actor architecture with async/await. macOS 15+, Swift 6.0.

**Key insight:** This is NOT a media player — it's a client library for the Roon API. All audio playback happens on the Roon Core; RoonKit sends control commands and receives state updates.

## Key Types

- `RoonClient` — entry point, conforms to `RoonClientProtocol`
- `RoonClientProtocol` — actor protocol for DI/testing
- `RoonConnection` — WebSocket actor
- `TransportService` — playback control
- `BrowseService` — library navigation
- `ImageService` — album art
- `SOODDiscovery` — network discovery
- `DebugLogging` — UserDefaults-backed toggle for verbose log level (key: `roonkit.debugLogging`)

`RoonClient.createBrowseService()` returns an independent `BrowseService` instance for background work (thumbnail resolution, pre-caching) that won't interfere with the user's browse session.

`VolumeControl` includes `normalizedValue` (0.0-1.0) and `denormalize(_:)` helpers. `Zone.standbySourceControl` finds the first standby-capable source control across outputs.

Logger subsystem derived from host bundle ID (`com.macaroon.roonkit` when hosted, `com.roonkit` standalone).

Connection: WebSocket to `ws://host:9100/api` → register → authorize → subscribe zones.

Keepalive watchdog detects dead connections after macOS sleep/wake (Roon pings every ~5s; if no message arrives within `keepaliveTimeout` (default 15s), the transport is force-closed to trigger reconnection). Uses `ContinuousClock` so elapsed time includes system sleep.

## Building & Testing

```bash
swift build
swift test
```

Tests use **Swift Testing framework** (`@Suite`, `@Test`, `#expect`), not XCTest.

Includes `MockRoonServer` (`Tests/RoonKitTests/Mocks/MockRoonServer.swift`) — a full-stack mock Roon Core that auto-responds to MOO protocol messages, enabling offline/CI testing of connection lifecycle, subscription management, transport commands, and race conditions without a live Roon Core.

## Swift Concurrency Pitfalls

### AsyncStream termination must propagate through ALL layers

**This is the single most critical pattern in the codebase.** It has caused at least four debugging sessions. When an `AsyncStream` producer stops producing (e.g., a WebSocket disconnects), every downstream `AsyncStream` in the chain must be explicitly `finish()`ed.

AsyncStream does NOT auto-terminate when its producer stops yielding. A `for await` loop on an unfinished stream **hangs forever** — silently. No error, no timeout, no log.

**The two-layer subscription pattern (MANDATORY for all subscription code):**

```swift
// LAYER 1 — PRODUCER (e.g., TransportService)
func subscribeZones() async throws -> AsyncStream<ZoneEvent> {
    let responseStream = try await connection.subscribe(...)
    let eventStream = AsyncStream<ZoneEvent> { continuation in
        self.eventContinuation = continuation
    }
    processingTask = Task {
        for await response in responseStream {
            self.processResponse(response)
        }
        // CRITICAL: finish the continuation when the source stream ends
        self.eventContinuation?.finish()
    }
    return eventStream
}

// LAYER 2 — CONSUMER
func subscribeToZones() async throws {
    let zoneStream = try await client.subscribeZones()
    zoneSubscriptionTask = Task {
        for await event in zoneStream {
            handleZoneEvent(event)
        }
        // CRITICAL: nil the sentinel so reconnection can start fresh
        self.zoneSubscriptionTask = nil
    }
}
```

**Checklist for any new subscription or stream-bridging code:**
1. Does every `for await` loop on a response/source stream call `continuation?.finish()` after the loop exits?
2. Does every `Task?` sentinel nil itself at the end of its body?
3. Does explicit teardown (`disconnect()`, `unsubscribe()`) both `cancel()` the task AND nil it?

### `Task?` is not a liveness indicator

A `Task<Void, Never>?` property does NOT become `nil` when the task's work completes. The handle persists as non-nil even after the async block returns. If you use `if task == nil` to mean "nothing is running, start new work," the task body MUST set the property to `nil` before returning.

## Roon API Limitations

Roon does NOT expose: audio EQ settings, balance control, bitrate/sample rate, mono/stereo info, queue reordering/removal (read-only), queue sorting, **playlist creation or management**.
