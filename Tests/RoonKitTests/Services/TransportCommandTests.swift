import Foundation
import Testing
@testable import RoonKit

/// Tests for transport commands via MockRoonServer.
///
/// Verifies that each TransportService method sends the correct MOO protocol message
/// with the expected service path, command verb, and body parameters.
@Suite("Transport Command Tests", .serialized)
struct TransportCommandTests {

    let extensionInfo = ExtensionInfo(
        extensionId: "com.test.app",
        displayName: "Test App",
        displayVersion: "1.0.0",
        publisher: "Test",
        email: "test@test.com"
    )

    /// Helper: create a connected transport service with a selected zone
    private func makeService() async throws -> (TransportService, MockRoonServer) {
        let server = MockRoonServer()
        let connection = server.createConnection(extensionInfo: extensionInfo)
        try await connection.connect()

        let transport = TransportService(connection: connection)
        await transport.selectZone(id: "zone-1")

        return (transport, server)
    }

    // MARK: - Playback Controls

    @Test("Play sends correct control message")
    func playSendsCorrectMessage() async throws {
        let (transport, server) = try await makeService()

        try await transport.play()

        let commands = server.receivedCommands
        let playCmd = commands.first { $0.method == "control" }
        #expect(playCmd != nil)
        #expect(playCmd?.body?["control"] as? String == "play")
        #expect(playCmd?.body?["zone_or_output_id"] as? String == "zone-1")
    }

    @Test("Pause sends correct control message")
    func pauseSendsCorrectMessage() async throws {
        let (transport, server) = try await makeService()

        try await transport.pause()

        let cmd = server.receivedCommands.first { $0.method == "control" }
        #expect(cmd?.body?["control"] as? String == "pause")
    }

    @Test("Stop sends correct control message")
    func stopSendsCorrectMessage() async throws {
        let (transport, server) = try await makeService()

        try await transport.stop()

        let cmd = server.receivedCommands.first { $0.method == "control" }
        #expect(cmd?.body?["control"] as? String == "stop")
    }

    @Test("Next sends correct control message")
    func nextSendsCorrectMessage() async throws {
        let (transport, server) = try await makeService()

        try await transport.next()

        let cmd = server.receivedCommands.first { $0.method == "control" }
        #expect(cmd?.body?["control"] as? String == "next")
    }

    @Test("Previous sends correct control message")
    func previousSendsCorrectMessage() async throws {
        let (transport, server) = try await makeService()

        try await transport.previous()

        let cmd = server.receivedCommands.first { $0.method == "control" }
        #expect(cmd?.body?["control"] as? String == "previous")
    }

    // MARK: - Volume Control

    @Test("SetVolume sends absolute volume command")
    func setVolumeSendsAbsoluteCommand() async throws {
        let (transport, server) = try await makeService()

        try await transport.setVolume(outputId: "output-1", level: -20.0)

        let cmd = server.receivedCommands.first { $0.method == "change_volume" }
        #expect(cmd != nil)
        #expect(cmd?.body?["output_id"] as? String == "output-1")
        #expect(cmd?.body?["how"] as? String == "absolute")
        #expect(cmd?.body?["value"] as? Double == -20.0)
    }

    @Test("Mute sends mute command")
    func muteSendsMuteCommand() async throws {
        let (transport, server) = try await makeService()

        try await transport.mute(outputId: "output-1")

        let cmd = server.receivedCommands.first { $0.method == "mute" }
        #expect(cmd != nil)
        #expect(cmd?.body?["output_id"] as? String == "output-1")
        #expect(cmd?.body?["how"] as? String == "mute")
    }

    @Test("MuteAll sends global mute command")
    func muteAllSendsGlobalMuteCommand() async throws {
        let (transport, server) = try await makeService()

        try await transport.muteAll()

        let cmd = server.receivedCommands.first { $0.method == "mute_all" }
        #expect(cmd != nil)
        #expect(cmd?.body?["how"] as? String == "mute")
    }

    // MARK: - Settings

