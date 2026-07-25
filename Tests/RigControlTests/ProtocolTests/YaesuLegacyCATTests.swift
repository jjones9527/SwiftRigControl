import Foundation
import Testing
@testable import RigControl

/// Byte-level protocol tests for the pre-newcat Yaesu HF flagships:
/// ``YaesuFT1000MPCAT`` and ``YaesuFT847CAT``.
///
/// Every fixture is derived from Hamlib `rigs/yaesu/ft1000mp.c` and
/// `rigs/yaesu/ft847.c`. Fire-and-forget writes for both families —
/// no ACK expected after set commands.
@Suite struct YaesuLegacyCATTests {

    // MARK: - FT-1000MP setup

    private func makeFT1000MP() async throws -> (MockTransport, YaesuFT1000MPCAT) {
        let transport = MockTransport()
        let proto = YaesuFT1000MPCAT(transport: transport, capabilities: .full)
        try await proto.connect()
        return (transport, proto)
    }

    // MARK: - FT-1000MP little-endian BCD

    @Test func ft1000mpEncodesLittleEndianBCD() {
        // 14_230_000 Hz / 10 = 1_423_000 units. Digits low-to-high:
        //   0, 0, 0, 3, 2, 4, 1, 0
        // Little-endian BCD packs digit1<<4 | digit0 into each byte:
        //   byte 0: (0<<4) | 0 = 0x00
        //   byte 1: (3<<4) | 0 = 0x30
        //   byte 2: (4<<4) | 2 = 0x42
        //   byte 3: (0<<4) | 1 = 0x01
        let bytes = YaesuBinaryFrame.encodeBCDLittleEndian8(1_423_000)
        #expect(bytes == [0x00, 0x30, 0x42, 0x01])
    }

    @Test func ft1000mpBCDRoundTripsRepresentativeValues() throws {
        for value: UInt64 in [0, 1, 100, 1_000_000, 12_345_678, 99_999_999] {
            let encoded = YaesuBinaryFrame.encodeBCDLittleEndian8(value)
            let decoded = try YaesuBinaryFrame.decodeBCDLittleEndian8(Data(encoded)[0..<4])
            #expect(decoded == value)
        }
    }

    // MARK: - FT-1000MP frequency

    @Test func ft1000mpSetFrequencyVFOAEmitsLittleEndianFrame() async throws {
        // Reference: Hamlib ft1000mp.c set_freq → to_bcd(...) + opcode 0x0A.
        // For 14_230_000 Hz: 00 30 42 01 0A.
        let (transport, proto) = try await makeFT1000MP()

        try await proto.setFrequency(14_230_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes.count == 1)
        #expect(writes[0] == Data([0x00, 0x30, 0x42, 0x01, 0x0A]))
    }

