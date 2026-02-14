import Testing
@testable import RoonKit

@Suite("VolumeControl Tests")
struct VolumeControlTests {

    @Test("VolumeControl parses complete dictionary")
    func volumeControlParsesComplete() {
        let dict: [String: Any] = [
            "type": "db",
            "min": -80.0,
            "max": 0.0,
            "value": -30.5,
            "step": 0.5,
            "is_muted": false
        ]

        let volume = VolumeControl(from: dict)

        #expect(volume != nil)
        #expect(volume?.type == .db)
        #expect(volume?.min == -80.0)
        #expect(volume?.max == 0.0)
        #expect(volume?.value == -30.5)
        #expect(volume?.step == 0.5)
        #expect(volume?.isMuted == false)
    }

    @Test("VolumeControl parses with defaults")
    func volumeControlParsesWithDefaults() {
        let dict: [String: Any] = [
            "type": "number"
            // All other fields will use defaults
        ]

        let volume = VolumeControl(from: dict)

        #expect(volume != nil)
        #expect(volume?.type == .number)
        #expect(volume?.min == 0)
        #expect(volume?.max == 100)
        #expect(volume?.value == 0)
        #expect(volume?.step == 1)
        #expect(volume?.isMuted == false)
    }

    @Test("VolumeControl returns nil for missing type")
    func volumeControlMissingType() {
        let dict: [String: Any] = [
            "min": 0,
            "max": 100
        ]

        let volume = VolumeControl(from: dict)

        #expect(volume == nil)
    }

    @Test("VolumeControl returns nil for invalid type")
    func volumeControlInvalidType() {
        let dict: [String: Any] = [
            "type": "invalid_type",
            "min": 0
        ]

        let volume = VolumeControl(from: dict)

        #expect(volume == nil)
    }

    @Test("VolumeControl with muted true")
    func volumeControlMuted() {
        let dict: [String: Any] = [
            "type": "db",
            "min": -80.0,
            "max": 0.0,
            "value": -20.0,
            "step": 0.5,
            "is_muted": true
        ]

        let volume = VolumeControl(from: dict)

        #expect(volume?.isMuted == true)
    }

    @Test("VolumeControl with incremental type")
    func volumeControlIncremental() {
        let dict: [String: Any] = [
            "type": "incremental",
            "min": 0,
            "max": 100,
            "value": 50,
            "step": 1
        ]

        let volume = VolumeControl(from: dict)

        #expect(volume?.type == .incremental)
    }

    @Test("VolumeControl equality")
    func volumeControlEquality() {
        let dict1: [String: Any] = [
            "type": "db",
            "min": -80.0,
            "max": 0.0,
            "value": -20.0,
            "step": 0.5,
            "is_muted": false
        ]
        let dict2: [String: Any] = [
            "type": "db",
            "min": -80.0,
            "max": 0.0,
            "value": -20.0,
            "step": 0.5,
            "is_muted": false
        ]
        let dict3: [String: Any] = [
            "type": "db",
            "min": -80.0,
            "max": 0.0,
            "value": -30.0,
            "step": 0.5,
            "is_muted": false
        ]

        let vol1 = VolumeControl(from: dict1)!
        let vol2 = VolumeControl(from: dict2)!
        let vol3 = VolumeControl(from: dict3)!

        #expect(vol1 == vol2)
        #expect(vol1 != vol3)
    }

    @Test("VolumeControl with explicit step")
    func volumeControlExplicitStep() {
        let dict: [String: Any] = [
            "type": "number",
            "step": 2.5
        ]

        let volume = VolumeControl(from: dict)

        #expect(volume?.step == 2.5)
    }

    @Test("VolumeControl with negative values")
    func volumeControlNegativeValues() {
        let dict: [String: Any] = [
            "type": "db",
            "min": -100.0,
            "max": -10.0,
            "value": -50.0,
            "step": 1.0
        ]

        let volume = VolumeControl(from: dict)

        #expect(volume?.min == -100.0)
        #expect(volume?.max == -10.0)
        #expect(volume?.value == -50.0)
    }
}

@Suite("SourceControl Tests")
struct SourceControlTests {

    @Test("SourceControl parses complete dictionary")
    func sourceControlParsesComplete() {
        let dict: [String: Any] = [
            "display_name": "HDMI Input",
            "status": "selected",
            "control_key": "hdmi",
            "supports_standby": true
        ]

        let source = SourceControl(from: dict)

        #expect(source != nil)
        #expect(source?.displayName == "HDMI Input")
        #expect(source?.status == .selected)
        #expect(source?.controlKey == "hdmi")
        #expect(source?.supportsStandby == true)
    }

    @Test("SourceControl parses minimal dictionary")
    func sourceControlParsesMinimal() {
        let dict: [String: Any] = [
            "display_name": "Optical",
            "status": "deselected",
            "control_key": "optical"
        ]

        let source = SourceControl(from: dict)

        #expect(source != nil)
        #expect(source?.supportsStandby == false) // Default
    }

