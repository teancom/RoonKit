import Testing
@testable import RoonKit

@Suite("QueueItem Tests")
struct QueueItemTests {

    @Test("QueueItem parses with all three_line fields")
    func queueItemParsesThreeLine() {
        let dict: [String: Any] = [
            "queue_item_id": 42,
            "length": 240.5,
            "image_key": "img-q1",
            "three_line": [
                "line1": "Song Title",
                "line2": "Artist Name",
                "line3": "Album Name"
            ] as [String: Any]
        ]

        let item = QueueItem(from: dict)

        #expect(item != nil)
        #expect(item?.id == 42)
        #expect(item?.length == 240.5)
        #expect(item?.imageKey == "img-q1")
        #expect(item?.title == "Song Title")
        #expect(item?.artist == "Artist Name")
        #expect(item?.album == "Album Name")
    }

    @Test("QueueItem parses with two_line fields")
    func queueItemParsesTwoLine() {
        let dict: [String: Any] = [
            "queue_item_id": 5,
            "two_line": [
                "line1": "Track Name",
                "line2": "Artist Name"
            ] as [String: Any]
        ]

        let item = QueueItem(from: dict)

        #expect(item != nil)
        #expect(item?.id == 5)
        #expect(item?.title == "Track Name")
        #expect(item?.artist == "Artist Name")
        #expect(item?.album == nil)
        #expect(item?.length == nil)
        #expect(item?.imageKey == nil)
    }

    @Test("QueueItem parses with one_line fields")
    func queueItemParsesOneLine() {
        let dict: [String: Any] = [
            "queue_item_id": 10,
            "one_line": [
                "line1": "Just A Title"
            ] as [String: Any]
        ]

        let item = QueueItem(from: dict)

        #expect(item != nil)
        #expect(item?.id == 10)
        #expect(item?.title == "Just A Title")
        #expect(item?.subtitle == nil)
        #expect(item?.artist == nil)
        #expect(item?.album == nil)
    }

    @Test("QueueItem returns Unknown title when no display lines")
    func queueItemUnknownTitle() {
        let dict: [String: Any] = [
            "queue_item_id": 7
        ]

        let item = QueueItem(from: dict)

        #expect(item != nil)
        #expect(item?.title == "Unknown")
    }

    @Test("QueueItem returns nil for missing queue_item_id")
    func queueItemMissingId() {
        let dict: [String: Any] = [
            "title": "Some Track"
        ]

        let item = QueueItem(from: dict)

        #expect(item == nil)
    }

    @Test("QueueItem uses three_line preferentially over two_line")
    func queueItemPreference() {
        let dict: [String: Any] = [
            "queue_item_id": 3,
            "three_line": [
                "line1": "Title Three",
                "line2": "Artist Three",
                "line3": "Album Three"
            ] as [String: Any],
            "two_line": [
                "line1": "Title Two",
                "line2": "Artist Two"
            ] as [String: Any]
        ]

        let item = QueueItem(from: dict)

        #expect(item?.title == "Title Three")
        #expect(item?.artist == "Artist Three")
        #expect(item?.album == "Album Three")
    }

    @Test("QueueItem with zero length")
    func queueItemZeroLength() {
        let dict: [String: Any] = [
            "queue_item_id": 1,
            "length": 0.0,
            "three_line": ["line1": "Title"] as [String: Any]
        ]

        let item = QueueItem(from: dict)

        #expect(item?.length == 0.0)
    }

    @Test("QueueItem equality")
    func queueItemEquality() {
        let item1 = QueueItem(id: 1, title: "Song", artist: "Artist")
        let item2 = QueueItem(id: 1, title: "Song", artist: "Artist")
        let item3 = QueueItem(id: 2, title: "Song", artist: "Artist")

        #expect(item1 == item2)
        #expect(item1 != item3)
    }

    @Test("QueueItem implements Identifiable")
    func queueItemIdentifiable() {
        let item = QueueItem(id: 99, title: "Track")

        #expect(item.id == 99)
    }
}

