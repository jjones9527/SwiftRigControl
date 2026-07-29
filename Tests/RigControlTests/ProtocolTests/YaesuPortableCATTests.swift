import Foundation
import Testing
@testable import RigControl

/// Byte-level protocol tests for `YaesuPortableCAT` — the pre-newcat
/// binary CAT that drives the FT-817/818/857/857D/897/897D/100/920
/// family.
///
/// Every fixture in this suite was derived by reading Hamlib
/// `rigs/yaesu/ft817.c`. Hamlib is the reference implementation the
/// FT-817 family was hardware-verified against for decades — matching
/// its bytes is the closest we can get to hardware verification
/// without owning one of the actual radios.
@Suite struct YaesuPortableCATTests {

    // MARK: - Setup

    private func makeProtocol() async throws -> (MockTransport, YaesuPortableCAT) {
        let transport = MockTransport()
        let proto = YaesuPortableCAT(
            transport: transport,
            capabilities: .full
        )
        try await proto.connect()
        return (transport, proto)
    }

    // MARK: - BCD encoding

    @Test func bcdEncodesEightDigitsBigEndian() {
        // 14_230_000 Hz truncated to /10 = 1_423_000 units. Encoded
        // as 8-digit BCD big-endian, that's 4 bytes containing the
        // digits "01423000":
        //   byte 0: 0x01 → digits 0,1
        //   byte 1: 0x42 → digits 4,2
        //   byte 2: 0x30 → digits 3,0
        //   byte 3: 0x00 → digits 0,0
        let bytes = YaesuBinaryFrame.encodeBCDBigEndian8(1_423_000)
        #expect(bytes == [0x01, 0x42, 0x30, 0x00])
    }

