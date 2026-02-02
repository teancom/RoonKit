import Testing
@testable import RoonKit

@Suite("NowPlaying Tests")
struct NowPlayingTests {

    @Test("NowPlaying parses complete data")
    func nowPlayingParsesComplete() {
        let dict: [String: Any] = [
            "seek_position": 60.0,
            "length": 240.0,
            "image_key": "img-12345",
            "one_line": ["line1": "Track Title"] as [String: Any],
            "two_line": ["line1": "Track Title", "line2": "Artist Name"] as [String: Any],
            "three_line": ["line1": "Track Title", "line2": "Artist Name", "line3": "Album Name"] as [String: Any]
        ]

        let nowPlaying = NowPlaying(from: dict)

        #expect(nowPlaying != nil)
        #expect(nowPlaying?.seekPosition == 60.0)
        #expect(nowPlaying?.length == 240.0)
        #expect(nowPlaying?.imageKey == "img-12345")
        #expect(nowPlaying?.title == "Track Title")
        #expect(nowPlaying?.artist == "Artist Name")
        #expect(nowPlaying?.album == "Album Name")
    }

    @Test("NowPlaying calculates progress correctly")
    func nowPlayingProgress() {
        let dict: [String: Any] = [
            "seek_position": 90.0,
            "length": 180.0,
            "one_line": ["line1": "Title"] as [String: Any],
            "two_line": ["line1": "Title", "line2": "Artist"] as [String: Any],
            "three_line": ["line1": "Title", "line2": "Artist", "line3": "Album"] as [String: Any]
        ]

        let nowPlaying = NowPlaying(from: dict)

        #expect(nowPlaying?.progress == 0.5)
        #expect(nowPlaying?.remainingTime == 90.0)
    }

    @Test("NowPlaying handles zero length")
    func nowPlayingZeroLength() {
        let dict: [String: Any] = [
            "seek_position": 10.0,
            "length": 0.0,
            "one_line": ["line1": "Title"] as [String: Any],
            "two_line": ["line1": "Title", "line2": "Artist"] as [String: Any],
            "three_line": ["line1": "Title", "line2": "Artist", "line3": "Album"] as [String: Any]
        ]

        let nowPlaying = NowPlaying(from: dict)

        #expect(nowPlaying?.progress == 0.0)
    }
}

@Suite("ZoneEvent Tests")
struct ZoneEventTests {

    @Test("ZoneEvent parses Subscribed response")
    func parsesSubscribed() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Subscribed",
            body: [
                "zones": [
                    ["zone_id": "z1", "display_name": "Zone 1"] as [String: Any],
                    ["zone_id": "z2", "display_name": "Zone 2"] as [String: Any]
                ]
            ]
        )

        let event = ZoneEvent.from(response: response)

        if case .subscribed(let zones) = event {
            #expect(zones.count == 2)
            #expect(zones[0].id == "z1")
        } else {
            Issue.record("Expected subscribed event")
        }
    }

    @Test("ZoneEvent parses zones_changed")
    func parsesZonesChanged() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [
                "zones_changed": [
                    ["zone_id": "z1", "display_name": "Zone 1", "state": "paused"] as [String: Any]
                ]
            ]
        )

        let event = ZoneEvent.from(response: response)

        if case .zonesChanged(let zones) = event {
            #expect(zones.count == 1)
            #expect(zones[0].state == .paused)
        } else {
            Issue.record("Expected zonesChanged event")
        }
    }

    @Test("ZoneEvent parses zones_removed")
    func parsesZonesRemoved() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [
                "zones_removed": ["z1", "z2"]
            ]
        )

        let event = ZoneEvent.from(response: response)

        if case .zonesRemoved(let ids) = event {
            #expect(ids == ["z1", "z2"])
        } else {
            Issue.record("Expected zonesRemoved event")
        }
    }

    @Test("ZoneEvent parses zones_seek_changed")
    func parsesSeekChanged() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [
                "zones_seek_changed": [
                    ["zone_id": "z1", "seek_position": 120.5, "queue_time_remaining": 300.0] as [String: Any]
                ]
            ]
        )

        let event = ZoneEvent.from(response: response)

        if case .zonesSeekChanged(let updates) = event {
            #expect(updates.count == 1)
            #expect(updates[0].seekPosition == 120.5)
        } else {
            Issue.record("Expected zonesSeekChanged event")
        }
    }
}