    @Test("SourceControl returns nil for missing display_name")
    func sourceControlMissingDisplayName() {
        let dict: [String: Any] = [
            "status": "selected",
            "control_key": "hdmi"
        ]

        let source = SourceControl(from: dict)

        #expect(source == nil)
    }

    @Test("SourceControl returns nil for missing status")
    func sourceControlMissingStatus() {
        let dict: [String: Any] = [
            "display_name": "HDMI",
            "control_key": "hdmi"
        ]

        let source = SourceControl(from: dict)

        #expect(source == nil)
    }

    @Test("SourceControl returns nil for invalid status")
    func sourceControlInvalidStatus() {
        let dict: [String: Any] = [
            "display_name": "HDMI",
            "status": "unknown_status",
            "control_key": "hdmi"
        ]

        let source = SourceControl(from: dict)

        #expect(source == nil)
    }

    @Test("SourceControl returns nil for missing control_key")
    func sourceControlMissingControlKey() {
        let dict: [String: Any] = [
            "display_name": "HDMI",
            "status": "selected"
        ]

        let source = SourceControl(from: dict)

        #expect(source == nil)
    }

    @Test("SourceControl with standby status")
    func sourceControlStandby() {
        let dict: [String: Any] = [
            "display_name": "AMP",
            "status": "standby",
            "control_key": "amp",
            "supports_standby": true
        ]

        let source = SourceControl(from: dict)

        #expect(source?.status == .standby)
        #expect(source?.supportsStandby == true)
    }

    @Test("SourceControl with indeterminate status")
    func sourceControlIndeterminate() {
        let dict: [String: Any] = [
            "display_name": "Network",
            "status": "indeterminate",
            "control_key": "network"
        ]

        let source = SourceControl(from: dict)

        #expect(source?.status == .indeterminate)
    }

    @Test("SourceControl equality")
    func sourceControlEquality() {
        let dict1: [String: Any] = [
            "display_name": "HDMI",
            "status": "selected",
            "control_key": "hdmi",
            "supports_standby": true
        ]
        let dict2: [String: Any] = [
            "display_name": "HDMI",
            "status": "selected",
            "control_key": "hdmi",
            "supports_standby": true
        ]
        let dict3: [String: Any] = [
            "display_name": "Optical",
            "status": "selected",
            "control_key": "optical",
            "supports_standby": false
        ]

        let source1 = SourceControl(from: dict1)!
        let source2 = SourceControl(from: dict2)!
        let source3 = SourceControl(from: dict3)!

        #expect(source1 == source2)
        #expect(source1 != source3)
    }
}

@Suite("OutputTests with Volume and Source")
struct OutputComplexTests {

    @Test("Output with multiple source controls")
    func outputMultipleSources() {
        let dict: [String: Any] = [
            "output_id": "out-1",
            "zone_id": "zone-1",
            "display_name": "Amp",
            "source_controls": [
                [
                    "display_name": "HDMI",
                    "status": "selected",
                    "control_key": "hdmi",
                    "supports_standby": true
                ] as [String: Any],
                [
                    "display_name": "Optical",
                    "status": "deselected",
                    "control_key": "optical",
                    "supports_standby": false
                ] as [String: Any]
            ]
        ]

        let output = Output(from: dict)

        #expect(output != nil)
        #expect(output?.sourceControls.count == 2)
        #expect(output?.sourceControls[0].displayName == "HDMI")
        #expect(output?.sourceControls[1].displayName == "Optical")
    }

    @Test("Output can group with other outputs")
    func outputCanGroupWith() {
        let dict: [String: Any] = [
            "output_id": "out-1",
            "zone_id": "zone-1",
            "display_name": "Speaker 1",
            "can_group_with_output_ids": ["out-2", "out-3"]
        ]

        let output = Output(from: dict)

        #expect(output?.canGroupWithOutputIds == ["out-2", "out-3"])
    }

    @Test("Output with all fields populated")
    func outputAllFields() {
        let dict: [String: Any] = [
            "output_id": "out-complete",
            "zone_id": "zone-1",
            "display_name": "Complete Output",
            "state": "playing",
            "volume": [
                "type": "db",
                "min": -80.0,
                "max": 0.0,
                "value": -15.0,
                "step": 0.5,
                "is_muted": false
            ] as [String: Any],
            "source_controls": [
                [
                    "display_name": "HDMI",
                    "status": "selected",
                    "control_key": "hdmi",
                    "supports_standby": true
                ] as [String: Any]
            ],
            "can_group_with_output_ids": ["out-2"]
        ]

        let output = Output(from: dict)

        #expect(output != nil)
        #expect(output?.id == "out-complete")
        #expect(output?.displayName == "Complete Output")
        #expect(output?.state == .playing)
        #expect(output?.volume?.value == -15.0)
        #expect(output?.sourceControls.count == 1)
        #expect(output?.canGroupWithOutputIds.count == 1)
    }
}
