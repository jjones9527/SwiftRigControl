import Foundation
import Testing
@testable import RigControl

/// Wire tests for the FT-100 (``YaesuFT100CAT``) and the FT-920
/// (``YaesuFT1000MPCAT`` with `.ft920`), v1.2.18.
///
/// Pre-v1.2.18 both radios were wired to ``YaesuPortableCAT``, the FT-817
/// layout (mode byte first, opcode `0x07`; PTT opcodes `0x08` / `0x88`)
/// at 38400 baud. Hamlib `rigs/yaesu/ft100.c` and `ft920.c` use the
/// legacy layout (parameters in bytes 0-3, opcode in byte 4, LE BCD
/// frequency) at 4800 baud only.
@Suite struct YaesuFT100FT920Tests {

    private func makeFT100() async throws -> (MockTransport, YaesuFT100CAT) {
        let transport = MockTransport()
        let proto = YaesuFT100CAT(transport: transport, capabilities: .full)
        try await proto.connect()
        await transport.reset()
        return (transport, proto)
    }

    private func makeFT920() async throws -> (MockTransport, YaesuFT1000MPCAT) {
        let transport = MockTransport()
        let proto = YaesuFT1000MPCAT(transport: transport, capabilities: .full, family: .ft920)
        try await proto.connect()
        await transport.reset()
        return (transport, proto)
    }

    /// A 32-byte FT-100 status block (`ft100.c:94-111`) with the given
    /// frequency bytes (1-4) and mode byte (5).
    private static func ft100Status(freq: [UInt8], mode: UInt8) -> Data {
        var block = [UInt8](repeating: 0, count: YaesuFT100CAT.statusLength)
        block.replaceSubrange(1...4, with: freq)
        block[5] = mode
        return Data(block)
    }

    // MARK: - FT-100 writes

    @Test func ft100SetFrequencyUsesLittleEndianBCDAndOpcode0A() async throws {
        // ft100.c:594-611 — to_bcd(freq / 10, 8), opcode 0x0A.
        let (transport, proto) = try await makeFT100()
        try await proto.setFrequency(14_230_000, vfo: .a)
        #expect(await transport.recordedWrites == [Data([0x00, 0x30, 0x42, 0x01, 0x0A])])
    }

    @Test(arguments: [
        (Mode.lsb, UInt8(0x00)), (Mode.usb, UInt8(0x01)), (Mode.cw, UInt8(0x02)),
        (Mode.cwR, UInt8(0x03)), (Mode.am, UInt8(0x04)), (Mode.dataUSB, UInt8(0x05)),
        (Mode.fm, UInt8(0x06)), (Mode.wfm, UInt8(0x07)),
    ])
    func ft100ModeTable(mode: Mode, selector: UInt8) async throws {
        // ft100.c:215-222 — FM is 0x06 and DIG is 0x05, unlike FT-1000MP.
        let (transport, proto) = try await makeFT100()
        try await proto.setMode(mode, vfo: .a)
        #expect(await transport.recordedWrites == [Data([0x00, 0x00, 0x00, selector, 0x0C])])
    }

