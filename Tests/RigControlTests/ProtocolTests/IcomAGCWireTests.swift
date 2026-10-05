import Foundation
import Testing
@testable import RigControl

/// Wire-byte tests for the unified Icom `setAGC` / `getAGC`.
///
/// Icom's `0x16 0x12` AGC byte comes from each radio's Hamlib
/// `agc_levels` table (`.agc_levels_present = 1`), e.g.
/// `ic7600.c:161-167`, `ic7300.c:454-460`, `ic7410.c:102+`.
/// Pre-v1.2.17 we sent Hamlib's `RIG_AGC_*` enum values instead
/// (`.fast` → `0x02` = MID on the radio, `.medium` → `0x05` = NAK),
/// and IC-7300 / IC-7610 / IC-705 / IC-7851 threw because they were
/// routed into IC-7600- and IC-7100-only helpers.
@Suite struct IcomAGCWireTests {

    private func make(
        _ model: IcomRadioModel,
        address: UInt8,
        commandSet: any CIVCommandSet,
        capabilities: RigCapabilities
    ) -> (MockTransport, IcomCIVProtocol) {
        let mock = MockTransport()
        let proto = IcomCIVProtocol(
            transport: mock,
            civAddress: address,
            radioModel: model,
            commandSet: commandSet,
            capabilities: capabilities
        )
        return (mock, proto)
    }

    private func makeIC9700() -> (MockTransport, IcomCIVProtocol) {
        make(.ic9700, address: 0xA2, commandSet: IC9700CommandSet(),
             capabilities: RadioCapabilitiesDatabase.Icom.ic9700)
    }

    private func makeIC7300() -> (MockTransport, IcomCIVProtocol) {
        make(.ic7300, address: 0x94, commandSet: StandardIcomCommandSet.ic7300,
             capabilities: RadioCapabilitiesDatabase.Icom.ic7300)
    }

    // MARK: - Set

    @Test(arguments: [
        (AGCSpeed.fast, UInt8(0x01)),
        (AGCSpeed.medium, UInt8(0x02)),
        (AGCSpeed.slow, UInt8(0x03)),
        (AGCSpeed.off, UInt8(0x00)),
    ])
    func ic9700SetAGCEmitsHamlibTableByte(speed: AGCSpeed, expected: UInt8) async throws {
        let (mock, proto) = makeIC9700()
        try await proto.connect()
        try await proto.setAGC(speed)

        let frame = await mock.recordedWrites.last!
        // FE FE A2 E0 16 12 <code> FD
        #expect(frame == Data([0xFE, 0xFE, 0xA2, 0xE0, 0x16, 0x12, expected, 0xFD]))
    }

    @Test func ic7300SetAGCNoLongerThrows() async throws {
        // Pre-v1.2.17 this dispatched to setAGCIC7600, which guards
        // radioModel == .ic7600 and threw unsupportedOperation.
        let (mock, proto) = makeIC7300()
        try await proto.connect()
        try await proto.setAGC(.fast)

        let frame = await mock.recordedWrites.last!
        #expect(frame == Data([0xFE, 0xFE, 0x94, 0xE0, 0x16, 0x12, 0x01, 0xFD]))
    }

    @Test func ic7600RejectsAGCOff() async throws {
        // ic7600.c:161-167 has no RIG_AGC_OFF entry.
        let (_, proto) = make(.ic7600, address: 0x7A,
                              commandSet: StandardIcomCommandSet.ic7600,
                              capabilities: RadioCapabilitiesDatabase.Icom.ic7600)
        try await proto.connect()
        await #expect(throws: RigError.self) {
            try await proto.setAGC(.off)
        }
    }

    // MARK: - Get

    @Test func ic7300GetAGCDecodesFast() async throws {
        let (mock, proto) = makeIC7300()
        try await proto.connect()
        await mock.setResponse(
            for: Data([0xFE, 0xFE, 0x94, 0xE0, 0x16, 0x12, 0xFD]),
            response: Data([0xFE, 0xFE, 0xE0, 0x94, 0x16, 0x12, 0x01, 0xFD])
        )
        #expect(try await proto.getAGC() == .fast)
    }

    @Test func ic9700GetAGCDecodesMedium() async throws {
        let (mock, proto) = makeIC9700()
        try await proto.connect()
        await mock.setResponse(
            for: Data([0xFE, 0xFE, 0xA2, 0xE0, 0x16, 0x12, 0xFD]),
            response: Data([0xFE, 0xFE, 0xE0, 0xA2, 0x16, 0x12, 0x02, 0xFD])
        )
        #expect(try await proto.getAGC() == .medium)
    }

    // MARK: - Tables

    @Test func ic7410TableIsReversed() throws {
        // ic7410.c:102+ — SLOW=1, MID=2, FAST=3.
        let table = try #require(IcomCIVProtocol.agcTable(for: .ic7410))
        #expect(table.first { $0.speed == .slow }?.code == 0x01)
        #expect(table.first { $0.speed == .fast }?.code == 0x03)
    }

    @Test func ic7200TableHasNoMedium() throws {
        // ic7200.c:106+ — OFF=0, FAST=1, SLOW=2.
        let table = try #require(IcomCIVProtocol.agcTable(for: .ic7200))
        #expect(table.first { $0.speed == .medium } == nil)
        #expect(table.first { $0.speed == .slow }?.code == 0x02)
    }

    @Test func noTableEverEmitsRigAGCEnumValues() {
        // 0x05 (RIG_AGC_MEDIUM) and 0x06 (RIG_AGC_AUTO) are Hamlib
        // API enum values, never Icom wire bytes for these models.
        for model in IcomRadioModel.allCases {
            guard let table = IcomCIVProtocol.agcTable(for: model) else { continue }
            for entry in table {
                #expect(entry.code <= 0x03, "\(model.rawValue) \(entry.speed) → 0x\(String(entry.code, radix: 16))")
            }
        }
    }
}
