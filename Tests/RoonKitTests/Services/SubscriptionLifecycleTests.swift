import Foundation
import Synchronization
import Testing
@testable import RoonKit

/// Thread-safe event collector for cross-isolation event gathering.
private final class EventCollector<T: Sendable>: Sendable {
    private let storage = Mutex<[T]>([])

    func append(_ event: T) {
        storage.withLock { $0.append(event) }
    }

    var events: [T] {
        storage.withLock { Array($0) }
    }

    var count: Int {
        storage.withLock { $0.count }
    }
}

/// Tests for subscription lifecycle using MockRoonServer.
///
/// Validates zone, output, and queue subscriptions — including re-subscribe behavior
/// and the stale termination handler guard that prevents bug `1da6869`.
@Suite("Subscription Lifecycle Tests", .serialized)
struct SubscriptionLifecycleTests {

    let extensionInfo = ExtensionInfo(
        extensionId: "com.test.app",
        displayName: "Test App",
        displayVersion: "1.0.0",
        publisher: "Test",
        email: "test@test.com"
    )

    // MARK: - Zone Subscription

    @Test("Zone subscription delivers initial zones")
    func zoneSubscriptionDeliversInitialZones() async throws {
        let zone = MockResponses.sampleZone(id: "z1", name: "Kitchen")
        let server = MockRoonServer(zones: [zone])
        let connection = server.createConnection(extensionInfo: extensionInfo)
        try await connection.connect()

        let transport = TransportService(connection: connection)
        let eventStream = try await transport.subscribeZones()

        // Collect the first event
        for await event in eventStream {
            if case .subscribed(let zones) = event {
                #expect(zones.count == 1)
                #expect(zones[0].id == "z1")
                #expect(zones[0].displayName == "Kitchen")
            }
            break
        }
    }

    @Test("Zone subscription delivers change events")
    func zoneSubscriptionDeliversChangeEvents() async throws {
        let zone = MockResponses.sampleZone(id: "z1", name: "Kitchen")
        let server = MockRoonServer(zones: [zone])
        let connection = server.createConnection(extensionInfo: extensionInfo)
        try await connection.connect()

        let transport = TransportService(connection: connection)
        let eventStream = try await transport.subscribeZones()

        let collector = EventCollector<ZoneEvent>()
        let collectTask = Task {
            for await event in eventStream {
                collector.append(event)
                if collector.count >= 2 { break }
            }
        }

        // Wait for initial subscription event to be processed
        try await Task.sleep(for: .milliseconds(50))

        // Inject a change
        let updatedZone = MockResponses.sampleZone(id: "z1", name: "Kitchen", state: "paused")
        server.injectZoneEvent(name: "Changed", zones: [updatedZone])

        await collectTask.value

        let receivedEvents = collector.events
        #expect(receivedEvents.count == 2)
        if case .subscribed = receivedEvents[0] {
            // Good — first event is Subscribed
        } else {
            Issue.record("Expected .subscribed as first event, got \(receivedEvents[0])")
        }
        if case .zonesChanged(let zones) = receivedEvents[1] {
            #expect(zones[0].state == .paused)
        } else {
            Issue.record("Expected .zonesChanged as second event, got \(receivedEvents[1])")
        }
    }

    @Test("Re-subscribe finishes old stream (prevents bug 0977722)")
    func reSubscribeFinishesOldStream() async throws {
        let zone = MockResponses.sampleZone()
        let server = MockRoonServer(zones: [zone])
        let connection = server.createConnection(extensionInfo: extensionInfo)
        try await connection.connect()

        let transport = TransportService(connection: connection)

        // First subscription
        let stream1 = try await transport.subscribeZones()

        // Collect events from stream1 to detect when it terminates
        let stream1Done = Task<Bool, Never> {
            var count = 0
            for await _ in stream1 {
                count += 1
                if count > 10 { return false } // safety limit
            }
            return true // stream terminated
        }

        // Wait for first subscription to be established
        try await Task.sleep(for: .milliseconds(50))

        // Second subscription — should finish the old stream
        let stream2 = try await transport.subscribeZones()

        // Verify stream1 terminates
        let terminated = await stream1Done.value
        #expect(terminated, "First stream should terminate when re-subscribing")

        // Verify stream2 is functional
        for await event in stream2 {
            if case .subscribed = event {
                break // stream2 works
            }
        }
    }

    @Test("Stale termination handler does not clobber new subscription (prevents bug 1da6869)")
    func staleTerminationHandlerDoesNotClobberNewSubscription() async throws {
        let zone = MockResponses.sampleZone(id: "z1", name: "Living Room")
        let server = MockRoonServer(zones: [zone])
        let connection = server.createConnection(extensionInfo: extensionInfo)
        try await connection.connect()

        let transport = TransportService(connection: connection)

        // First subscription
        let stream1 = try await transport.subscribeZones()

        // Drain the Subscribed event from stream1 so it's actively listening
        let stream1Task = Task<Void, Never> {
            for await _ in stream1 { }
        }

        // Wait for stream1 to be established
        try await Task.sleep(for: .milliseconds(50))

        // Second subscription — finishes stream1, which triggers stream1's onTermination
        let stream2 = try await transport.subscribeZones()

        // Wait for stream1's onTermination Task to fire and execute.
        // The handler runs in a Task { await self.handleSubscriptionTermination(key:) },
        // so we need to yield long enough for that actor-isolated call to complete.
        await stream1Task.value
        try await Task.sleep(for: .milliseconds(100))

        // Drain the initial Subscribed event from stream2
        let collector = EventCollector<ZoneEvent>()
        let stream2Task = Task {
            for await event in stream2 {
                collector.append(event)
                if collector.count >= 2 { break }
            }
        }

        // Wait for stream2 to process its Subscribed event
        try await Task.sleep(for: .milliseconds(50))

        // Inject a zone change — stream2 must still be alive to receive this
        let updatedZone = MockResponses.sampleZone(id: "z1", name: "Living Room", state: "paused")
        server.injectZoneEvent(name: "Changed", zones: [updatedZone])

        await stream2Task.value

        // Verify stream2 received both events: Subscribed + Changed
        let events = collector.events
        #expect(events.count == 2, "Stream2 should receive both Subscribed and Changed events")
        if case .subscribed = events[0] {
            // Expected
        } else {
            Issue.record("Expected .subscribed as first event, got \(events[0])")
        }
        if case .zonesChanged(let zones) = events[1] {
            #expect(zones[0].state == .paused)
        } else {
            Issue.record("Expected .zonesChanged as second event, got \(events[1])")
        }
    }

