import Foundation
import Testing
@testable import RigControl

/// Parser regression tests pinned to real-hardware captures from
/// the IC-9700 (validated 2026-05-29).
///
/// The byte sequences in each test were taken from the wire using
/// the IC7600Probe debug tool against a real radio at CI-V address
/// 0xA2. Keep them byte-for-byte; if the parser logic changes,
/// these tests verify the IC-9700 is still parsed correctly.
@Suite struct IC9700ResponseParsingTests {

    private func makeIC9700() -> (MockTransport, IcomCIVProtocol) {
        let mock = MockTransport()
        let proto = IcomCIVProtocol(
            transport: mock,
            civAddress: 0xA2,
            radioModel: .ic9700,
            commandSet: IC9700CommandSet(),
            capabilities: RadioCapabilitiesDatabase.Icom.ic9700
        )
        return (mock, proto)
    }

    // MARK: - 0x16 sub-command read shape

    @Test func satelliteModeReplyParsesWithOneByteCommand() throws {
        // Real radio reply, satmode ON:
        //   FE FE E0 A2 16 5A 01 FD
        // `CIVFrame.parse` does NOT treat 0x16 as a "has sub-command"
        // prefix (only 0x14/0x15/0x1C are in that list), so the split
        // is `command=[0x16], data=[0x5A, value]`. `getSatelliteModeIC9700`
        // now validates against this shape.
        let raw = Data([0xFE, 0xFE, 0xE0, 0xA2, 0x16, 0x5A, 0x01, 0xFD])
        let frame = try CIVFrame.parse(raw)
        #expect(frame.command.count == 1)
        #expect(frame.command[0] == 0x16)
        #expect(frame.data.count == 2)
        #expect(frame.data[0] == 0x5A)
        #expect(frame.data[1] == 0x01)      // satmode ON
    }

    @Test func digitalSquelchReplyParsesWithOneByteCommand() throws {
        // Real radio reply, DSQL OFF:
        //   FE FE E0 A2 16 5B 00 FD
        let raw = Data([0xFE, 0xFE, 0xE0, 0xA2, 0x16, 0x5B, 0x00, 0xFD])
        let frame = try CIVFrame.parse(raw)
        #expect(frame.command.count == 1)
        #expect(frame.command[0] == 0x16)
        #expect(frame.data.count == 2)
        #expect(frame.data[0] == 0x5B)
        #expect(frame.data[1] == 0x00)      // DSQL OFF
    }

    @Test func dualwatchReplyParsesWithOneByteCommand() throws {
        // Real radio reply, dualwatch OFF:
        //   FE FE E0 A2 16 59 00 FD
        let raw = Data([0xFE, 0xFE, 0xE0, 0xA2, 0x16, 0x59, 0x00, 0xFD])
        let frame = try CIVFrame.parse(raw)
        #expect(frame.command.count == 1)
        #expect(frame.command[0] == 0x16)
        #expect(frame.data.count == 2)
        #expect(frame.data[0] == 0x59)
        #expect(frame.data[1] == 0x00)
    }

    // MARK: - Dualwatch wire-bytes regression

    @Test func dualwatchOnSendsCorrectWireBytes() async throws {
        let (mock, proto) = makeIC9700()
        try await proto.connect()

        // Pre-fix the IC-9700 used `0x07 0xC2/0xC3` (the HF Icom
        // form), which the radio NAKs. Hamlib `icom_set_func`
        // (icom.c:7263–7269) confirms the IC-9100/9700/ID-5100
        // family uses `C_CTL_FUNC (0x16) + S_MEM_DUALMODE (0x59)`
        // with a single value byte (0x01=ON, 0x00=OFF). Pin the
        // bytes so a regression brings this test down.
        try await proto.setDualwatchIC9700(true)

        let writes = await mock.recordedWrites
        let lastFrame = writes.last!
        #expect(lastFrame[4] == 0x16)   // C_CTL_FUNC, NOT 0x07
        #expect(lastFrame[5] == 0x59)   // S_MEM_DUALMODE, NOT 0xC3
        #expect(lastFrame[6] == 0x01)   // ON
    }

    @Test func dualwatchOffSendsCorrectWireBytes() async throws {
        let (mock, proto) = makeIC9700()
        try await proto.connect()
        try await proto.setDualwatchIC9700(false)

        let writes = await mock.recordedWrites
        let lastFrame = writes.last!
        #expect(lastFrame[4] == 0x16)
        #expect(lastFrame[5] == 0x59)
        #expect(lastFrame[6] == 0x00)   // OFF
    }
}
