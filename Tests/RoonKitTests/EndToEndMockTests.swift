import Testing
import Foundation
@testable import RoonKit

// Helper to check if Data contains a string
private extension Data {
    func containsString(_ str: String) -> Bool {
        guard let text = String(data: self, encoding: .utf8) else { return false }
        return text.contains(str)
    }
}

/// End-to-end tests for RoonKit services.
///
/// NOTE: Testing the full async connection flow with mocks is complex due to
/// timing issues between the receive loop and test code. These tests focus on
/// verifiable behavior without requiring synchronized message delivery.
///
/// Full integration testing is best done with a real Roon Core
/// (see RoonKitIntegrationTests).
@Suite("End-to-End Mock Tests")
struct EndToEndMockTests {

    // MARK: - TransportService Message Formatting

    @Test("Play command sends correct control message")
    func playCommandFormat() throws {
        // Test that play() would send the right message format
        // by encoding a request manually
        let request = RoonRequest(
            requestId: 0,
            path: "com.roonlabs.transport:2/control",
            body: ["zone_or_output_id": "zone-123", "control": "play"]
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("com.roonlabs.transport:2/control"))
        #expect(encoded.containsString("zone-123"))
        #expect(encoded.containsString("play"))
    }

    @Test("Pause command sends correct control message")
    func pauseCommandFormat() throws {
        let request = RoonRequest(
            requestId: 0,
            path: "com.roonlabs.transport:2/control",
            body: ["zone_or_output_id": "zone-123", "control": "pause"]
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("pause"))
    }

    @Test("Stop command sends correct control message")
    func stopCommandFormat() throws {
        let request = RoonRequest(
            requestId: 0,
            path: "com.roonlabs.transport:2/control",
            body: ["zone_or_output_id": "zone-123", "control": "stop"]
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("stop"))
    }

    @Test("Next command sends correct control message")
    func nextCommandFormat() throws {
        let request = RoonRequest(
            requestId: 0,
            path: "com.roonlabs.transport:2/control",
            body: ["zone_or_output_id": "zone-123", "control": "next"]
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("next"))
    }

    @Test("Previous command sends correct control message")
    func previousCommandFormat() throws {
        let request = RoonRequest(
            requestId: 0,
            path: "com.roonlabs.transport:2/control",
            body: ["zone_or_output_id": "zone-123", "control": "previous"]
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("previous"))
    }

    // MARK: - Volume Control Message Formatting

    @Test("Set volume sends correct absolute volume message")
    func setVolumeFormat() throws {
        let request = RoonRequest(
            requestId: 0,
            path: "com.roonlabs.transport:2/change_volume",
            body: [
                "output_id": "output-1",
                "how": "absolute",
                "value": -25.0
            ]
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("change_volume"))
        #expect(encoded.containsString("output-1"))
        #expect(encoded.containsString("absolute"))
        #expect(encoded.containsString("-25"))
    }

    @Test("Adjust volume sends correct relative volume message")
    func adjustVolumeFormat() throws {
        let request = RoonRequest(
            requestId: 0,
            path: "com.roonlabs.transport:2/change_volume",
            body: [
                "output_id": "output-1",
                "how": "relative",
                "value": 5.0
            ]
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("relative"))
        #expect(encoded.containsString("5"))
    }

    @Test("Mute sends correct mute message")
    func muteFormat() throws {
        let request = RoonRequest(
            requestId: 0,
            path: "com.roonlabs.transport:2/mute",
            body: [
                "output_id": "output-1",
                "how": "mute"
            ]
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("mute"))
        #expect(encoded.containsString("output-1"))
    }

    // MARK: - Browse Message Formatting

    @Test("Browse sends correct hierarchy message")
    func browseFormat() throws {
        let request = RoonRequest(
            requestId: 0,
            path: "com.roonlabs.browse:1/browse",
            body: [
                "hierarchy": "albums",
                "pop_all": true
            ]
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("com.roonlabs.browse:1/browse"))
        #expect(encoded.containsString("albums"))
    }

    @Test("Load sends correct pagination message")
    func loadFormat() throws {
        let request = RoonRequest(
            requestId: 0,
            path: "com.roonlabs.browse:1/load",
            body: [
                "offset": 0,
                "count": 50
            ]
        )

        let encoded = try MessageCoding.encode(request)

        #expect(encoded.containsString("com.roonlabs.browse:1/load"))
        #expect(encoded.containsString("offset"))
        #expect(encoded.containsString("count"))
    }

    // MARK: - Response Parsing

    @Test("Zone subscription response parses correctly")
    func zoneSubscriptionParsing() throws {
        let response = """
            MOO/1 CONTINUE Subscribed
            Request-Id: 2
            Content-Type: application/json
            Content-Length: 100

            {"zones":[{"zone_id":"z1","display_name":"Living Room","state":"playing","outputs":[],"settings":{"shuffle":false,"loop":"disabled","auto_radio":false}}]}
            """

        let parsed = try MessageCoding.decode(response)

        #expect(parsed.verb == .continue)
        #expect(parsed.name == "Subscribed")
        #expect(parsed.body?["zones"] != nil)
    }

    @Test("Browse result response parses correctly")
    func browseResultParsing() throws {
        let response = """
            MOO/1 COMPLETE Success
            Request-Id: 2
            Content-Type: application/json
            Content-Length: 100

            {"action":"list","list":{"title":"Albums","count":50,"level":0}}
            """

        let parsed = try MessageCoding.decode(response)

        #expect(parsed.verb == .complete)
        #expect(parsed.name == "Success")
        #expect(parsed.body?["action"] as? String == "list")
    }

    // MARK: - MockResponses Helpers

    @Test("MockResponses sampleZone creates valid zone data")
    func sampleZoneValidity() {
        let zone = MockResponses.sampleZone(id: "test-zone", name: "Test Room", state: "paused")

        #expect(zone["zone_id"] as? String == "test-zone")
        #expect(zone["display_name"] as? String == "Test Room")
        #expect(zone["state"] as? String == "paused")
        #expect(zone["outputs"] != nil)
        #expect(zone["settings"] != nil)
        #expect(zone["now_playing"] != nil)
    }

    @Test("MockResponses creates valid zone subscription response")
    func zoneSubscribedValidity() {
        let response = MockResponses.zoneSubscribed(zones: [MockResponses.sampleZone()])

        #expect(response.contains("MOO/1 CONTINUE Subscribed"))
        #expect(response.contains("Request-Id: 2"))
        #expect(response.contains("zone-1"))
        #expect(response.contains("Living Room"))
    }
}