    // MARK: - Output Subscription

    @Test("Output subscription delivers initial outputs")
    func outputSubscriptionDeliversInitialOutputs() async throws {
        let output = MockResponses.sampleOutput(id: "o1", zoneId: "z1", name: "Speakers")
        let server = MockRoonServer(outputs: [output])
        let connection = server.createConnection(extensionInfo: extensionInfo)
        try await connection.connect()

        let transport = TransportService(connection: connection)
        let eventStream = try await transport.subscribeOutputs()

        for await event in eventStream {
            if case .subscribed(let outputs) = event {
                #expect(outputs.count == 1)
                #expect(outputs[0].id == "o1")
                #expect(outputs[0].displayName == "Speakers")
            }
            break
        }
    }

    @Test("Simultaneous output add and remove both delivered (prevents bug 8f8076a)")
    func simultaneousOutputAddAndRemove() async throws {
        let output = MockResponses.sampleOutput(id: "o1", zoneId: "z1")
        let server = MockRoonServer(outputs: [output])
        let connection = server.createConnection(extensionInfo: extensionInfo)
        try await connection.connect()

        let transport = TransportService(connection: connection)
        let eventStream = try await transport.subscribeOutputs()

        let collector = EventCollector<OutputEvent>()
        let collectTask = Task {
            for await event in eventStream {
                collector.append(event)
                // Subscribed + the two events from Changed
                if collector.count >= 3 { break }
            }
        }

        // Wait for initial subscription
        try await Task.sleep(for: .milliseconds(50))

        // Inject a Changed message with both removed and added
        guard let requestId = server.outputSubscriptionRequestId else {
            Issue.record("No output subscription request ID")
            return
        }
        let newOutput = MockResponses.sampleOutput(id: "o2", zoneId: "z2", name: "Kitchen")
        let body: [String: Any] = [
            "outputs_removed": ["o1"],
            "outputs_added": [newOutput]
        ]
        let response = MockResponses.continueResponse(requestId: requestId, name: "Changed", body: body)
        server.transport.injectMessage(.data(response.data(using: .utf8)!))

        await collectTask.value

        // Should see: subscribed, then both outputsRemoved and outputsAdded
        let receivedEvents = collector.events
        #expect(receivedEvents.count == 3)
        let hasRemoved = receivedEvents.contains { if case .outputsRemoved = $0 { return true }; return false }
        let hasAdded = receivedEvents.contains { if case .outputsAdded = $0 { return true }; return false }
        #expect(hasRemoved, "Should have outputsRemoved event")
        #expect(hasAdded, "Should have outputsAdded event")
    }

    // MARK: - Queue Subscription

    @Test("Queue subscription delivers initial items")
    func queueSubscriptionDeliversInitialItems() async throws {
        let item = MockResponses.sampleQueueItem(id: 1, title: "Test Song")
        let server = MockRoonServer(queueItems: [item])
        let connection = server.createConnection(extensionInfo: extensionInfo)
        try await connection.connect()

        let transport = TransportService(connection: connection)
        await transport.selectZone(id: "zone-1")
        let eventStream = try await transport.subscribeQueue(zoneOrOutputId: "zone-1")

        for await event in eventStream {
            if case .subscribed(let items) = event {
                #expect(items.count == 1)
                #expect(items[0].title == "Test Song")
            }
            break
        }
    }

    @Test("Queue re-subscribe on rapid zone switch (prevents bug 7c33b65)")
    func queueReSubscribeOnZoneSwitch() async throws {
        let item1 = MockResponses.sampleQueueItem(id: 1, title: "Song A")
        let item2 = MockResponses.sampleQueueItem(id: 2, title: "Song B")
        let server = MockRoonServer(queueItems: [item1])
        let connection = server.createConnection(extensionInfo: extensionInfo)
        try await connection.connect()

        let transport = TransportService(connection: connection)

        // Subscribe to first zone
        let stream1 = try await transport.subscribeQueue(zoneOrOutputId: "zone-1")

        // Consume first event from stream1
        for await event in stream1 {
            if case .subscribed = event { break }
        }

        // Rapidly switch to second zone
        server.queueItems = [item2]
        let stream2 = try await transport.subscribeQueue(zoneOrOutputId: "zone-2")

        // Second stream should deliver
        for await event in stream2 {
            if case .subscribed(let items) = event {
                #expect(items.count == 1)
                #expect(items[0].title == "Song B")
            }
            break
        }
    }
}
