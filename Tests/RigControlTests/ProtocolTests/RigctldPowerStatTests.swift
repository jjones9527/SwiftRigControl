import Foundation
import Testing
@testable import RigControl

/// Tests for `\get_powerstat` / `\set_powerstat` end-to-end
/// dispatch through `RigctldCommandHandler`.
///
/// Reproduces the failure surfaced in issue #14 (IC-9700
/// returning `RPRT -1` for `\get_powerstat` under MacWinlink
/// beta35-rc1 Air testing) and pins the fixed behaviour.
///
/// Reference: Hamlib `icom_get_powerstat` (`icom.c:8218`) probes
/// the IC-9700 / IC-7300 / IC-705 / IC-7100 / IC-7600 / IC-7610
/// / IC-7700 / IC-7800 / IC-785X / IC-905 / IC-2730 by calling
/// `rig_get_freq`; a successful read means power is ON, a timeout
/// means OFF. SwiftRigControl's `IcomCIVProtocol.getPowerState`
/// follows the same strategy — this test locks the wire-level
/// behaviour through the rigctld bridge.
@Suite struct RigctldPowerStatTests {

    /// Build a real IC-9700 controller wired to `.mock` so we can
    /// script the CI-V wire and drive `\get_powerstat` end-to-end.
    private func makeIC9700Handler() async throws -> (
        RigController,
        RigctldCommandHandler,
        MockSerialTransport
    ) {
        let rig = try RigController(
            radio: .Icom.ic9700(),
            connection: .mock
        )
        try await rig.connect()
        let proto = await rig.rawProtocol
        let mock = await proto.transport as! MockSerialTransport
        let handler = RigctldCommandHandler(rigController: rig)
        return (rig, handler, mock)
    }

    // MARK: - get_powerstat

    /// `\get_powerstat` on an IC-9700 that responds to the
    /// frequency-read probe must dispatch through
    /// `RigController.getPowerState()` and return `"1"` with
    /// `RPRT 0`.
    @Test func getPowerStatReturnsOneWhenRadioResponds() async throws {
        let (_, handler, mock) = try await makeIC9700Handler()

        // IC-9700 (CI-V 0xA2, controller 0xE0) reply to 0x03
        // (read frequency) at 145.500 MHz.  BCD little-endian:
        //   145,500,000 Hz → 0x00 0x00 0x50 0x45 0x01
        let freqReply = Data([
            0xFE, 0xFE, 0xE0, 0xA2, 0x03,
            0x00, 0x00, 0x50, 0x45, 0x01,
            0xFD,
        ])
        await mock.setResponse(
            for: Data([0xFE, 0xFE, 0xA2, 0xE0, 0x03, 0xFD]),
            response: freqReply
        )

        let response = await handler.handle(.getPowerStat)

        #expect(response.returnCode == .ok)
        #expect(response.data == ["1"])
        // Default-protocol wire format must be `1\nRPRT 0\n`
        // (see v1.2.9 RPRT trailer fix, issue #15).
        #expect(response.formatDefault() == "1\nRPRT 0\n")
    }

    /// `\get_powerstat` on an IC-9700 that times out on the
    /// frequency-read probe must return `"0"` — the radio is
    /// off / in standby. Matches Hamlib `icom_get_powerstat`
    /// (`icom.c:8285`): "Assume power is OFF if get_freq fails".
    @Test func getPowerStatReturnsZeroOnTimeout() async throws {
        let (_, handler, mock) = try await makeIC9700Handler()
        await mock.setShouldThrowOnRead(true)

        let response = await handler.handle(.getPowerStat)

        #expect(response.returnCode == .ok)
        #expect(response.data == ["0"])
        #expect(response.formatDefault() == "0\nRPRT 0\n")
    }

    // MARK: - set_powerstat

    /// `\set_powerstat 0` sends CI-V command `0x18 0x00`
    /// (power off).  IC-9700 powers off immediately without ACK
    /// — the read is allowed to time out; the handler returns OK.
    @Test func setPowerStatOffSendsPowerOffFrame() async throws {
        let (_, handler, mock) = try await makeIC9700Handler()

        let response = await handler.handle(.setPowerStat(on: false))

        #expect(response.returnCode == .ok)
        let writes = await mock.recordedWrites
        // Must include the power-off frame: FE FE A2 E0 18 00 FD
        #expect(writes.contains(Data([0xFE, 0xFE, 0xA2, 0xE0, 0x18, 0x00, 0xFD])))
    }

    /// `\set_powerstat 1` sends CI-V command `0x18 0x01`
    /// (power on).  IC-9700 requires an extended wake-up preamble
    /// on real hardware — this test only asserts we emit the
    /// standard frame after which the radio ACKs.
    @Test func setPowerStatOnSendsPowerOnFrame() async throws {
        let (_, handler, mock) = try await makeIC9700Handler()
        // Provide an explicit ACK for the power-on frame so
        // receiveFrame returns cleanly (default-response ACK is
        // also fine, but making it explicit documents intent).
        await mock.setResponse(
            for: Data([0xFE, 0xFE, 0xA2, 0xE0, 0x18, 0x01, 0xFD]),
            response: Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
        )

        let response = await handler.handle(.setPowerStat(on: true))

        #expect(response.returnCode == .ok)
        let writes = await mock.recordedWrites
        #expect(writes.contains(Data([0xFE, 0xFE, 0xA2, 0xE0, 0x18, 0x01, 0xFD])))
    }

    // MARK: - Parser coverage

    /// Confirm the parser routes both compact and long forms
    /// of the powerstat command to the correct enum cases.
    @Test func parserRoutesGetPowerStat() throws {
        let parser = RigctldCommandParser()
        let cmd = try parser.parse("\\get_powerstat")
        if case .getPowerStat = cmd {
            // ok
        } else {
            Issue.record("Expected .getPowerStat, got \(cmd)")
        }
    }

    @Test func parserRoutesSetPowerStat() throws {
        let parser = RigctldCommandParser()
        let cmd = try parser.parse("\\set_powerstat 1")
        if case .setPowerStat(let on) = cmd {
            #expect(on == true)
        } else {
            Issue.record("Expected .setPowerStat(true), got \(cmd)")
        }
    }
}
