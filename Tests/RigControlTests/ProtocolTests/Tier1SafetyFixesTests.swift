import Foundation
import Testing
@testable import RigControl

/// Regression tests for the Tier 1 safety-critical bugs identified
/// in the 2026-07-15 Hamlib parity audit. Each test targets a
/// specific bug that could unintentionally key a transmitter, TX on
/// the wrong VFO, or otherwise diverge dangerously from Hamlib.
///
/// These tests must never be deleted — even after the underlying
/// bugs stay fixed, they document the exact wire semantics that
/// SwiftRigControl guarantees.
@Suite struct Tier1SafetyFixesTests {

    // MARK: - Kenwood PTT bugs (setPTT + getPTT)

    /// Regression: pre-fix `setPTT(false)` sent `TX0;` which on
    /// Kenwood means "PTT on via mic port" — the exact opposite of
    /// releasing PTT. Verifies the fix uses bare `RX;` per Hamlib
    /// `kenwood_set_ptt`.
    @Test func kenwoodSetPTTOffSendsBareRX() async throws {
        let mock = MockTransport()
        let kw = KenwoodProtocol(transport: mock, capabilities: .full)
        try await kw.connect()
        await mock.reset()

        try await kw.setPTT(false)

        let writes = await mock.recordedWrites
        #expect(writes.count == 1)
        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "RX;")
    }

    @Test func kenwoodSetPTTOnSendsBareTX() async throws {
        let mock = MockTransport()
        let kw = KenwoodProtocol(transport: mock, capabilities: .full)
        try await kw.connect()
        await mock.reset()

        try await kw.setPTT(true)

        let writes = await mock.recordedWrites
        #expect(writes.count == 1)
        let command = String(data: writes[0], encoding: .ascii)
        #expect(command == "TX;")
    }

    /// Regression: pre-fix `getPTT()` sent `TX;` (a *set* command)
    /// which keyed the transmitter every time the caller polled
    /// PTT state. Verifies the fix uses `IF;` per Hamlib
    /// `kenwood_get_ptt`.
    @Test func kenwoodGetPTTUsesIFQueryNotTX() async throws {
        let mock = MockTransport()
        let kw = KenwoodProtocol(transport: mock, capabilities: .full)
        try await kw.connect()
        await mock.reset()

        // The `IF;` response is a fixed 37-char string plus the
        // `;` terminator, with TX/RX flag at byte 28 per Hamlib
        // `kenwood_get_ptt` (byte 28 = '0' RX, '1' TX).
        let ifQuery = "IF;".data(using: .ascii)!
        let ifResp = Self.makeIFResponse(txByte: "0")
        await mock.setResponse(for: ifQuery, response: ifResp)

        let ptt = try await kw.getPTT()

        let writes = await mock.recordedWrites
        #expect(writes.count == 1)
        #expect(String(data: writes[0], encoding: .ascii) == "IF;")
        #expect(ptt == false)
    }

    @Test func kenwoodGetPTTReadsIFByte28AsTransmit() async throws {
        let mock = MockTransport()
        let kw = KenwoodProtocol(transport: mock, capabilities: .full)
        try await kw.connect()
        await mock.reset()

        let ifQuery = "IF;".data(using: .ascii)!
        let ifResp = Self.makeIFResponse(txByte: "1")
        await mock.setResponse(for: ifQuery, response: ifResp)

        let ptt = try await kw.getPTT()
        #expect(ptt == true)
    }

    /// Constructs a plausible Kenwood `IF;` response with the
    /// TX/RX byte at position 28 set explicitly. The rest of the
    /// fields are zero-filled — only position 28 matters for the
    /// PTT-reading path under test.
    private static func makeIFResponse(txByte: Character) -> Data {
        // Fill 37 chars, then append ';'. Positions 0-1 = "IF".
        var chars = Array(repeating: Character("0"), count: 37)
        chars[0] = "I"
        chars[1] = "F"
        chars[28] = txByte
        return (String(chars) + ";").data(using: .ascii)!
    }

    // MARK: - Yaesu getPTT: TX2/TX3 must be recognized as transmitting

    /// Regression: pre-fix `getPTT()` only checked for `TX1;` and
    /// misreported `TX2;` (data-jack PTT) and `TX3;` (CAT-port PTT)
    /// as "not transmitting". A UI that polled PTT would show RX
    /// while the radio was actually keyed, tempting the operator
    /// to send another PTT toggle. Matches Hamlib
    /// `newcat_get_ptt` (newcat.c:2282-2295).
    @Test func yaesuGetPTTRecognizesTX1AsTransmit() async throws {
        try await assertYaesuGetPTT(responding: "TX1;", equals: true)
    }

    @Test func yaesuGetPTTRecognizesTX2AsTransmit() async throws {
        try await assertYaesuGetPTT(responding: "TX2;", equals: true)
    }

    @Test func yaesuGetPTTRecognizesTX3AsTransmit() async throws {
        try await assertYaesuGetPTT(responding: "TX3;", equals: true)
    }

    @Test func yaesuGetPTTRecognizesTX0AsReceive() async throws {
        try await assertYaesuGetPTT(responding: "TX0;", equals: false)
    }

    private func assertYaesuGetPTT(responding: String, equals expected: Bool) async throws {
        let mock = MockTransport()
        let yaesu = YaesuCATProtocol(transport: mock, capabilities: .full)
        try await yaesu.connect()
        await mock.reset()

        let query = "TX;".data(using: .ascii)!
        let response = responding.data(using: .ascii)!
        await mock.setResponse(for: query, response: response)

        let ptt = try await yaesu.getPTT()
        #expect(ptt == expected)
    }

    // MARK: - Yaesu split: uses ST;, not FT;

    /// Regression: pre-fix `setSplit(true)` on an FT-DX10 sent
    /// `FT1;` — but on modern Yaesu radios `FT` is TX-VFO selection
    /// and `FT1;` would silently reassign the TX VFO instead of
    /// enabling split. Verifies fix uses `ST0;` / `ST1;` per Hamlib
    /// `newcat_set_split` (newcat.c:8317).
    @Test func yaesuSetSplitOnFTDX10SendsST1() async throws {
        let mock = MockTransport()
        let yaesu = YaesuCATProtocol(
            transport: mock,
            capabilities: .full,
            quirks: .newcatWithSTDX
        )
        try await yaesu.connect()
        await mock.reset()

        let cmd = "ST1;".data(using: .ascii)!
        await mock.setResponse(for: cmd, response: cmd)

        try await yaesu.setSplit(true)

        let writes = await mock.recordedWrites
        #expect(writes.count == 1)
        #expect(String(data: writes[0], encoding: .ascii) == "ST1;")
    }

    @Test func yaesuSetSplitOffOnFTDX10SendsST0() async throws {
        let mock = MockTransport()
        let yaesu = YaesuCATProtocol(
            transport: mock,
            capabilities: .full,
            quirks: .newcatWithSTDX
        )
        try await yaesu.connect()
        await mock.reset()

        let cmd = "ST0;".data(using: .ascii)!
        await mock.setResponse(for: cmd, response: cmd)

        try await yaesu.setSplit(false)

        let writes = await mock.recordedWrites
        #expect(writes.count == 1)
        #expect(String(data: writes[0], encoding: .ascii) == "ST0;")
    }

    /// On FT-950/991/2000/DX3000/DX5000/DX1200/DX9000 the `ST`
    /// command is not supported per Hamlib newcat.c:578. Rather
    /// than silently sending the wrong bytes, `setSplit` must fail
    /// loudly so callers know to use TX-VFO selection instead.
    @Test func yaesuSetSplitOnNoSTRadioThrowsUnsupported() async throws {
        let mock = MockTransport()
        let yaesu = YaesuCATProtocol(
            transport: mock,
            capabilities: .full,
            quirks: .newcatNoST
        )
        try await yaesu.connect()
        await mock.reset()

        await #expect(throws: RigError.self) {
            try await yaesu.setSplit(true)
        }

        let writes = await mock.recordedWrites
        #expect(writes.isEmpty, "no bytes should be written when split is unsupported")
    }

    /// FT-891 has neither ST nor FT per Hamlib newcat.c:516,578.
    /// Both `setSplit` and `selectVFO` must throw rather than
    /// send bytes that could reassign the TX VFO.
    @Test func yaesuFT891SelectVFOThrowsUnsupported() async throws {
        let mock = MockTransport()
        let yaesu = YaesuCATProtocol(
            transport: mock,
            capabilities: .full,
            quirks: .ft891
        )
        try await yaesu.connect()
        await mock.reset()

        await #expect(throws: RigError.self) {
            try await yaesu.selectVFO(.b)
        }
    }

    // MARK: - Yaesu selectVFO: uses FT2/FT3 on radios that need it

    /// On FT-950/2000/DX3000/DX5000/DX1200/991/DX10/DX101(D/MP),
    /// `FT0;`/`FT1;` toggle the TX function and `FT2;`/`FT3;`
    /// select VFO A/B. Pre-fix code sent `FT0;`/`FT1;` for VFO
    /// selection, which on these radios would silently reassign
    /// TX-VFO instead. Matches Hamlib newcat.c:8216-8222.
    @Test func yaesuSelectVFOOnFT950UsesFT2AndFT3() async throws {
        let mock = MockTransport()
        let yaesu = YaesuCATProtocol(
            transport: mock,
            capabilities: .full,
            quirks: .newcatNoST
        )
        try await yaesu.connect()
        await mock.reset()

        await mock.setResponse(
            for: "FT2;".data(using: .ascii)!,
            response: "FT2;".data(using: .ascii)!
        )
        try await yaesu.selectVFO(.a)

        await mock.setResponse(
            for: "FT3;".data(using: .ascii)!,
            response: "FT3;".data(using: .ascii)!
        )
        try await yaesu.selectVFO(.b)

        let writes = await mock.recordedWrites
        #expect(writes.count == 2)
        #expect(String(data: writes[0], encoding: .ascii) == "FT2;")
        #expect(String(data: writes[1], encoding: .ascii) == "FT3;")
    }

    /// FT-710 uses classic `FT0;`/`FT1;` for VFO A/B per Hamlib
    /// (falls through the model-check at newcat.c:8216-8218).
    @Test func yaesuSelectVFOOnFT710UsesFT0AndFT1() async throws {
        let mock = MockTransport()
        let yaesu = YaesuCATProtocol(
            transport: mock,
            capabilities: .full,
            quirks: .ft710
        )
        try await yaesu.connect()
        await mock.reset()

        await mock.setResponse(
            for: "FT0;".data(using: .ascii)!,
            response: "FT0;".data(using: .ascii)!
        )
        try await yaesu.selectVFO(.a)

        await mock.setResponse(
            for: "FT1;".data(using: .ascii)!,
            response: "FT1;".data(using: .ascii)!
        )
        try await yaesu.selectVFO(.b)

        let writes = await mock.recordedWrites
        #expect(writes.count == 2)
        #expect(String(data: writes[0], encoding: .ascii) == "FT0;")
        #expect(String(data: writes[1], encoding: .ascii) == "FT1;")
    }

    // MARK: - FT-891 capability flag

    @Test func ft891HasSplitIsFalse() {
        // Pre-fix code advertised hasSplit=true even though the radio
        // has no CAT path to establish split (no ST, no FT).
        // Capability flag must be honest so callers don't attempt it.
        #expect(RadioDefinition.Yaesu.ft891.capabilities.hasSplit == false)
    }

    // MARK: - Kenwood mode code 8 (FSK-R)

    @Test func kenwoodModeCode8RoundTripsToRTTYR() async throws {
        // Verifying by exercising setMode(.rttyR) → we should see
        // "MD8;" go out on the wire.
        let mock = MockTransport()
        let kw = KenwoodProtocol(transport: mock, capabilities: .full)
        try await kw.connect()
        await mock.reset()

        let cmd = "MD8;".data(using: .ascii)!
        await mock.setResponse(for: cmd, response: cmd)

        try await kw.setMode(.rttyR, vfo: .a)

        let writes = await mock.recordedWrites
        #expect(writes.count == 1)
        #expect(String(data: writes[0], encoding: .ascii) == "MD8;")
    }
}
