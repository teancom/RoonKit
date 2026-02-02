import Testing
@testable import RoonKit

@Suite("Zone Tests")
struct ZoneTests {

    @Test("Zone parses from complete dictionary")
    func zoneParseComplete() {
        let dict: [String: Any] = [
            "zone_id": "zone-123",
            "display_name": "Living Room",
            "state": "playing",
            "seek_position": 45.5,
            "queue_items_remaining": 5,
            "queue_time_remaining": 1200.0,
            "is_previous_allowed": true,
            "is_next_allowed": true,
            "is_pause_allowed": true,
            "is_play_allowed": false,
            "is_seek_allowed": true,
            "settings": [
                "shuffle": true,
                "loop": "loop_one",
                "auto_radio": false
            ] as [String: Any],
            "outputs": [
                [
                    "output_id": "out-1",
                    "zone_id": "zone-123",
                    "display_name": "Speaker"
                ] as [String: Any]
            ],
            "now_playing": [
                "seek_position": 45.5,
                "length": 180.0,
                "image_key": "img-abc",
                "one_line": ["line1": "Song Title"] as [String: Any],
                "two_line": ["line1": "Song Title", "line2": "Artist"] as [String: Any],
                "three_line": ["line1": "Song Title", "line2": "Artist", "line3": "Album"] as [String: Any]
            ] as [String: Any]
        ]

        let zone = Zone(from: dict)

        #expect(zone != nil)
        #expect(zone?.id == "zone-123")
        #expect(zone?.displayName == "Living Room")
        #expect(zone?.state == .playing)
        #expect(zone?.seekPosition == 45.5)
        #expect(zone?.settings.shuffle == true)
        #expect(zone?.settings.loop == .loopOne)
        #expect(zone?.isPreviousAllowed == true)
        #expect(zone?.isPlayAllowed == false)
        #expect(zone?.outputs.count == 1)
        #expect(zone?.nowPlaying?.title == "Song Title")
    }

    @Test("Zone parses minimal dictionary")
    func zoneParseMinimal() {
        let dict: [String: Any] = [
            "zone_id": "zone-abc",
            "display_name": "Kitchen"
        ]

        let zone = Zone(from: dict)

        #expect(zone != nil)
        #expect(zone?.id == "zone-abc")
        #expect(zone?.displayName == "Kitchen")
        #expect(zone?.state == .stopped)
        #expect(zone?.outputs.isEmpty == true)
        #expect(zone?.nowPlaying == nil)
    }

    @Test("Zone returns nil for missing required fields")
    func zoneReturnsNilForMissingFields() {
        let dict: [String: Any] = [
            "zone_id": "zone-abc"
            // Missing display_name
        ]

        let zone = Zone(from: dict)

        #expect(zone == nil)
    }

    @Test("LoopMode cycles correctly")
    func loopModeCycles() {
        #expect(LoopMode.disabled.next == .loop)
        #expect(LoopMode.loop.next == .loopOne)
        #expect(LoopMode.loopOne.next == .disabled)
    }

    @Test("PlaybackState decodes from strings")
    func playbackStateDecodes() {
        #expect(PlaybackState(rawValue: "playing") == .playing)
        #expect(PlaybackState(rawValue: "paused") == .paused)
        #expect(PlaybackState(rawValue: "loading") == .loading)
        #expect(PlaybackState(rawValue: "stopped") == .stopped)
        #expect(PlaybackState(rawValue: "invalid") == nil)
    }
}
