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

    @Test("Zone with standby-capable source control returns it")
    func standbySourceControlFound() {
        let scDict: [String: Any] = [
            "display_name": "Speaker",
            "status": "selected",
            "supports_standby": true,
            "control_key": "ctl-1"
        ]
        let sc = SourceControl(from: scDict)!

        let output = Output(
            id: "out-1",
            zoneId: "zone-123",
            displayName: "Living Room Speaker",
            sourceControls: [sc]
        )

        let zone = Zone(
            id: "zone-123",
            displayName: "Living Room",
            outputs: [output]
        )

        let standby = zone.standbySourceControl

        #expect(standby != nil)
        #expect(standby?.outputId == "out-1")
        #expect(standby?.sourceControl.displayName == "Speaker")
        #expect(standby?.sourceControl.supportsStandby == true)
    }

    @Test("Zone with no standby-capable source controls returns nil")
    func standbySourceControlNotFound() {
        let scDict: [String: Any] = [
            "display_name": "Speaker",
            "status": "selected",
            "supports_standby": false,
            "control_key": "ctl-1"
        ]
        let sc = SourceControl(from: scDict)!

        let output = Output(
            id: "out-1",
            zoneId: "zone-123",
            displayName: "Living Room Speaker",
            sourceControls: [sc]
        )

        let zone = Zone(
            id: "zone-123",
            displayName: "Living Room",
            outputs: [output]
        )

        #expect(zone.standbySourceControl == nil)
    }

    @Test("Zone with multiple outputs finds first standby-capable source control")
    func standbySourceControlMultipleOutputs() {
        let nonStandbyDict: [String: Any] = [
            "display_name": "Regular Speaker",
            "status": "selected",
            "supports_standby": false,
            "control_key": "ctl-1"
        ]
        let nonStandby = SourceControl(from: nonStandbyDict)!

        let standbyDict: [String: Any] = [
            "display_name": "Power Source",
            "status": "selected",
            "supports_standby": true,
            "control_key": "ctl-2"
        ]
        let standby = SourceControl(from: standbyDict)!

        let output1 = Output(
            id: "out-1",
            zoneId: "zone-123",
            displayName: "Output 1",
            sourceControls: [nonStandby]
        )

        let output2 = Output(
            id: "out-2",
            zoneId: "zone-123",
            displayName: "Output 2",
            sourceControls: [standby]
        )

        let zone = Zone(
            id: "zone-123",
            displayName: "Living Room",
            outputs: [output1, output2]
        )

        let result = zone.standbySourceControl

        #expect(result != nil)
        #expect(result?.outputId == "out-2")
        #expect(result?.sourceControl.displayName == "Power Source")
    }

    @Test("Zone with empty outputs returns nil for standbySourceControl")
    func standbySourceControlEmptyOutputs() {
        let zone = Zone(
            id: "zone-123",
            displayName: "Living Room",
            outputs: []
        )

        #expect(zone.standbySourceControl == nil)
    }
}