@Suite("QueueEvent Tests")
struct QueueEventTests {

    @Test("QueueEvent parses Subscribed response")
    func queueEventSubscribed() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Subscribed",
            body: [
                "items": [
                    [
                        "queue_item_id": 1,
                        "three_line": ["line1": "Track 1"] as [String: Any]
                    ] as [String: Any],
                    [
                        "queue_item_id": 2,
                        "three_line": ["line1": "Track 2"] as [String: Any]
                    ] as [String: Any]
                ]
            ]
        )

        let event = QueueEvent.from(response: response)

        if case .subscribed(let items) = event {
            #expect(items.count == 2)
            #expect(items[0].id == 1)
            #expect(items[1].id == 2)
        } else {
            Issue.record("Expected subscribed event")
        }
    }

    @Test("QueueEvent parses empty Subscribed response")
    func queueEventSubscribedEmpty() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Subscribed",
            body: [:]
        )

        let event = QueueEvent.from(response: response)

        if case .subscribed(let items) = event {
            #expect(items.isEmpty)
        } else {
            Issue.record("Expected subscribed event with empty items")
        }
    }

    @Test("QueueEvent parses Changed with full items list")
    func queueEventChanged() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [
                "items": [
                    ["queue_item_id": 1, "three_line": ["line1": "Track"] as [String: Any]] as [String: Any]
                ]
            ]
        )

        let event = QueueEvent.from(response: response)

        if case .changed(let items) = event {
            #expect(items.count == 1)
            #expect(items[0].id == 1)
        } else {
            Issue.record("Expected changed event")
        }
    }

    @Test("QueueEvent parses items_removed")
    func queueEventItemsRemoved() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [
                "items_removed": [1, 2, 3]
            ]
        )

        let event = QueueEvent.from(response: response)

        if case .itemsRemoved(let ids) = event {
            #expect(ids == [1, 2, 3])
        } else {
            Issue.record("Expected itemsRemoved event")
        }
    }

    @Test("QueueEvent parses items_added")
    func queueEventItemsAdded() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [
                "items_added": [
                    ["queue_item_id": 5, "three_line": ["line1": "New Track"] as [String: Any]] as [String: Any]
                ]
            ]
        )

        let event = QueueEvent.from(response: response)

        if case .itemsAdded(let items) = event {
            #expect(items.count == 1)
            #expect(items[0].id == 5)
        } else {
            Issue.record("Expected itemsAdded event")
        }
    }

    @Test("QueueEvent parses items_changed")
    func queueEventItemsChanged() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [
                "items_changed": [
                    ["queue_item_id": 3, "three_line": ["line1": "Updated"] as [String: Any]] as [String: Any]
                ]
            ]
        )

        let event = QueueEvent.from(response: response)

        if case .itemsChanged(let items) = event {
            #expect(items.count == 1)
            #expect(items[0].id == 3)
        } else {
            Issue.record("Expected itemsChanged event")
        }
    }

    @Test("QueueEvent returns nil for empty Changed")
    func queueEventEmptyChanged() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [:]
        )

        let event = QueueEvent.from(response: response)

        #expect(event == nil)
    }

    @Test("QueueEvent returns nil for nil body")
    func queueEventNilBody() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Subscribed",
            body: nil
        )

        let event = QueueEvent.from(response: response)

        #expect(event == nil)
    }

    @Test("QueueEvent ignores empty arrays in items_added")
    func queueEventEmptyItemsAdded() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [
                "items_added": []
            ]
        )

        let event = QueueEvent.from(response: response)

        #expect(event == nil)
    }

    @Test("QueueEvent ignores items_removed with empty array")
    func queueEventEmptyRemoved() {
        let response = RoonResponse(
            verb: .continue,
            requestId: 1,
            name: "Changed",
            body: [
                "items_removed": []
            ]
        )

        let event = QueueEvent.from(response: response)

        #expect(event == nil)
    }
}
