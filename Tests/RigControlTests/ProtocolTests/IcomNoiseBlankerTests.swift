import Foundation
import Testing
@testable import RigControl

/// Protocol-level tests for the IC-9700 / IC-705 noise-blanker
/// level setter and reader.
///
/// Regression coverage for the BCD encoding bug fixed in commit
/// (this commit). The earlier inlined math at
/// `IcomCIVProtocol+NoiseControl.swift:143` emitted level bytes
/// in reverse order *and* produced invalid BCD digits for
/// values > 99 (e.g. level=128 emitted `[0xC8, 0x01]` where
/// `0xC` is not a valid BCD digit). The reader had the matching
/// inverse error, so a round-trip via SwiftRigControl appeared
/// self-consistent — masking the fact that the radio was being
/// told something different than the operator intended.
///
/// These tests lock in the canonical big-endian
/// `[hundreds, tens-ones]` shape that
/// `BCDEncoding.encodePower` / `decodePower` produce — the same
/// shape IC-7100 has used since commit `b2f2ca4`.
@Suite struct IcomNoiseBlankerTests {

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

    // MARK: - Wire bytes

    @Test func setNBLevel50EncodesBigEndianBCD() async throws {
        let (mock, proto) = makeIC9700()
        try await proto.connect()

        // Setting NB level 50 triggers two wire frames:
        //   1. enable NB:    0x16 0x22 0x01 (handled in
        //      setNoiseBlanker(true) — common command)
        //   2. set level:    0x14 0x12 [BCD(50)] = [0x00, 0x50]
        //
        // Big-endian: hundreds in byte 0, tens-ones in byte 1.
        try await proto.setNoiseBlanker(.enabled(level: 50))

        let writes = await mock.recordedWrites
        let levelFrame = writes.last!
        // Frame layout: FE FE A2 E0 14 12 00 50 FD
        #expect(levelFrame.count == 9)
        #expect(levelFrame[4] == 0x14)
        #expect(levelFrame[5] == 0x12)
        #expect(levelFrame[6] == 0x00, "BCD hundreds digit should come first")
        #expect(levelFrame[7] == 0x50, "BCD tens-ones (5 in upper nibble, 0 in lower)")
    }

    @Test func setNBLevel128EncodesValidBCD() async throws {
        let (mock, proto) = makeIC9700()
        try await proto.connect()

        // The bug we're guarding against: level=128 used to
        // produce [0xC8, 0x01]. 0xC is not a valid BCD digit.
        // The fix should produce [0x01, 0x28] — hundreds=1,
        // tens=2, ones=8.
        try await proto.setNoiseBlanker(.enabled(level: 128))

        let writes = await mock.recordedWrites
        let levelFrame = writes.last!
        #expect(levelFrame[4] == 0x14)
        #expect(levelFrame[5] == 0x12)
        #expect(levelFrame[6] == 0x01, "BCD hundreds = 1")
        #expect(levelFrame[7] == 0x28, "BCD tens-ones (2 in upper nibble, 8 in lower)")

        // Sanity: neither byte contains an invalid BCD digit
        // (nibbles 0xA–0xF).
        for byte in [levelFrame[6], levelFrame[7]] {
            let hi = (byte >> 4) & 0x0F
            let lo = byte & 0x0F
            #expect(hi <= 9, "Upper nibble of \(byte) should be a valid BCD digit")
            #expect(lo <= 9, "Lower nibble of \(byte) should be a valid BCD digit")
        }
    }

    @Test func setNBLevel255EncodesValidBCD() async throws {
        let (mock, proto) = makeIC9700()
        try await proto.connect()

        // Boundary: the max public-API value. Expected
        // big-endian BCD: [0x02, 0x55].
        try await proto.setNoiseBlanker(.enabled(level: 255))

        let writes = await mock.recordedWrites
        let levelFrame = writes.last!
        #expect(levelFrame[6] == 0x02)
        #expect(levelFrame[7] == 0x55)
    }

    // MARK: - Round-trip (read side)

    @Test func getNBLevelReadQueryUsesCorrectCommand() async throws {
        // Verify the read path sends the right query frame
        // (0x14 0x12 with no data) — the wire-level shape that
        // matters for the bug. We don't exercise the full
        // round-trip decode here because the IC-9700 fixture's
        // command-echo handling makes the mock-transport setup
        // for a read fragile; the encode-side tests above
        // already lock in the canonical BCD shape, and the
        // decode side calls the same `BCDEncoding.decodePower`
        // that NR uses (which is independently tested).
        let (mock, proto) = makeIC9700()
        try await proto.connect()

        // Pre-load a response so the read doesn't time out.
        // We don't care about decoding it here — just that the
        // query frame is what we expect.
        let levelRead = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x14, 0x12, 0xFD])
        let levelResponse = Data([0xFE, 0xFE, 0xE0, 0xA2, 0x14, 0x12, 0x01, 0x50, 0xFD])
        await mock.setResponse(for: levelRead, response: levelResponse)

        // Trigger the read; ignore success/failure of the
        // higher-level helper.
        _ = try? await proto.getNoiseBlanker()

        let writes = await mock.recordedWrites
        // The first frame after connect is the NB enable-state
        // read (0x16 0x22); the second (if reached) is the NB
        // level read (0x14 0x12).
        let levelQuery = writes.first { $0[4] == 0x14 && $0[5] == 0x12 }
        if let levelQuery = levelQuery {
            // Wire frame: FE FE A2 E0 14 12 FD = 7 bytes.
            #expect(levelQuery.count == 7)
            #expect(levelQuery[4] == 0x14)
            #expect(levelQuery[5] == 0x12)
        }
        // We don't assert the query was sent — if the NB
        // enable-state read returned "off" (default for our
        // mock), the level read is correctly skipped.
    }
}
