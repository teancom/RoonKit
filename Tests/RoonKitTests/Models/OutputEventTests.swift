import Testing
@testable import RoonKit

@Suite("OutputEvent Tests")
struct OutputEventTests {

    @Test("OutputEvent parses Subscribed response")
    func outputEventSubscribed() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Subscribed",
            body: [
                "outputs": [
                    [
                        "output_id": "out-1",
                        "zone_id": "zone-1",
                        "display_name": "Living Room"
                    ] as [String: Any],
                    [
                        "output_id": "out-2",
                        "zone_id": "zone-1",
                        "display_name": "Kitchen"
                    ] as [String: Any]
                ]
            ]
        )

        let events = OutputEvent.from(response: response)
        #expect(events.count == 1)

        if case .subscribed(let outputs) = events[0] {
            #expect(outputs.count == 2)
            #expect(outputs[0].id == "out-1")
            #expect(outputs[0].displayName == "Living Room")
            #expect(outputs[1].id == "out-2")
            #expect(outputs[1].displayName == "Kitchen")
        } else {
            Issue.record("Expected subscribed event")
        }
    }

    @Test("OutputEvent parses empty Subscribed response")
    func outputEventSubscribedEmpty() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Subscribed",
            body: [:]
        )

        let events = OutputEvent.from(response: response)
        #expect(events.count == 1)

        if case .subscribed(let outputs) = events[0] {
            #expect(outputs.isEmpty)
        } else {
            Issue.record("Expected subscribed event with empty outputs")
        }
    }

    @Test("OutputEvent parses outputs_removed")
    func outputEventOutputsRemoved() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [
                "outputs_removed": ["out-1", "out-2"]
            ]
        )

        let events = OutputEvent.from(response: response)
        #expect(events.count == 1)

        if case .outputsRemoved(let ids) = events[0] {
            #expect(ids == ["out-1", "out-2"])
            #expect(ids.count == 2)
        } else {
            Issue.record("Expected outputsRemoved event")
        }
    }

    @Test("OutputEvent parses outputs_added")
    func outputEventOutputsAdded() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [
                "outputs_added": [
                    [
                        "output_id": "out-new",
                        "zone_id": "zone-1",
                        "display_name": "New Speaker"
                    ] as [String: Any]
                ]
            ]
        )

        let events = OutputEvent.from(response: response)
        #expect(events.count == 1)

        if case .outputsAdded(let outputs) = events[0] {
            #expect(outputs.count == 1)
            #expect(outputs[0].id == "out-new")
            #expect(outputs[0].displayName == "New Speaker")
        } else {
            Issue.record("Expected outputsAdded event")
        }
    }

    @Test("OutputEvent parses outputs_changed")
    func outputEventOutputsChanged() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [
                "outputs_changed": [
                    [
                        "output_id": "out-1",
                        "zone_id": "zone-1",
                        "display_name": "Living Room Updated",
                        "state": "playing"
                    ] as [String: Any]
                ]
            ]
        )

        let events = OutputEvent.from(response: response)
        #expect(events.count == 1)

        if case .outputsChanged(let outputs) = events[0] {
            #expect(outputs.count == 1)
            #expect(outputs[0].id == "out-1")
            #expect(outputs[0].displayName == "Living Room Updated")
            #expect(outputs[0].state == .playing)
        } else {
            Issue.record("Expected outputsChanged event")
        }
    }

    @Test("OutputEvent returns empty array for empty Changed")
    func outputEventEmptyChanged() {
        let response = RoonResponse(
            verb: .complete,
            requestId: 1,
            name: "Changed",
            body: [:]
        )

        let events = OutputEvent.from(response: response)

        #expect(events.isEmpty)
    }

    @Test("OutputEvent returns empty array for nil body")
    func outputEventNilBody() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Subscribed",
            body: nil
        )

        let events = OutputEvent.from(response: response)

        #expect(events.isEmpty)
    }

    @Test("OutputEvent returns empty array for unknown response name")
    func outputEventUnknownName() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "UnknownEvent",
            body: [
                "outputs": []
            ]
        )

        let events = OutputEvent.from(response: response)

        #expect(events.isEmpty)
    }

    @Test("OutputEvent returns all event types from a single Changed message")
    func outputEventReturnsAllEventTypes() {
        // During output grouping/ungrouping, Roon sends removed + added together
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [
                "outputs_removed": ["out-1"],
                "outputs_added": [
                    ["output_id": "out-2", "zone_id": "z", "display_name": "New"] as [String: Any]
                ]
            ]
        )

        let events = OutputEvent.from(response: response)

        #expect(events.count == 2)

        if case .outputsRemoved(let ids) = events[0] {
            #expect(ids == ["out-1"])
        } else {
            Issue.record("Expected outputsRemoved as first event")
        }

        if case .outputsAdded(let outputs) = events[1] {
            #expect(outputs.count == 1)
            #expect(outputs[0].id == "out-2")
        } else {
            Issue.record("Expected outputsAdded as second event")
        }
    }

    @Test("OutputEvent returns added and changed from a single Changed message")
    func outputEventReturnsAddedAndChanged() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [
                "outputs_added": [
                    ["output_id": "out-1", "zone_id": "z", "display_name": "Added"] as [String: Any]
                ],
                "outputs_changed": [
                    ["output_id": "out-2", "zone_id": "z", "display_name": "Changed"] as [String: Any]
                ]
            ]
        )

        let events = OutputEvent.from(response: response)

        #expect(events.count == 2)

        if case .outputsAdded(let outputs) = events[0] {
            #expect(outputs.count == 1)
            #expect(outputs[0].id == "out-1")
        } else {
            Issue.record("Expected outputsAdded as first event")
        }

        if case .outputsChanged(let outputs) = events[1] {
            #expect(outputs.count == 1)
            #expect(outputs[0].id == "out-2")
        } else {
            Issue.record("Expected outputsChanged as second event")
        }
    }

    @Test("OutputEvent with volume control")
    func outputEventWithVolume() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Subscribed",
            body: [
                "outputs": [
                    [
                        "output_id": "out-1",
                        "zone_id": "zone-1",
                        "display_name": "Main",
                        "volume": [
                            "type": "db",
                            "min": -80.0,
                            "max": 0.0,
                            "value": -20.0,
                            "step": 0.5,
                            "is_muted": false
                        ] as [String: Any]
                    ] as [String: Any]
                ]
            ]
        )

        let events = OutputEvent.from(response: response)
        #expect(events.count == 1)

        if case .subscribed(let outputs) = events[0] {
            #expect(outputs.count == 1)
            #expect(outputs[0].volume != nil)
            #expect(outputs[0].volume?.type == .db)
            #expect(outputs[0].volume?.value == -20.0)
        } else {
            Issue.record("Expected subscribed event with volume")
        }
    }
}
