import Testing
@testable import RoonKit

@Suite("Output Tests")
struct OutputTests {

    @Test("Output parses with volume")
    func outputParsesWithVolume() {
        let dict: [String: Any] = [
            "output_id": "out-123",
            "zone_id": "zone-abc",
            "display_name": "Main Speakers",
            "state": "playing",
            "volume": [
                "type": "db",
                "min": -80.0,
                "max": 0.0,
                "value": -30.5,
                "step": 0.5,
                "is_muted": false
            ] as [String: Any]
        ]

        let output = Output(from: dict)

        #expect(output != nil)
        #expect(output?.id == "out-123")
        #expect(output?.zoneId == "zone-abc")
        #expect(output?.displayName == "Main Speakers")
        #expect(output?.volume != nil)
        #expect(output?.volume?.type == .db)
        #expect(output?.volume?.value == -30.5)
        #expect(output?.volume?.isMuted == false)
    }

    @Test("Output parses without volume")
    func outputParsesWithoutVolume() {
        let dict: [String: Any] = [
            "output_id": "out-xyz",
            "zone_id": "zone-abc",
            "display_name": "Fixed Output"
        ]

        let output = Output(from: dict)

        #expect(output != nil)
        #expect(output?.volume == nil)
    }

    @Test("VolumeType decodes correctly")
    func volumeTypeDecodes() {
        #expect(VolumeType(rawValue: "db") == .db)
        #expect(VolumeType(rawValue: "number") == .number)
        #expect(VolumeType(rawValue: "incremental") == .incremental)
    }
}
