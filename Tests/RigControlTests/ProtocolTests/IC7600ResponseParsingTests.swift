import Foundation
import Testing
@testable import RigControl

/// Parser regression tests pinned to real-hardware captures from
/// the IC-7600 (validated 2026-05-29).
///
/// The bytes in each script were taken from the wire using the
/// `IC7600Probe` debug tool against a real radio at CI-V address
/// 0x7A. Keep them byte-for-byte; if the parser logic changes,
/// these tests verify the IC-7600 is still parsed correctly.
@Suite struct IC7600ResponseParsingTests {

    private func makeIC7600() -> (MockTransport, IcomCIVProtocol) {
        let mock = MockTransport()
        let proto = IcomCIVProtocol(
            transport: mock,
            civAddress: 0x7A,
            radioModel: .ic7600,
            commandSet: StandardIcomCommandSet.ic7600,
            capabilities: RadioCapabilitiesDatabase.Icom.ic7600
        )
        return (mock, proto)
    }

    @Test func squelchConditionReplyParsesWithTwoByteCommand() throws {
        // Real radio reply at 14 MHz, squelch open:
        //   FE FE E0 7A 15 01 01 FD
        // CIVFrame.parse treats 0x15 as a "has sub-command" prefix
        // (0x15 is in the parser's hasSubCommand list along with
        // 0x14 and 0x1C), so the split is:
        //   command = [0x15, 0x01]  (read-level + sub=squelch)
        //   data    = [0x01]        (value byte)
        // Hamlib `icom_get_dcd` (icom.c:5531) confirms 1 value byte
        // where 0x01 = OPEN, 0x00 = CLOSED. The `getSquelchConditionIC7600`
        // branch B (command.count >= 2 && data.count >= 1) is what
        // fires for this radio. Pre-fix required `data.count >= 2`
        // and rejected the captured 1-byte data section.
        let raw = Data([0xFE, 0xFE, 0xE0, 0x7A, 0x15, 0x01, 0x01, 0xFD])
        let frame = try CIVFrame.parse(raw)
        #expect(frame.command.count == 2)
        #expect(frame.command[0] == 0x15)
        #expect(frame.command[1] == 0x01)
        #expect(frame.data.count == 1)
        #expect(frame.data[0] == 0x01)      // OPEN
    }

    @Test func squelchConditionParserAcceptsClosedShape() throws {
        // Same shape, value 0 = CLOSED.
        let raw = Data([0xFE, 0xFE, 0xE0, 0x7A, 0x15, 0x01, 0x00, 0xFD])
        let frame = try CIVFrame.parse(raw)
        #expect(frame.command.count == 2)
        #expect(frame.command[0] == 0x15)
        #expect(frame.command[1] == 0x01)
        #expect(frame.data.count == 1)
        #expect(frame.data[0] == 0x00)      // CLOSED
    }

    @Test func agcTimeConstantReplyParsesWithOneByteCommand() throws {
        // Real radio reply (2026-05-29) after setting AGC TC to 5:
        //   FE FE E0 7A 1A 04 05 FD
        // CIVFrame.parse does NOT treat 0x1A as a "has sub-command"
        // prefix (only 0x14/0x15/0x1C are in that list), so the
        // split is:
        //   command = [0x1A]
        //   data    = [0x04, 0x05]  (sub-cmd echo + value)
        // This is the opposite layout from squelch above, and the
        // reason `getAGCTimeConstantIC7600` validates against a
        // 1-byte command with the sub-cmd in data[0].
        let raw = Data([0xFE, 0xFE, 0xE0, 0x7A, 0x1A, 0x04, 0x05, 0xFD])
        let frame = try CIVFrame.parse(raw)
        #expect(frame.command.count == 1)
        #expect(frame.command[0] == 0x1A)
        #expect(frame.data.count == 2)
        #expect(frame.data[0] == 0x04)      // sub-cmd echo
        #expect(frame.data[1] == 0x05)      // AGC TC value
    }

    @Test func bandEdgeIsExplicitlyUnsupportedPendingManualCrossCheck() async throws {
        let (_, proto) = makeIC7600()
        try await proto.connect()

        // getBandEdgeIC7600 throws .unsupportedOperation until the
        // multi-segment response format is decoded against the
        // IC-7600 CI-V manual. Real-hardware capture (2026-05-29)
        // doesn't match the "5+5 BCD" layout the previous parser
        // assumed and would always throw .invalidResponse anyway.
        await #expect(throws: RigError.self) {
            _ = try await proto.getBandEdgeIC7600()
        }
    }
}