    @Test func bcdRoundTripsSmallValues() throws {
        for value: UInt64 in [0, 1, 10, 100, 1_000, 10_000, 100_000,
                                1_000_000, 12_345_678, 99_999_999] {
            let encoded = YaesuBinaryFrame.encodeBCDBigEndian8(value)
            let decoded = try YaesuBinaryFrame.decodeBCDBigEndian8(Data(encoded)[0..<4])
            #expect(decoded == value,
                    "BCD round-trip failed for \(value): got \(decoded)")
        }
    }

    @Test func bcdDecodeRejectsInvalidNibbles() {
        // 0xAB has high nibble 0xA (>9) — not a decimal digit.
        #expect(throws: RigError.self) {
            _ = try YaesuBinaryFrame.decodeBCDBigEndian8(Data([0xAB, 0x00, 0x00, 0x00])[0..<4])
        }
    }

    // MARK: - Frequency

    @Test func setFrequencyEmitsFiveByteBigEndianBCDFrame() async throws {
        // Reference: Hamlib ft817_set_freq() at line ~1501:
        //   to_bcd_be(data, freq/10, 8);
        //   ft817_send_icmd(rig, FT817_NATIVE_CAT_SET_FREQ, data);
        // Opcode 0x01 goes at byte 4; BCD payload at bytes 0-3.
        //
        // For 14_230_000 Hz → 1_423_000 units → 01 42 30 00 01.
        let (transport, proto) = try await makeProtocol()

        try await proto.setFrequency(14_230_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes.count == 1)
        #expect(writes[0] == Data([0x01, 0x42, 0x30, 0x00, 0x01]))
    }

    @Test func setFrequencyOnSevenPointOneMHz() async throws {
        // 7_100_000 Hz → 710_000 units → 00 71 00 00 01.
        let (transport, proto) = try await makeProtocol()

        try await proto.setFrequency(7_100_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x71, 0x00, 0x00, 0x01]))
    }

    @Test func setFrequencyOnVFOBIgnoresVFO() async throws {
        // The FT-817 family has no per-VFO addressing in the set-freq
        // command — the currently-selected VFO is always the target.
        // We accept `vfo:` for CATProtocol conformance but emit the
        // same bytes regardless.
        let (transport, proto) = try await makeProtocol()

        try await proto.setFrequency(14_230_000, vfo: .b)

        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x01, 0x42, 0x30, 0x00, 0x01]))
    }

    @Test func getFrequencyDecodesFiveByteResponse() async throws {
        // Reference: Hamlib ft817_get_freq() → from_bcd_be(data, 8).
        // Send query 00 00 00 00 03 → response 5 bytes:
        //   bytes 0-3: BCD-BE frequency in 10-Hz units
        //   byte 4:    mode selector
        // For 14_230_000 Hz: response starts 01 42 30 00 xx.
        let (transport, proto) = try await makeProtocol()

        let query = Data([0x00, 0x00, 0x00, 0x00, 0x03])
        let response = Data([0x01, 0x42, 0x30, 0x00, 0x01])   // USB mode
        await transport.setResponse(for: query, response: response)

        let freq = try await proto.getFrequency(vfo: .a)

        #expect(freq == 14_230_000)
    }

    // MARK: - Mode

    @Test func setModeLSBEmitsExpectedFrame() async throws {
        // Reference: ncmd table entry "mode set main LSB" at
        // ft817.c:183 — { 1, { 0x00, 0x00, 0x00, 0x00, 0x07 } }.
        let (transport, proto) = try await makeProtocol()

        try await proto.setMode(.lsb, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x07]))
    }

    @Test func setModeUSBEmitsExpectedFrame() async throws {
        let (transport, proto) = try await makeProtocol()
        try await proto.setMode(.usb, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x01, 0x00, 0x00, 0x00, 0x07]))
    }

    @Test func setModeCWEmitsExpectedFrame() async throws {
        let (transport, proto) = try await makeProtocol()
        try await proto.setMode(.cw, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x02, 0x00, 0x00, 0x00, 0x07]))
    }

    @Test func setModeCWRverseEmitsExpectedFrame() async throws {
        let (transport, proto) = try await makeProtocol()
        try await proto.setMode(.cwR, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x03, 0x00, 0x00, 0x00, 0x07]))
    }

    @Test func setModeAMEmitsExpectedFrame() async throws {
        let (transport, proto) = try await makeProtocol()
        try await proto.setMode(.am, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x04, 0x00, 0x00, 0x00, 0x07]))
    }

    @Test func setModeFMEmitsExpectedFrame() async throws {
        let (transport, proto) = try await makeProtocol()
        try await proto.setMode(.fm, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x08, 0x00, 0x00, 0x00, 0x07]))
    }

    @Test func setModeFMNarrowEmitsExpectedFrame() async throws {
        // ncmd table "mode set main FM-N" at ft817.c:189 —
        // { 1, { 0x88, 0x00, 0x00, 0x00, 0x07 } }.
        let (transport, proto) = try await makeProtocol()
        try await proto.setMode(.fmN, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x88, 0x00, 0x00, 0x00, 0x07]))
    }

    @Test func setModeDataUSBEmitsPKTFrame() async throws {
        // Both DATA-USB and DATA-LSB map to the FT-817's PKT
        // selector (0x0C) — the radio doesn't distinguish upper
        // vs lower on the PKT channel.
        let (transport, proto) = try await makeProtocol()
        try await proto.setMode(.dataUSB, vfo: .a)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x0C, 0x00, 0x00, 0x00, 0x07]))
    }

    @Test func getModeReturnsUSBForSelectorOne() async throws {
        // The 5-byte status response encodes mode in byte 4 (low 7
        // bits). Selector 0x01 = USB per ft817.c:184.
        let (transport, proto) = try await makeProtocol()

        let query = Data([0x00, 0x00, 0x00, 0x00, 0x03])
        let response = Data([0x00, 0x00, 0x00, 0x00, 0x01])
        await transport.setResponse(for: query, response: response)

        let mode = try await proto.getMode(vfo: .a)

        #expect(mode == .usb)
    }

    @Test func getModeReturnsFMNarrowWhenBit7Set() async throws {
        // Byte 4 = 0x88 → selector 0x08 (FM) with narrow bit set.
        let (transport, proto) = try await makeProtocol()

        let query = Data([0x00, 0x00, 0x00, 0x00, 0x03])
        let response = Data([0x00, 0x00, 0x00, 0x00, 0x88])
        await transport.setResponse(for: query, response: response)

        let mode = try await proto.getMode(vfo: .a)

        #expect(mode == .fmN)
    }

    // MARK: - PTT

    @Test func setPTTOnEmitsBareOpcodeZeroEight() async throws {
        // ncmd "ptt on" at ft817.c:182 → { 1, { 0x00, 0x00, 0x00,
        // 0x00, 0x08 } }.
        let (transport, proto) = try await makeProtocol()
        try await proto.setPTT(true)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x08]))
    }

    @Test func setPTTOffEmitsBareOpcodeEightEight() async throws {
        let (transport, proto) = try await makeProtocol()
        try await proto.setPTT(false)
        let writes = await transport.recordedWrites
        #expect(writes[0] == Data([0x00, 0x00, 0x00, 0x00, 0x88]))
    }

    @Test func getPTTQueriesTXStatusAndReadsSingleByte() async throws {
        // Send opcode 0xF7 → 1-byte response. 0xFF = idle;
        // anything else = transmitting.
        let (transport, proto) = try await makeProtocol()

        let query = Data([0x00, 0x00, 0x00, 0x00, 0xF7])
        // Radio idle
        await transport.setResponse(for: query, response: Data([0xFF]))

        let ptt = try await proto.getPTT()
        #expect(ptt == false)
    }

    @Test func getPTTReturnsTrueWhenTransmitting() async throws {
        let (transport, proto) = try await makeProtocol()

        let query = Data([0x00, 0x00, 0x00, 0x00, 0xF7])
        // Radio TXing at 50% power (arbitrary non-FF byte)
        await transport.setResponse(for: query, response: Data([0x50]))

        let ptt = try await proto.getPTT()
        #expect(ptt == true)
    }

    // MARK: - VFO

    @Test func selectVFOIsNoOpOnFT817Family() async throws {
        // The FT-817 has no "select VFO A" or "select VFO B"
        // command — only a toggle. Rather than issue a speculative
        // toggle, we no-op. This test guarantees we don't emit
        // spurious bytes on selectVFO.
        let (transport, proto) = try await makeProtocol()

        try await proto.selectVFO(.a)
        try await proto.selectVFO(.b)

        let writes = await transport.recordedWrites
        #expect(writes.isEmpty)
    }

    // MARK: - Low-baud-rate framing (v1.2.1 regression)

    @Test func getFrequencyReassemblesChunkedResponseAtLowBaudRate() async throws {
        // Regression for the FT-857 4800-baud "invalid response"
        // report (issue #12 followup — MacWinlink beta30 field
        // report). At 4800 baud each byte takes ~2 ms to transit,
        // so a 5-byte status frame straddles multiple OS reads.
        //
        // Before the fix, `sendStatusCommand` called
        // `transport.read(timeout:)` once and rejected any response
        // shorter than `expectedLength` with `.invalidResponse`. The
        // fix routes through `transport.readExact(count:timeout:)`
        // which accumulates until the full frame arrives.
        //
        // Simulate the arrival pattern with the mock's chunked
        // response: 1 + 2 + 2 bytes across three reads. If the fix
        // is in place, `getFrequency` returns the decoded value.
        let (transport, proto) = try await makeProtocol()

        // 14_230_000 Hz → 01 42 30 00 + USB mode selector 0x01.
        await transport.setChunkedResponse([
            Data([0x01]),
            Data([0x42, 0x30]),
            Data([0x00, 0x01])
        ])

        let freq = try await proto.getFrequency(vfo: .a)
        #expect(freq == 14_230_000)

        let writes = await transport.recordedWrites
        #expect(writes == [Data([0x00, 0x00, 0x00, 0x00, 0x03])])
    }

    // MARK: - Unsupported modes

    @Test func setModeThrowsForRTTY() async throws {
        // RTTY is a valid Mode but the FT-817 family exposes no
        // native mode selector for it. Callers should get a clear
        // error rather than silently succeeding.
        let (_, proto) = try await makeProtocol()

        await #expect(throws: RigError.self) {
            try await proto.setMode(.rtty, vfo: .a)
        }
    }
}
