import Foundation
import Testing
@testable import RigControl

/// Diagnostic + regression tests for macwinlink-releases#54 (second
/// followup). MacWinlink beta38 Air testing showed Direwolf logging
/// `rig_set_ptt returning(-9)` for `T VFOA 0` and `returning(-10)`
/// for `T VFOA 1` on every PTT toggle — the radio keyed correctly,
/// but Hamlib treated the reply as a warning. Wire capture showed
/// Direwolf reading 8 bytes for `T VFOA 0` and 9 bytes for
/// `T VFOA 1` where a successful `RPRT 0\n` is exactly 7 bytes.
@Suite struct RigctldSetPTTWireBytesTests {

    private func makeHandler() async throws -> RigctldCommandHandler {
        let caps = RigCapabilities(
            hasVFOB: true,
            frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000)
        )
        let rig = try RigController(
            radio: .dummy(name: "Test", capabilities: caps),
            connection: .mock
        )
        try await rig.connect()
        return RigctldCommandHandler(rigController: rig)
    }

    /// Runs the exact wire pipeline a client sees: parse the raw
    /// command line, dispatch through the handler, format the
    /// response in default protocol mode, return the resulting
    /// bytes. This is what `ClientSession.send(...)` writes to
    /// the socket.
    private func wireResponse(for line: String, handler: RigctldCommandHandler) async throws -> String {
        let parser = RigctldCommandParser()
        let command = try parser.parse(line)
        let response = await handler.handle(command)
        return response.format(mode: .default)
    }

    // MARK: - The exact failing cases from the field report

    @Test func setPTTZeroReturnsExactlyRPRT0() async throws {
        let handler = try await makeHandler()
        let wire = try await wireResponse(for: "T 0", handler: handler)
        #expect(wire == "RPRT 0\n",
                "`T 0` must produce exactly 7 bytes `RPRT 0\\n`. Got \(wire.count) bytes: \(wire.debugDescription).")
        #expect(wire.utf8.count == 7)
    }

    @Test func setPTTOneReturnsExactlyRPRT0() async throws {
        let handler = try await makeHandler()
        let wire = try await wireResponse(for: "T 1", handler: handler)
        #expect(wire == "RPRT 0\n",
                "`T 1` must produce exactly 7 bytes `RPRT 0\\n`. Got \(wire.count) bytes: \(wire.debugDescription).")
        #expect(wire.utf8.count == 7)
    }

    @Test func setPTTVFOAZeroReturnsExactlyRPRT0() async throws {
        // The Direwolf-under-vfo_opt-1 wire form. Field report:
        // Direwolf read 8 bytes, Hamlib returned `-9 rejected`.
        let handler = try await makeHandler()
        let wire = try await wireResponse(for: "T VFOA 0", handler: handler)
        #expect(wire == "RPRT 0\n",
                "`T VFOA 0` must produce exactly 7 bytes `RPRT 0\\n`. Got \(wire.count) bytes: \(wire.debugDescription).")
        #expect(wire.utf8.count == 7)
    }

    @Test func setPTTVFOAOneReturnsExactlyRPRT0() async throws {
        // The other failing case. Direwolf read 9 bytes → Hamlib
        // returned `-10 arg truncated`.
        let handler = try await makeHandler()
        let wire = try await wireResponse(for: "T VFOA 1", handler: handler)
        #expect(wire == "RPRT 0\n",
                "`T VFOA 1` must produce exactly 7 bytes `RPRT 0\\n`. Got \(wire.count) bytes: \(wire.debugDescription).")
        #expect(wire.utf8.count == 7)
    }

    // MARK: - Related set-commands that also accept VFO prefix

    @Test func setFrequencyReturnsExactlyRPRT0() async throws {
        let handler = try await makeHandler()
        let wire = try await wireResponse(for: "F 14070000", handler: handler)
        #expect(wire == "RPRT 0\n")
    }

    @Test func setFrequencyWithVFOAReturnsExactlyRPRT0() async throws {
        let handler = try await makeHandler()
        let wire = try await wireResponse(for: "F VFOA 14070000", handler: handler)
        #expect(wire == "RPRT 0\n")
    }

    @Test func setModeReturnsExactlyRPRT0() async throws {
        let handler = try await makeHandler()
        let wire = try await wireResponse(for: "M USB 2400", handler: handler)
        #expect(wire == "RPRT 0\n")
    }

    @Test func setModeWithVFOAReturnsExactlyRPRT0() async throws {
        let handler = try await makeHandler()
        let wire = try await wireResponse(for: "M VFOA USB 2400", handler: handler)
        #expect(wire == "RPRT 0\n")
    }

    @Test func setSplitReturnsExactlyRPRT0() async throws {
        let handler = try await makeHandler()
        let wire = try await wireResponse(for: "S 1 VFOB", handler: handler)
        #expect(wire == "RPRT 0\n")
    }

    @Test func setSplitWithVFOAReturnsExactlyRPRT0() async throws {
        let handler = try await makeHandler()
        let wire = try await wireResponse(for: "S VFOA 0 VFOB", handler: handler)
        #expect(wire == "RPRT 0\n")
    }
}
