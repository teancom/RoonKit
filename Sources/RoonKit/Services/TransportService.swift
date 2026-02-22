import Foundation
import os

private let log = Logger(subsystem: RoonKitLog.subsystem, category: "Transport")

/// Service for controlling playback and managing zones
public actor TransportService {
    private let connection: RoonConnection
    private var subscriptionKey: Int = 1
    private var zoneSubscription: Task<Void, Never>?
    private var outputSubscription: Task<Void, Never>?
    private var queueSubscriptions: [String: Task<Void, Never>] = [:]

    /// Currently known zones
    public private(set) var zones: [String: Zone] = [:]

    /// Currently known outputs
    public private(set) var outputs: [String: Output] = [:]

    /// Currently selected zone ID
    public private(set) var selectedZoneId: String?

    /// Stream of zone events
    private var zoneEventContinuation: AsyncStream<ZoneEvent>.Continuation?
    /// The subscription key currently owning zoneSubscription/zoneEventContinuation.
    /// Termination handlers check this to avoid clobbering a newer subscription.
    private var activeZoneSubscriptionKey: Int?

    /// Stream of output events
    private var outputEventContinuation: AsyncStream<OutputEvent>.Continuation?
    /// The subscription key currently owning outputSubscription/outputEventContinuation.
    private var activeOutputSubscriptionKey: Int?

    /// Queue event continuations keyed by zone/output ID
    private var queueEventContinuations: [String: AsyncStream<QueueEvent>.Continuation] = [:]
    /// The subscription key currently owning each queue subscription, keyed by zone/output ID.
    private var activeQueueSubscriptionKeys: [String: Int] = [:]

    public init(connection: RoonConnection) {
        self.connection = connection
    }

    // MARK: - Zone Selection

    /// Select a zone for playback commands
    public func selectZone(id: String) {
        selectedZoneId = id
    }

    /// Get the currently selected zone
    public var selectedZone: Zone? {
        guard let id = selectedZoneId else { return nil }
        return zones[id]
    }

    // MARK: - Zone Subscription

    /// Subscribe to zone updates and return a stream of events
    public func subscribeZones() async throws -> AsyncStream<ZoneEvent> {
        let key = subscriptionKey
        subscriptionKey += 1
        log.log(level: DebugLogging.verboseLevel,"subscribeZones key=\(key)")

        let responseStream = try await connection.subscribe(
            path: RoonService.path(RoonService.transport, "subscribe_zones"),
            body: ["subscription_key": key]
        )
        log.log(level: DebugLogging.verboseLevel,"subscribeZones: got responseStream key=\(key)")

        let eventStream = AsyncStream<ZoneEvent> { continuation in
            self.zoneEventContinuation?.finish()
            self.zoneEventContinuation = continuation
            self.activeZoneSubscriptionKey = key

            continuation.onTermination = { @Sendable _ in
                log.log(level: DebugLogging.verboseLevel,"subscribeZones: eventStream onTermination key=\(key)")
                Task { await self.handleSubscriptionTermination(key: key) }
            }
        }

        // Process responses in background
        zoneSubscription = Task {
            log.log(level: DebugLogging.verboseLevel,"zoneResponseTask: started key=\(key)")
            for await response in responseStream {
                self.processZoneResponse(response)
            }
            // Response stream ended (connection dropped) — finish the event
            // stream so downstream consumers see the stream end and can nil
            // their task handles for re-subscription.
            log.log(level: DebugLogging.verboseLevel,"zoneResponseTask: responseStream ended, finishing eventStream key=\(key)")
            self.zoneEventContinuation?.finish()
        }

        return eventStream
    }

    private func processZoneResponse(_ response: RoonResponse) {
        let events = ZoneEvent.from(response: response)
        guard !events.isEmpty else { return }

        for event in events {
            // Update local zone cache
            switch event {
            case .subscribed(let newZones):
                zones.removeAll()
                for zone in newZones {
                    zones[zone.id] = zone
                }

            case .zonesAdded(let newZones):
                for zone in newZones {
                    zones[zone.id] = zone
                }

            case .zonesRemoved(let ids):
                for id in ids {
                    zones.removeValue(forKey: id)
                }

            case .zonesChanged(let updatedZones):
                for zone in updatedZones {
                    zones[zone.id] = zone
                }

            case .zonesSeekChanged:
                // For seek updates, we don't have full zone data
                // The consumer should handle these lightweight updates
                break
            }

            // Emit event
            zoneEventContinuation?.yield(event)
        }
    }

    private func handleSubscriptionTermination(key: Int) async {
        // Only clean up if this termination is for the *current* subscription.
        // When subscribeZones() is called twice rapidly, the old subscription's
        // onTermination fires after the new subscription is already set up.
        // Without this guard, the old handler would cancel the new subscription.
        guard activeZoneSubscriptionKey == key else { return }

        zoneSubscription?.cancel()
        zoneSubscription = nil
        zoneEventContinuation?.finish()
        zoneEventContinuation = nil
        activeZoneSubscriptionKey = nil

        // Send unsubscribe request (fire and forget)
        _ = try? await connection.send(
            path: RoonService.path(RoonService.transport, "unsubscribe_zones"),
            body: ["subscription_key": key]
        )
    }

    // MARK: - Output Subscription

    /// Subscribe to output updates and return a stream of events
    public func subscribeOutputs() async throws -> AsyncStream<OutputEvent> {
        let key = subscriptionKey
        subscriptionKey += 1

        let responseStream = try await connection.subscribe(
            path: RoonService.path(RoonService.transport, "subscribe_outputs"),
            body: ["subscription_key": key]
        )

        let eventStream = AsyncStream<OutputEvent> { continuation in
            self.outputEventContinuation?.finish()
            self.outputEventContinuation = continuation
            self.activeOutputSubscriptionKey = key

            continuation.onTermination = { @Sendable _ in
                Task { await self.handleOutputSubscriptionTermination(key: key) }
            }
        }

        // Process responses in background
        outputSubscription = Task {
            for await response in responseStream {
                self.processOutputResponse(response)
            }
            // Response stream ended (connection dropped) — finish the event
            // stream so downstream consumers see the stream end.
            self.outputEventContinuation?.finish()
        }

        return eventStream
    }

    private func processOutputResponse(_ response: RoonResponse) {
        let events = OutputEvent.from(response: response)
        guard !events.isEmpty else { return }

        for event in events {
            // Update local output cache
            switch event {
            case .subscribed(let newOutputs):
                outputs.removeAll()
                for output in newOutputs {
                    outputs[output.id] = output
                }

            case .outputsAdded(let newOutputs):
                for output in newOutputs {
                    outputs[output.id] = output
                }

            case .outputsRemoved(let ids):
                for id in ids {
                    outputs.removeValue(forKey: id)
                }

            case .outputsChanged(let updatedOutputs):
                for output in updatedOutputs {
                    outputs[output.id] = output
                }
            }

            // Emit event
            outputEventContinuation?.yield(event)
        }
    }

    private func handleOutputSubscriptionTermination(key: Int) async {
        guard activeOutputSubscriptionKey == key else { return }

        outputSubscription?.cancel()
        outputSubscription = nil
        outputEventContinuation?.finish()
        outputEventContinuation = nil
        activeOutputSubscriptionKey = nil

        // Send unsubscribe request (fire and forget)
        _ = try? await connection.send(
            path: RoonService.path(RoonService.transport, "unsubscribe_outputs"),
            body: ["subscription_key": key]
        )
    }

    // MARK: - Queue Subscription

    /// Subscribe to queue updates for a zone and return a stream of events
    /// - Parameters:
    ///   - zoneOrOutputId: The zone or output ID to subscribe to
    ///   - maxItemCount: Maximum number of queue items to return
    /// - Returns: Async stream of queue events
    public func subscribeQueue(
        zoneOrOutputId: String,
        maxItemCount: Int = 100
    ) async throws -> AsyncStream<QueueEvent> {
        let key = subscriptionKey
        subscriptionKey += 1

        let responseStream = try await connection.subscribe(
            path: RoonService.path(RoonService.transport, "subscribe_queue"),
            body: [
                "subscription_key": key,
                "zone_or_output_id": zoneOrOutputId,
                "max_item_count": maxItemCount
            ]
        )

        let eventStream = AsyncStream<QueueEvent> { continuation in
            self.queueEventContinuations[zoneOrOutputId]?.finish()
            self.queueEventContinuations[zoneOrOutputId] = continuation
            self.activeQueueSubscriptionKeys[zoneOrOutputId] = key

            continuation.onTermination = { @Sendable _ in
                Task { await self.handleQueueSubscriptionTermination(zoneOrOutputId: zoneOrOutputId, key: key) }
            }
        }

        // Process responses in background
        let task = Task {
            for await response in responseStream {
                self.processQueueResponse(response, zoneOrOutputId: zoneOrOutputId)
            }
            // Response stream ended (connection dropped) — finish the event
            // stream so downstream consumers (QueueState) see the stream
            // end and can nil their task handles for re-subscription.
            self.queueEventContinuations[zoneOrOutputId]?.finish()
        }
        queueSubscriptions[zoneOrOutputId] = task

        return eventStream
    }

    private func processQueueResponse(_ response: RoonResponse, zoneOrOutputId: String) {
        guard let event = QueueEvent.from(response: response) else { return }

        // Emit event
        queueEventContinuations[zoneOrOutputId]?.yield(event)
    }

    private func handleQueueSubscriptionTermination(zoneOrOutputId: String, key: Int) async {
        guard activeQueueSubscriptionKeys[zoneOrOutputId] == key else { return }

        queueSubscriptions[zoneOrOutputId]?.cancel()
        queueSubscriptions.removeValue(forKey: zoneOrOutputId)
        queueEventContinuations[zoneOrOutputId]?.finish()
        queueEventContinuations.removeValue(forKey: zoneOrOutputId)
        activeQueueSubscriptionKeys.removeValue(forKey: zoneOrOutputId)

        // Send unsubscribe request (fire and forget)
        _ = try? await connection.send(
            path: RoonService.path(RoonService.transport, "unsubscribe_queue"),
            body: ["subscription_key": key]
        )
    }

    /// Start playback from a specific item in the queue
    public func playFromHere(queueItemId: Int, zoneOrOutputId: String? = nil) async throws {
        guard let targetId = zoneOrOutputId ?? selectedZoneId else {
            throw TransportError.noZoneSelected
        }
        try await sendCommand("play_from_here", body: [
            "zone_or_output_id": targetId, "queue_item_id": queueItemId
        ])
    }

    // MARK: - Command Helper

    /// Send a transport command and throw on failure.
    private func sendCommand(_ action: String, body: sending [String: Any]) async throws {
        let response = try await connection.send(
            path: RoonService.path(RoonService.transport, action),
            body: body
        )
        if !response.isSuccess {
            throw TransportError.commandFailed(response.errorMessage ?? "unknown error")
        }
    }

    /// Send a transport command that requires a selected zone.
    private func sendZoneCommand(_ action: String, body: [String: Any] = [:]) async throws {
        guard let zoneId = selectedZoneId else {
            throw TransportError.noZoneSelected
        }
        var fullBody = body
        fullBody["zone_or_output_id"] = zoneId
        try await sendCommand(action, body: fullBody)
    }

    // MARK: - Playback Controls

    /// Play the selected zone
    public func play() async throws {
        try await sendZoneCommand("control", body: ["control": "play"])
    }

    /// Pause the selected zone
    public func pause() async throws {
        try await sendZoneCommand("control", body: ["control": "pause"])
    }

    /// Toggle play/pause
    public func playPause() async throws {
        try await sendZoneCommand("control", body: ["control": "playpause"])
    }

    /// Stop playback
    public func stop() async throws {
        try await sendZoneCommand("control", body: ["control": "stop"])
    }

    /// Skip to next track
    public func next() async throws {
        try await sendZoneCommand("control", body: ["control": "next"])
    }

    /// Skip to previous track
    public func previous() async throws {
        try await sendZoneCommand("control", body: ["control": "previous"])
    }

    // MARK: - Volume Control

    /// Set absolute volume for an output
    public func setVolume(outputId: String, level: Double) async throws {
        try await sendCommand("change_volume", body: [
            "output_id": outputId, "how": "absolute", "value": level
        ])
    }

    /// Adjust volume relatively for an output
    public func adjustVolume(outputId: String, delta: Double) async throws {
        try await sendCommand("change_volume", body: [
            "output_id": outputId, "how": "relative", "value": delta
        ])
    }

    /// Step volume up/down for an output
    public func stepVolume(outputId: String, steps: Int) async throws {
        try await sendCommand("change_volume", body: [
            "output_id": outputId, "how": "relative_step", "value": steps
        ])
    }

    /// Mute an output
    public func mute(outputId: String) async throws {
        try await sendCommand("mute", body: ["output_id": outputId, "how": "mute"])
    }

    /// Unmute an output
    public func unmute(outputId: String) async throws {
        try await sendCommand("mute", body: ["output_id": outputId, "how": "unmute"])
    }

    /// Mute all zones that support muting
    public func muteAll() async throws {
        try await sendCommand("mute_all", body: ["how": "mute"])
    }

    /// Unmute all zones that support muting
    public func unmuteAll() async throws {
        try await sendCommand("mute_all", body: ["how": "unmute"])
    }

    /// Pause all zones
    public func pauseAll() async throws {
        try await sendCommand("pause_all", body: [:])
    }

    // MARK: - Standby Controls

    /// Put an output into standby
    public func standby(outputId: String, controlKey: String? = nil) async throws {
        var body: [String: Any] = ["output_id": outputId]
        if let controlKey { body["control_key"] = controlKey }
        try await sendCommand("standby", body: body)
    }

    /// Toggle the standby state of an output
    public func toggleStandby(outputId: String, controlKey: String? = nil) async throws {
        var body: [String: Any] = ["output_id": outputId]
        if let controlKey { body["control_key"] = controlKey }
        try await sendCommand("toggle_standby", body: body)
    }

    /// Convenience switch an output, taking it out of standby if needed
    public func convenienceSwitch(outputId: String, controlKey: String? = nil) async throws {
        var body: [String: Any] = ["output_id": outputId]
        if let controlKey { body["control_key"] = controlKey }
        try await sendCommand("convenience_switch", body: body)
    }

    // MARK: - Zone Transfer and Output Grouping

    /// Transfer the current queue from one zone to another
    public func transferZone(from fromZoneOrOutputId: String, to toZoneOrOutputId: String) async throws {
        try await sendCommand("transfer_zone", body: [
            "from_zone_or_output_id": fromZoneOrOutputId,
            "to_zone_or_output_id": toZoneOrOutputId
        ])
    }

    /// Create a group of synchronized audio outputs
    public func groupOutputs(_ outputIds: [String]) async throws {
        try await sendCommand("group_outputs", body: ["output_ids": outputIds])
    }

    /// Ungroup outputs that were previously grouped
    public func ungroupOutputs(_ outputIds: [String]) async throws {
        try await sendCommand("ungroup_outputs", body: ["output_ids": outputIds])
    }

    // MARK: - Get Zones and Outputs

    /// Get all zones (one-shot, no subscription)
    /// - Returns: Array of zones
    public func getZones() async throws -> [Zone] {
        let response = try await connection.send(
            path: RoonService.path(RoonService.transport, "get_zones"),
            body: [:]
        )

        guard response.isSuccess, let body = response.body else {
            throw TransportError.commandFailed(response.errorMessage ?? "unknown error")
        }

        let zonesArray = body["zones"] as? [[String: Any]] ?? []
        return zonesArray.compactMap { Zone(from: $0) }
    }

    /// Get all outputs (one-shot, no subscription)
    /// - Returns: Array of outputs
    public func getOutputs() async throws -> [Output] {
        let response = try await connection.send(
            path: RoonService.path(RoonService.transport, "get_outputs"),
            body: [:]
        )

        guard response.isSuccess, let body = response.body else {
            throw TransportError.commandFailed(response.errorMessage ?? "unknown error")
        }

        let outputsArray = body["outputs"] as? [[String: Any]] ?? []
        return outputsArray.compactMap { Output(from: $0) }
    }

    // MARK: - Seek

    /// Seek to absolute position in seconds
    public func seek(to seconds: Double) async throws {
        try await sendZoneCommand("seek", body: ["how": "absolute", "seconds": seconds])
    }

    /// Seek by relative amount in seconds (positive or negative)
    public func seek(by seconds: Double) async throws {
        try await sendZoneCommand("seek", body: ["how": "relative", "seconds": seconds])
    }

    // MARK: - Settings

    /// Set shuffle mode for the selected zone
    public func setShuffle(enabled: Bool) async throws {
        try await changeSettings(shuffle: enabled)
    }

    /// Set loop mode for the selected zone
    public func setLoop(mode: LoopMode) async throws {
        try await changeSettings(loop: mode.rawValue)
    }

    /// Cycle to the next loop mode (disabled -> loop -> loop_one -> disabled)
    /// This sends "next" to the server, which handles the cycling
    public func cycleLoop() async throws {
        try await changeSettings(loop: "next")
    }

    /// Set auto-radio mode for the selected zone
    public func setAutoRadio(enabled: Bool) async throws {
        try await changeSettings(autoRadio: enabled)
    }

    private func changeSettings(
        shuffle: Bool? = nil,
        loop: String? = nil,
        autoRadio: Bool? = nil
    ) async throws {
        var body: [String: Any] = [:]
        if let shuffle { body["shuffle"] = shuffle }
        if let loop { body["loop"] = loop }
        if let autoRadio { body["auto_radio"] = autoRadio }
        try await sendZoneCommand("change_settings", body: body)
    }
}

/// Errors from transport service operations
public enum TransportError: Error, Sendable, Equatable {
    case noZoneSelected
    case commandFailed(String)
}

extension TransportError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noZoneSelected:
            return "no zone selected"
        case .commandFailed(let message):
            return "command failed: \(message)"
        }
    }
}