    @Test func ft100RejectsDataLSB() async throws {
        // Hamlib maps only PKT-USB to the FT-100's DIG mode.
        let (_, proto) = try await makeFT100()
        await #expect(throws: RigError.self) {
            try await proto.setMode(.dataLSB, vfo: .a)
        }
    }

    @Test func ft100PTTFrames() async throws {
        // ft100.c:210-211.
        let (transport, proto) = try await makeFT100()
        try await proto.setPTT(true)
        try await proto.setPTT(false)
        #expect(await transport.recordedWrites == [
            Data([0x00, 0x00, 0x00, 0x01, 0x0F]),
            Data([0x00, 0x00, 0x00, 0x00, 0x0F]),
        ])
    }

    @Test func ft100WritesAreNotAcknowledged() async throws {
        // ft100_send_priv_cmd only writes (ft100.c:524-532); a read
        // would block until timeout on real hardware.
        let (transport, proto) = try await makeFT100()
        await transport.setShouldThrowOnRead(true)
        try await proto.setFrequency(7_074_000, vfo: .a)
        try await proto.setMode(.usb, vfo: .a)
        try await proto.setPTT(true)
    }

    // MARK: - FT-100 reads

    @Test func ft100GetFrequencyDecodesBinaryTimesOnePointTwoFive() async throws {
        // ft100.c:614-658 — bytes 1-4 big-endian binary, × 1.25.
        // 14_074_000 Hz / 1.25 = 11_259_200 = 0x00ABCD40.
        let (transport, proto) = try await makeFT100()
        await transport.setResponse(
            for: Data([0x00, 0x00, 0x00, 0x00, 0x10]),
            response: Self.ft100Status(freq: [0x00, 0xAB, 0xCD, 0x40], mode: 0x01)
        )
        #expect(try await proto.getFrequency(vfo: .a) == 14_074_000)
    }

    @Test func ft100GetModeReadsLowNibble() async throws {
        // ft100.c:758-800 — high nibble is the filter, low nibble the mode.
        let (transport, proto) = try await makeFT100()
        await transport.setResponse(
            for: Data([0x00, 0x00, 0x00, 0x00, 0x10]),
            response: Self.ft100Status(freq: [0, 0, 0, 0], mode: 0x15)
        )
        #expect(try await proto.getMode(vfo: .a) == .dataUSB)
    }

    @Test func ft100GetPTTReadsFlagsBit7() async throws {
        // ft100.c:953-972 — flags byte 0, bit 7.
        let (transport, proto) = try await makeFT100()
        await transport.setResponse(
            for: Data([0x00, 0x00, 0x00, 0x01, 0xFA]),
            response: Data([0x80, 0, 0, 0, 0, 0, 0, 0])
        )
        #expect(try await proto.getPTT() == true)
    }

    // MARK: - FT-920

    @Test(arguments: [
        (Mode.lsb, UInt8(0x00)), (Mode.usb, UInt8(0x01)), (Mode.cw, UInt8(0x02)),
        (Mode.am, UInt8(0x04)), (Mode.fm, UInt8(0x06)), (Mode.rtty, UInt8(0x08)),
        (Mode.dataLSB, UInt8(0x08)), (Mode.dataUSB, UInt8(0x0A)), (Mode.dataFM, UInt8(0x0B)),
    ])
    func ft920ModeTable(mode: Mode, selector: UInt8) async throws {
        // ft920.c:109-119 and ft920_set_mode (ft920.c:975-1009).
        let (transport, proto) = try await makeFT920()
        try await proto.setMode(mode, vfo: .a)
        #expect(await transport.recordedWrites == [Data([0x00, 0x00, 0x00, selector, 0x0C])])
    }

    @Test func ft920VFOBModeSetsHighBit() async throws {
        // ft920.c:122-132 — VFO B forms are 0x80 | base.
        let (transport, proto) = try await makeFT920()
        try await proto.setMode(.dataUSB, vfo: .b)
        #expect(await transport.recordedWrites == [Data([0x00, 0x00, 0x00, 0x8A, 0x0C])])
    }

    @Test func ft920DataUSBDiffersFromFT1000MP() throws {
        // FT-1000MP has no DATA-USB and falls back to 0x0A for both;
        // on the FT-920 DATA-L is 0x08 and DATA-U is 0x0A.
        #expect(try YaesuFT1000MPCAT.modeSelector(for: .dataLSB, vfo: .a, family: .ft920) == 0x08)
        #expect(try YaesuFT1000MPCAT.modeSelector(for: .dataLSB, vfo: .a, family: .ft1000mp) == 0x0A)
    }

    // MARK: - Catalog wiring

    @Test func catalogUsesLegacyAdaptersAt4800Baud() async throws {
        let ft100 = RadioDefinition.Yaesu.ft100
        #expect(ft100.defaultBaudRate == 4800)
        #expect(ft100.createProtocol(transport: MockTransport()) is YaesuFT100CAT)

        let ft920 = RadioDefinition.Yaesu.ft920
        #expect(ft920.defaultBaudRate == 4800)
        let proto = try #require(ft920.createProtocol(transport: MockTransport()) as? YaesuFT1000MPCAT)
        #expect(await proto.family == .ft920)
    }

    @Test func advertisedModesAreSettable() throws {
        for mode in RadioCapabilitiesDatabase.Yaesu.ft100.supportedModes {
            #expect((try? YaesuFT100CAT.modeSelector(for: mode)) != nil, "FT-100 \(mode.rawValue)")
        }
        for mode in RadioCapabilitiesDatabase.Yaesu.ft920.supportedModes {
            #expect((try? YaesuFT1000MPCAT.ft920ModeBase(for: mode)) != nil, "FT-920 \(mode.rawValue)")
        }
    }
}
