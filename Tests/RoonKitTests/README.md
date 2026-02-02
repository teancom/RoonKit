# RoonKit Test Suite

## Overview

RoonKit uses a two-tier testing strategy:

1. **Unit Tests** (`Tests/RoonKitTests/`) - Fast, mocked, run in CI
2. **Integration Tests** (`Tests/RoonKitIntegrationTests/`) - Real Roon, manual execution

## Running Tests

### Unit Tests

```bash
# Run all unit tests
swift test

# Run specific test suite
swift test --filter MessageCodingTests
swift test --filter RoonConnectionTests
swift test --filter TransportServiceTests
```

### Integration Tests

Integration tests require a real Roon Core on your network.

```bash
# Set Roon Core address
export ROON_HOST=192.168.1.100

# Run integration tests
swift test --filter IntegrationTests
```

To skip integration tests (in CI):

```bash
export ROON_SKIP_INTEGRATION=1
swift test
```

## Test Coverage

### Connection Layer

| Component | Test File | Coverage |
|-----------|-----------|----------|
| ConnectionState | ConnectionStateTests.swift | State properties, error messages |
| MessageCoding | MessageCodingTests.swift | Encode/decode, round-trip, errors |
| TokenStorage | TokenStorageTests.swift | CRUD operations, key prefixes |
| Reconnector | ReconnectorTests.swift | Backoff calculation, max attempts |
| RoonConnection | RoonConnectionTests.swift | Connect, register, token handling |

### Protocol Layer

| Component | Test File | Coverage |
|-----------|-----------|----------|
| RoonMessage | MessageCodingTests.swift | Request/response structure |
| RegistrationTypes | RegistrationTypesTests.swift | CoreInfo, RegistrationRequest/Response |

### Models

| Component | Test File | Coverage |
|-----------|-----------|----------|
| Zone | ZoneTests.swift | Parsing, state, settings |
| Output | OutputTests.swift | Parsing, volume control |
| NowPlaying | NowPlayingTests.swift | Parsing, progress calculation |
| ZoneEvent | ZoneTests.swift | Event parsing |
| BrowseItem | BrowseItemTests.swift | Parsing, hints |
| BrowseList | BrowseItemTests.swift | List metadata |

### Services

| Component | Test File | Coverage |
|-----------|-----------|----------|
| TransportService | TransportServiceTests.swift | Playback, volume, seek, settings |
| BrowseService | BrowseServiceTests.swift | Browse, search, pagination |

### Client

| Component | Test File | Coverage |
|-----------|-----------|----------|
| RoonClient | EndToEndMockTests.swift | Initialization, end-to-end flows |

## Mock Infrastructure

`Tests/RoonKitTests/Mocks/MockWebSocketTransport.swift` provides:

- Message capture for verification
- Response queue for simulating server
- Manual message injection
- Pre-built response helpers (MockResponses)

### MockResponses Helpers

- `coreInfo()` - Registry info response
- `registered()` - Registration success
- `zoneSubscribed(zones:)` - Zone subscription
- `zonesChanged(zones:)` - Zone update
- `success(requestId:)` - Generic success
- `browseResult(...)` - Browse response
- `loadResult(...)` - Load response
- `sampleZone(...)` - Test zone factory

## Writing New Tests

### Unit Test Pattern

```swift
import Testing
@testable import RoonKit

@Suite("MyComponent Tests")
struct MyComponentTests {
    @Test("Description of test")
    func testSomething() async throws {
        // Arrange
        let transport = MockWebSocketTransport()
        transport.messagesToReceive = [
            .success(.text(MockResponses.coreInfo())),
            .success(.text(MockResponses.registered()))
        ]

        // Act
        let connection = RoonConnection(...)
        try await connection.connect()

        // Assert
        #expect(...)
    }
}
```

### Integration Test Pattern

```swift
@Test("Real Roon test")
func testWithRealRoon() async throws {
    guard !IntegrationTestConfig.shouldSkip else {
        printSkipMessage()
        return
    }

    guard let client = createIntegrationClient() else {
        Issue.record("Failed to create client")
        return
    }

    try await client.connect()
    // ... test ...
    await client.disconnect()
}
```