    @Test func ft1000mpSetFrequencyVFOBUsesOpcode8A() async throws {
        // VFO B uses opcode 0x8A per ncmd entry 13.
        let (transport, proto) = try await makeFT1000MP()

        try await proto.setFrequency(14_230_000, vfo: .b)

        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x30, 0x42, 0x01, 0x8A]))
    }

    @Test func ft1000mpFireAndForgetSetFrequencyDoesNotRead() async throws {
        // The FT-1000MP has no ACK read after a set command. If the
        // implementation accidentally reads, this test would hang or
        // fail — the point is that setFrequency returns without
        // consuming a response.
        let (transport, proto) = try await makeFT1000MP()

        try await proto.setFrequency(14_230_000, vfo: .a)

        // No response was set up; the implementation must not have
        // tried to read one.
        let writes = await transport.recordedWrites
        #expect(writes.count == 1)
    }

    // MARK: - FT-1000MP mode

    @Test func ft1000mpSetModeLSBOnVFOA() async throws {
        // Reference: ncmd entry 14 "vfo A mode set LSB":
        //   [0x00, 0x00, 0x00, 0x00, 0x0C].
        let (transport, proto) = try await makeFT1000MP()

        try await proto.setMode(.lsb, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x0C]))
    }

    @Test func ft1000mpSetModeUSBOnVFOA() async throws {
        let (transport, proto) = try await makeFT1000MP()
        try await proto.setMode(.usb, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x01, 0x0C]))
    }

    @Test func ft1000mpSetModeAMOnVFOA() async throws {
        let (transport, proto) = try await makeFT1000MP()
        try await proto.setMode(.am, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x04, 0x0C]))
    }

    @Test func ft1000mpSetModeLSBOnVFOBSetsHighBit() async throws {
        // Reference: ncmd entry 26 "vfo B mode set LSB":
        //   [0x00, 0x00, 0x00, 0x80, 0x0C].
        let (transport, proto) = try await makeFT1000MP()

        try await proto.setMode(.lsb, vfo: .b)

        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x80, 0x0C]))
    }

    @Test func ft1000mpSetModeRTTYOnVFOA() async throws {
        // ncmd entry 22 "vfo A mode set RTTY-LSB":
        //   [0x00, 0x00, 0x00, 0x08, 0x0C].
        let (transport, proto) = try await makeFT1000MP()
        try await proto.setMode(.rtty, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x08, 0x0C]))
    }

    // MARK: - FT-1000MP PTT + VFO

    @Test func ft1000mpSetPTTOn() async throws {
        // ncmd entry 40: [_,_,_,0x01,0x0F].
        let (transport, proto) = try await makeFT1000MP()
        try await proto.setPTT(true)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x01, 0x0F]))
    }

    @Test func ft1000mpSetPTTOff() async throws {
        // ncmd entry 39: [_,_,_,0x00,0x0F].
        let (transport, proto) = try await makeFT1000MP()
        try await proto.setPTT(false)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x0F]))
    }

    @Test func ft1000mpSelectVFOAEmitsExpectedFrame() async throws {
        // ncmd entry 4: [_,_,_,0x00,0x05].
        let (transport, proto) = try await makeFT1000MP()
        try await proto.selectVFO(.a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x05]))
    }

    @Test func ft1000mpSelectVFOB() async throws {
        // ncmd entry 5: [_,_,_,0x01,0x05].
        let (transport, proto) = try await makeFT1000MP()
        try await proto.selectVFO(.b)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x01, 0x05]))
    }

    @Test func ft1000mpGetFrequencyThrowsForNow() async throws {
        // Status-block decode isn't implemented in this release.
        // Explicit throw so downstream apps get a clear signal
        // rather than a silent fallthrough.
        let (_, proto) = try await makeFT1000MP()
        await #expect(throws: RigError.self) {
            _ = try await proto.getFrequency(vfo: .a)
        }
    }

    // MARK: - FT-847 setup

    private func makeFT847(unidirectional: Bool = false)
        async throws -> (MockTransport, YaesuFT847CAT)
    {
        let transport = MockTransport()
        let proto = YaesuFT847CAT(
            transport: transport,
            capabilities: .full,
            isUnidirectional: unidirectional
        )
        try await proto.connect()
        return (transport, proto)
    }

    // MARK: - FT-847 frequency

    @Test func ft847SetFrequencyEmitsBigEndianBCDFrame() async throws {
        // Reference: Hamlib ft847.c set_freq → to_bcd_be + opcode 0x01.
        // For 14_230_000 Hz: 01 42 30 00 01 (same as FT-817 — both
        // are big-endian).
        let (transport, proto) = try await makeFT847()

        try await proto.setFrequency(14_230_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x01, 0x42, 0x30, 0x00, 0x01]))
    }

    @Test func ft847SetFrequencyIsFireAndForget() async throws {
        // Contrast with FT-817 which reads an ACK; FT-847 does not.
        // Not consuming a response is the whole safety win of the
        // dedicated adapter.
        let (transport, proto) = try await makeFT847()
        try await proto.setFrequency(14_230_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes.count == 1)
    }

    // MARK: - FT-847 mode

    @Test func ft847SetModeLSB() async throws {
        // ncmd table entry: [0x00, 0x00, 0x00, 0x00, 0x07].
        let (transport, proto) = try await makeFT847()
        try await proto.setMode(.lsb, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x07]))
    }

    @Test func ft847SetModeUSB() async throws {
        let (transport, proto) = try await makeFT847()
        try await proto.setMode(.usb, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x01, 0x00, 0x00, 0x00, 0x07]))
    }

    @Test func ft847SetModeFMNarrow() async throws {
        let (transport, proto) = try await makeFT847()
        try await proto.setMode(.fmN, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x88, 0x00, 0x00, 0x00, 0x07]))
    }

    // MARK: - FT-847 PTT

    @Test func ft847SetPTTOn() async throws {
        // ncmd: [0x00, 0x00, 0x00, 0x00, 0x08].
        let (transport, proto) = try await makeFT847()
        try await proto.setPTT(true)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x08]))
    }

    @Test func ft847SetPTTOffUsesUnusualP4Byte() async throws {
        // ncmd entry: [0x00, 0x00, 0x00, 0x01, 0x88]. The P4 = 0x01
        // is unusual — it's the only PTT command in the Yaesu binary
        // families that doesn't have all zeros in the parameter bytes.
        let (transport, proto) = try await makeFT847()
        try await proto.setPTT(false)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x01, 0x88]))
    }

    // MARK: - FT-847 satellite mode

    @Test func ft847SatelliteModeEnableEmitsOpcode4E() async throws {
        // ncmd: [0x00, 0x00, 0x00, 0x00, 0x4E] = sat mode on.
        let (transport, proto) = try await makeFT847()
        try await proto.setSatelliteMode(true)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x4E]))
        #expect(await proto.isSatelliteModeEnabled == true)
    }

    @Test func ft847SatelliteModeDisableEmitsOpcode8E() async throws {
        let (transport, proto) = try await makeFT847()
        try await proto.setSatelliteMode(true)
        try await proto.setSatelliteMode(false)
        let writes = await transport.recordedWrites
        #expect(writes.count == 2)
        #expect(writes[1] == Data([0x00, 0x00, 0x00, 0x00, 0x8E]))
        #expect(await proto.isSatelliteModeEnabled == false)
    }

    @Test func ft847SatelliteModeChangesSetFrequencyOpcode() async throws {
        // In sat mode, setFrequency(...vfo: .a) uses opcode 0x11
        // (SAT RX). setFrequency(...vfo: .b) uses 0x21 (SAT TX).
        let (transport, proto) = try await makeFT847()

        try await proto.setSatelliteMode(true)
        try await proto.setFrequency(146_500_000, vfo: .a)
        try await proto.setFrequency(437_000_000, vfo: .b)

        let writes = await transport.recordedWrites
        // Index 0: sat mode on. Index 1: SAT RX at 146.5 MHz.
        // Index 2: SAT TX at 437 MHz.
        // 146_500_000 / 10 = 14_650_000 → big-endian BCD:
        //   digits high-to-low: 1,4,6,5,0,0,0,0 → 0x14 0x65 0x00 0x00
        #expect(writes[1] == Data([0x14, 0x65, 0x00, 0x00, 0x11]))
        // 437_000_000 / 10 = 43_700_000 → 0x43 0x70 0x00 0x00
        #expect(writes[2] == Data([0x43, 0x70, 0x00, 0x00, 0x21]))
    }

    // MARK: - FT-847 unidirectional variant

    @Test func ft847UnidirectionalSetsStillEmitBytes() async throws {
        // FT-847UNI writes go on the wire — the radio just doesn't
        // respond. Only reads are affected.
        let (transport, proto) = try await makeFT847(unidirectional: true)

        try await proto.setFrequency(14_230_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x01, 0x42, 0x30, 0x00, 0x01]))
    }

    @Test func ft847UnidirectionalGetFrequencyThrows() async throws {
        let (_, proto) = try await makeFT847(unidirectional: true)

        await #expect(throws: RigError.self) {
            _ = try await proto.getFrequency(vfo: .a)
        }
    }

    @Test func ft847UnidirectionalGetPTTThrows() async throws {
        let (_, proto) = try await makeFT847(unidirectional: true)

        await #expect(throws: RigError.self) {
            _ = try await proto.getPTT()
        }
    }

    // MARK: - FT-847 getPTT polarity (v1.2.0 audit fix)

    @Test func ft847GetPTTBit7SetMeansPTTOff() async throws {
        // Per Hamlib ft847_get_ptt() (ft847.c line 1673):
        //   *ptt = (p->tx_status & 0x80) ? RIG_PTT_OFF : RIG_PTT_ON;
        // Prior to v1.2.0 Swift had this inverted. Regression test.
        let (transport, proto) = try await makeFT847()

        let query = Data([0x00, 0x00, 0x00, 0x00, 0xF7])
        // 0xFF = bit 7 set = radio idle / RX per Hamlib.
        await transport.setResponse(for: query, response: Data([0xFF]))

        let ptt = try await proto.getPTT()
        #expect(ptt == false)
    }

    @Test func ft847GetPTTBit7ClearMeansPTTOn() async throws {
        let (transport, proto) = try await makeFT847()

        let query = Data([0x00, 0x00, 0x00, 0x00, 0xF7])
        // 0x50 = bit 7 clear = radio TXing per Hamlib.
        await transport.setResponse(for: query, response: Data([0x50]))

        let ptt = try await proto.getPTT()
        #expect(ptt == true)
    }
}
