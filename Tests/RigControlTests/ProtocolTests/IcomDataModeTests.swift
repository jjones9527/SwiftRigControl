import Foundation
import Testing
@testable import RigControl

/// Protocol-level tests for Icom DATA-USB / DATA-LSB / DATA-FM
/// mode setting. The IC-7600 (and every other non-targetable
/// modern Icom) needs a two-frame sequence: the normal mode set
/// followed by `0x1A 0x06 [data_flag, filter]` to flip the DATA
/// sub-mode bit. Targetable radios (IC-7300, IC-7610, IC-7700,
/// IC-7800, IC-7851) carry the data flag in the same `0x26`
/// frame so they don't need the follow-up.
///
/// Cross-checked against Hamlib `icom_set_mode`
/// (rigs/icom/icom.c:2494) for each radio family.
@Suite struct IcomDataModeTests {

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

    private func makeIC7300() -> (MockTransport, IcomCIVProtocol) {
        let mock = MockTransport()
        let proto = IcomCIVProtocol(
            transport: mock,
            civAddress: 0x94,
            radioModel: .ic7300,
            commandSet: StandardIcomCommandSet.ic7300,
            capabilities: RadioCapabilitiesDatabase.Icom.ic7300
        )
        return (mock, proto)
    }

    // MARK: - IC-7600 (non-targetable, needs 0x1A 0x06 follow-up)

    @Test func ic7600DataUSBSendsBaseUSBPlusDataModeSubcommand() async throws {
        let (mock, proto) = makeIC7600()
        try await proto.connect()

        // IC-7600 requires VFO selection (Main = 0xD0). We
        // intentionally make the mock ACK every write so we can
        // assert on the recorded wire bytes.
        try await proto.setMode(.dataUSB, vfo: .a)

        let writes = await mock.recordedWrites

        // Expected sequence (per Hamlib `icom_set_mode` for
        // IC-7600):
        //   1. VFO select  (since requiresVFOSelection=true)
        //   2. 0x06 [USB, FIL1]   — set base mode to USB
        //   3. 0x1A 0x06 [0x01, FIL1] — flip DATA sub-mode bit on
        //
        // The bug we're guarding against: previously the IC-7600
        // sent `0x06 [USB, 0x00]` (filter=0x00) and stopped.
        // That left the radio in plain USB, not DATA-USB.
        #expect(writes.count >= 3, "Expected at least VFO + base mode + data flag")

        let baseMode = writes[writes.count - 2]
        let dataFlag = writes[writes.count - 1]

        // Base mode: ...06 01 01 FD (USB, FIL1)
        #expect(baseMode[4] == 0x06)
        #expect(baseMode[5] == 0x01)       // USB
        #expect(baseMode[6] == 0x01)       // FIL1 — NOT 0x00

        // Data-mode subcommand: ...1A 06 01 01 FD (data=on, FIL1)
        #expect(dataFlag[4] == 0x1A)
        #expect(dataFlag[5] == 0x06)
        #expect(dataFlag[6] == 0x01)       // data flag ON
    }

    @Test func ic7600ExitDataModeSendsDataFlagOff() async throws {
        let (mock, proto) = makeIC7600()
        try await proto.connect()

        // Going back to plain USB after DATA-USB must clear the
        // DATA flag — otherwise the radio stays in DATA sub-mode.
        try await proto.setMode(.usb, vfo: .a)

        let writes = await mock.recordedWrites
        #expect(writes.count >= 3)
        let dataFlag = writes[writes.count - 1]
        #expect(dataFlag[4] == 0x1A)
        #expect(dataFlag[5] == 0x06)
        #expect(dataFlag[6] == 0x00)       // data flag OFF
    }

    @Test func ic7600DataLSBUsesLSBBaseMode() async throws {
        let (mock, proto) = makeIC7600()
        try await proto.connect()
        try await proto.setMode(.dataLSB, vfo: .a)

        let writes = await mock.recordedWrites
        let baseMode = writes[writes.count - 2]
        let dataFlag = writes[writes.count - 1]
        #expect(baseMode[5] == 0x00)       // LSB
        #expect(dataFlag[6] == 0x01)       // data on
    }

    // MARK: - IC-7300 (targetable, single-frame 0x26)

    @Test func ic7300DataUSBUses0x26FrameNoFollowUp() async throws {
        let (mock, proto) = makeIC7300()
        try await proto.connect()
        try await proto.setMode(.dataUSB, vfo: .a)

        let writes = await mock.recordedWrites

        // Targetable radios carry the data flag inline in the
        // 0x26 frame — no 0x1A 0x06 follow-up. Check the last
        // frame is 0x26 [USB, 0x01, FIL1] and that no 0x1A 0x06
        // appears in the writes.
        let last = writes.last!
        #expect(last[4] == 0x26)
        #expect(last[5] == 0x01)           // USB
        #expect(last[6] == 0x01)           // data flag ON
        #expect(last[7] == 0x01)           // FIL1

        for frame in writes {
            // No frame should be a 0x1A 0x06 follow-up.
            let isDataModeFollowUp = frame.count >= 6 && frame[4] == 0x1A && frame[5] == 0x06
            #expect(!isDataModeFollowUp,
                    "Targetable radio should not send 0x1A 0x06 follow-up")
        }
    }
}
