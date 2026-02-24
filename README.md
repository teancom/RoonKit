# RoonKit

A Swift library for controlling [Roon](https://roon.app) music systems. macOS 15+, Swift 6.0.

RoonKit is **not** a media player — it's a client library for the Roon API. All audio playback happens on the Roon Core; RoonKit sends control commands and receives state updates.

## Usage

```swift
import RoonKit

let client = RoonClient()
try await client.connect(host: "192.168.1.100")

// Subscribe to zone changes
let zones = try await client.subscribeZones()
for await event in zones {
    // Handle zone events
}

// Transport control
try await client.transport.play(zoneId: zone.zoneId)
try await client.transport.pause(zoneId: zone.zoneId)
```

## Adding to Your Project

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/teancom/RoonKit.git", branch: "main"),
]
```

## Key Types

| Type | Purpose |
|------|---------|
| `RoonClient` | Entry point, conforms to `RoonClientProtocol` |
| `RoonClientProtocol` | Actor protocol for DI/testing |
| `RoonConnection` | WebSocket actor |
| `TransportService` | Playback control |
| `BrowseService` | Library navigation |
| `ImageService` | Album art |
| `SOODDiscovery` | Network discovery |

## Building & Testing

```bash
swift build
swift test
```

## Roon API Limitations

Roon does **not** expose: audio EQ settings, balance control, bitrate/sample rate, mono/stereo info, queue reordering/removal (read-only), queue sorting, or playlist creation/management.

## Acknowledgments

- [Roon Labs](https://roonlabs.com/) for the Roon music system
- Protocol details derived from [node-roon-api](https://github.com/RoonLabs/node-roon-api)
