import Foundation
import Testing
@testable import RigControl

/// IC-F8101 wire tests (v1.2.19).
///
/// The IC-F8101 takes frequency, mode and PTT through `0x1A` sub-commands
/// (Hamlib `rigs/icom/icf8101.c`): `1A 35` frequency, `1A 36` mode set,
/// `1A 34` mode read, `1A 37` PTT. Before v1.2.19 it used the standard
/// `0x05` / `0x06` / `0x1C` commands.
@Suite struct ICF8101CommandSetTests {

    private func make() async throws -> (MockTransport, IcomCIVProtocol) {
        let mock = MockTransport()
        let proto = try #require(
            RadioDefinition.Icom.icF8101().createProtocol(transport: mock) as? IcomCIVProtocol
        )
        try await proto.connect()
        await mock.reset()
        return (mock, proto)
    }

    private static func cmd(_ body: [UInt8]) -> Data {
        Data([0xFE, 0xFE, 0x8A, 0xE0] + body + [0xFD])
    }

    private static func reply(_ body: [UInt8]) -> Data {
        Data([0xFE, 0xFE, 0xE0, 0x8A] + body + [0xFD])
    }

    @Test func setFrequencyUses1A35() async throws {
        // icf8101_set_freq, icf8101.c:40-63.
        let (mock, proto) = try await make()
        try await proto.setFrequency(14_074_000, vfo: .a)
        #expect(await mock.recordedWrites.last == Self.cmd([0x1A, 0x35, 0x00, 0x40, 0x07, 0x14, 0x00]))
    }

    @Test(arguments: [
        (Mode.lsb, UInt8(0x00)), (Mode.usb, UInt8(0x01)), (Mode.am, UInt8(0x02)),
        (Mode.cw, UInt8(0x03)), (Mode.rtty, UInt8(0x04)),
        (Mode.dataLSB, UInt8(0x18)), (Mode.dataUSB, UInt8(0x19)),
    ])
    func setModeUses1A36(mode: Mode, code: UInt8) async throws {
        // icf8101_set_mode, icf8101.c:65-107. No 0x06, no 0x1A 0x06.
        let (mock, proto) = try await make()
        try await proto.setMode(mode, vfo: .a)
        let writes = await mock.recordedWrites
        #expect(writes.last == Self.cmd([0x1A, 0x36, 0x00, code]))
        #expect(!writes.contains { $0.count > 4 && $0[4] == 0x06 })
        #expect(!writes.contains(Self.cmd([0x1A, 0x06, 0x00, 0x00])))
    }

    @Test(arguments: [
        (UInt8(0x01), Mode.usb), (UInt8(0x03), Mode.cw),
        (UInt8(0x18), Mode.dataLSB), (UInt8(0x19), Mode.dataUSB),
        (UInt8(0x21), Mode.dataUSB), (UInt8(0x22), Mode.dataLSB),
    ])
    func getModeReads1A34(code: UInt8, expected: Mode) async throws {
        // icf8101_get_mode, icf8101.c:109-158: reply [34, 00, mode].
        let (mock, proto) = try await make()
        await mock.setResponse(for: Self.cmd([0x1A, 0x34]), response: Self.reply([0x1A, 0x34, 0x00, code]))
        #expect(try await proto.getMode(vfo: .a) == expected)
    }

    @Test func pttUses1A37() async throws {
        // icf8101_set_ptt / get_ptt, icf8101.c:327-412.
        let (mock, proto) = try await make()
        try await proto.setPTT(true)
        try await proto.setPTT(false)
        let writes = await mock.recordedWrites
        #expect(writes == [Self.cmd([0x1A, 0x37, 0x00, 0x01]), Self.cmd([0x1A, 0x37, 0x00, 0x00])])

        await mock.setResponse(for: Self.cmd([0x1A, 0x37]), response: Self.reply([0x1A, 0x37, 0x00, 0x02]))
        #expect(try await proto.getPTT() == true)   // 2 = data-port PTT
        await mock.setResponse(for: Self.cmd([0x1A, 0x37]), response: Self.reply([0x1A, 0x37, 0x00, 0x00]))
        #expect(try await proto.getPTT() == false)
    }

    @Test func advertisedModesAreSettable() async throws {
        for mode in RadioCapabilitiesDatabase.Icom.icF8101.supportedModes {
            let (_, proto) = try await make()
            try await proto.setMode(mode, vfo: .a)
        }
    }
}