    @Test("SetShuffle sends settings change")
    func setShuffleSendsSettingsChange() async throws {
        let (transport, server) = try await makeService()

        try await transport.setShuffle(enabled: true)

        let cmd = server.receivedCommands.first { $0.method == "change_settings" }
        #expect(cmd != nil)
        #expect(cmd?.body?["shuffle"] as? Bool == true)
        #expect(cmd?.body?["zone_or_output_id"] as? String == "zone-1")
    }

    @Test("SetLoop sends settings change")
    func setLoopSendsSettingsChange() async throws {
        let (transport, server) = try await makeService()

        try await transport.setLoop(mode: .loop)

        let cmd = server.receivedCommands.first { $0.method == "change_settings" }
        #expect(cmd != nil)
        #expect(cmd?.body?["loop"] as? String == "loop")
    }

    @Test("SetAutoRadio sends settings change")
    func setAutoRadioSendsSettingsChange() async throws {
        let (transport, server) = try await makeService()

        try await transport.setAutoRadio(enabled: true)

        let cmd = server.receivedCommands.first { $0.method == "change_settings" }
        #expect(cmd != nil)
        #expect(cmd?.body?["auto_radio"] as? Bool == true)
    }

    // MARK: - Seek

    @Test("Seek sends absolute seek command")
    func seekSendsAbsoluteCommand() async throws {
        let (transport, server) = try await makeService()

        try await transport.seek(to: 120.0)

        let cmd = server.receivedCommands.first { $0.method == "seek" }
        #expect(cmd != nil)
        #expect(cmd?.body?["how"] as? String == "absolute")
        #expect(cmd?.body?["seconds"] as? Double == 120.0)
    }

    // MARK: - Standby and Transfer

    @Test("Standby sends standby command")
    func standbySendsCommand() async throws {
        let (transport, server) = try await makeService()

        try await transport.standby(outputId: "output-1", controlKey: "key-1")

        let cmd = server.receivedCommands.first { $0.method == "standby" }
        #expect(cmd != nil)
        #expect(cmd?.body?["output_id"] as? String == "output-1")
        #expect(cmd?.body?["control_key"] as? String == "key-1")
    }

    @Test("TransferZone sends transfer command")
    func transferZoneSendsCommand() async throws {
        let (transport, server) = try await makeService()

        try await transport.transferZone(from: "zone-1", to: "zone-2")

        let cmd = server.receivedCommands.first { $0.method == "transfer_zone" }
        #expect(cmd != nil)
        #expect(cmd?.body?["from_zone_or_output_id"] as? String == "zone-1")
        #expect(cmd?.body?["to_zone_or_output_id"] as? String == "zone-2")
    }

    // MARK: - Grouping

    @Test("GroupOutputs sends group command")
    func groupOutputsSendsCommand() async throws {
        let (transport, server) = try await makeService()

        try await transport.groupOutputs(["output-1", "output-2"])

        let cmd = server.receivedCommands.first { $0.method == "group_outputs" }
        #expect(cmd != nil)
        #expect(cmd?.body?["output_ids"] as? [String] == ["output-1", "output-2"])
    }

    @Test("UngroupOutputs sends ungroup command")
    func ungroupOutputsSendsCommand() async throws {
        let (transport, server) = try await makeService()

        try await transport.ungroupOutputs(["output-1", "output-2"])

        let cmd = server.receivedCommands.first { $0.method == "ungroup_outputs" }
        #expect(cmd != nil)
        #expect(cmd?.body?["output_ids"] as? [String] == ["output-1", "output-2"])
    }

    // MARK: - Error Cases

    @Test("No zone selected throws TransportError")
    func noZoneSelectedThrowsError() async throws {
        let server = MockRoonServer()
        let connection = server.createConnection(extensionInfo: extensionInfo)
        try await connection.connect()

        let transport = TransportService(connection: connection)
        // Don't select a zone

        do {
            try await transport.play()
            Issue.record("Expected TransportError.noZoneSelected")
        } catch let error as TransportError {
            #expect(error == .noZoneSelected)
        }
    }
}
