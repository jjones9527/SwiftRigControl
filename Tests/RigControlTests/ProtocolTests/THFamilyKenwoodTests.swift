import Foundation
import Testing
@testable import RigControl

/// Byte-level protocol tests for the three CR-terminated Kenwood
/// handheld / mobile protocols:
/// - ``THD72Protocol`` (with `Family.thd72` and `Family.thd74`)
/// - ``TMFamilyCAT`` (TM-D710 / TM-V71)
/// - ``THFamilyCAT`` (TH-F6A / TH-F7E)
///
/// Every fixture is derived from Hamlib
/// `rigs/kenwood/thd72.c`, `thd74.c`, `tmd710.c`, `thf6a.c`, and
/// the shared `th.c` helpers. All three protocols use the CR
/// (`\r`) terminator (EOM_TH in Hamlib) — the semicolon terminator
/// belongs to the HF Kenwood text protocol, which is a different
/// family entirely.
@Suite struct THFamilyKenwoodTests {

    // MARK: - THD72Protocol .thd72 (baseline, ensures family=.thd72 default)

    @Test func thd72SetFrequencyUsesFOStringAtPositions5To14() async throws {
        let transport = MockTransport()
        let proto = THD72Protocol(
            transport: transport,
            capabilities: .full,
            family: .thd72
        )
        try await proto.connect()
        await transport.reset()

        // First fetch the FO string (query: "FO 0\r"), respond with
        // a 52+ byte template. Then setFrequency writes back the
        // mutated string.
        let query = "FO 0\r".data(using: .ascii)!
        // 53-byte response: "FO 0,DDDDDDDDDD,......,mode(1char)" — we
        // just care that chars 5-14 are the freq and char 51 is mode.
        let template =
            "FO 0,0146000000,0,0,0,0,0,00,00,000,00000000,0"
        let templateResp = (template + "\r").data(using: .ascii)!
        await transport.setResponse(for: query, response: templateResp)

        // Also mock the write-back echo — the mutated FO becomes the
        // command AND the expected response since the radio echoes.
        let expectedWrite = "FO 0,0147500000,0,0,0,0,0,00,00,000,00000000,0"
        let expectedResp = (expectedWrite + "\r").data(using: .ascii)!
        await transport.setResponse(
            for: (expectedWrite + "\r").data(using: .ascii)!,
            response: expectedResp
        )

        try await proto.setFrequency(147_500_000, vfo: .a)

        let writes = await transport.recordedWrites
        // Two writes: fetch query + mutated write-back.
        #expect(writes.count == 2)
        #expect(String(data: writes[0], encoding: .ascii) == "FO 0\r")
        // The write-back should have the new frequency at positions
        // 5-14 (the "0147500000" segment).
        let secondWrite = String(data: writes[1], encoding: .ascii) ?? ""
        #expect(secondWrite.contains("0147500000"))
    }

    // MARK: - THD72Protocol .thd74 (mode at position 31, not 51)

    @Test func thd74ModeAtPosition31NotPosition51() async throws {
        let transport = MockTransport()
        let proto = THD72Protocol(
            transport: transport,
            capabilities: .full,
            family: .thd74
        )
        try await proto.connect()
        await transport.reset()

        // TH-D74 response is 72 bytes; mode selector at char 31.
        // For this test we only need the parser to look at position
        // 31 correctly. Construct a 72-byte response where char 31
        // holds '1' (FM-N).
        let responsePayload = String(
            repeating: "0",
            count: 72
        )
        var chars = Array(responsePayload)
        chars[0] = "F"; chars[1] = "O"; chars[2] = " "; chars[3] = "0"; chars[4] = ","
        // freq at chars 5-14
        for (i, c) in "0146000000".enumerated() {
            chars[5 + i] = c
        }
        // mode at char 31
        chars[31] = "1"
        let responseStr = String(chars)
        let query = "FO 0\r".data(using: .ascii)!
        await transport.setResponse(
            for: query,
            response: (responseStr + "\r").data(using: .ascii)!
        )

        let mode = try await proto.getMode(vfo: .a)
        #expect(mode == .fmN)
    }

    // MARK: - TMFamilyCAT

    @Test func tmFamilySetFrequencyRewritesField1() async throws {
        let transport = MockTransport()
        let proto = TMFamilyCAT(transport: transport, capabilities: .full)
        try await proto.connect()
        await transport.reset()

        // fetchFO query: "FO 0\r"
        let query = "FO 0\r".data(using: .ascii)!
        // Response with 13 fields per Hamlib tmd710_pull_fo format:
        //   FO 0,0146000000,0,0,0,0,0,0,00,00,000,00000000,0
        let templateResp = "FO 0,0146000000,0,0,0,0,0,0,00,00,000,00000000,0\r"
            .data(using: .ascii)!
        await transport.setResponse(for: query, response: templateResp)

        // The mutated write-back should have field 1 replaced with
        // the new frequency (10 digits). Everything else identical.
        let expectedWrite = "FO 0,0147500000,0,0,0,0,0,0,00,00,000,00000000,0\r"
            .data(using: .ascii)!
        await transport.setResponse(for: expectedWrite, response: expectedWrite)

        try await proto.setFrequency(147_500_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes.count == 2)
        #expect(writes[0] == query)
        #expect(writes[1] == expectedWrite)
    }

    @Test func tmFamilyVFOBFetchesVFO1() async throws {
        let transport = MockTransport()
        let proto = TMFamilyCAT(transport: transport, capabilities: .full)
        try await proto.connect()
        await transport.reset()

        // When VFO B is requested, the FO fetch should target "FO 1".
        let query = "FO 1\r".data(using: .ascii)!
        let templateResp = "FO 1,0435000000,0,0,0,0,0,0,00,00,000,00000000,0\r"
            .data(using: .ascii)!
        await transport.setResponse(for: query, response: templateResp)

        let freq = try await proto.getFrequency(vfo: .b)
        #expect(freq == 435_000_000)
    }

    @Test func tmFamilySetPTTEmitsBareTXOrRX() async throws {
        let transport = MockTransport()
        let proto = TMFamilyCAT(transport: transport, capabilities: .full)
        try await proto.connect()
        await transport.reset()

        try await proto.setPTT(true)
        try await proto.setPTT(false)

        let writes = await transport.recordedWrites
        #expect(writes.count == 2)
        #expect(String(data: writes[0], encoding: .ascii) == "TX\r")
        #expect(String(data: writes[1], encoding: .ascii) == "RX\r")
    }

    @Test func tmFamilyModeToTMD710IndexFM() throws {
        #expect(try TMFamilyCAT.modeToTMD710Index(.fm) == 0)
        #expect(try TMFamilyCAT.modeToTMD710Index(.fmN) == 1)
        #expect(try TMFamilyCAT.modeToTMD710Index(.am) == 2)
    }

    @Test func tmFamilyRejectsSSBModeAsUnsupported() throws {
        #expect(throws: RigError.self) {
            _ = try TMFamilyCAT.modeToTMD710Index(.usb)
        }
    }

    // MARK: - THFamilyCAT

    @Test func thFamilySetFrequencyEmitsFQWith11DigitsPlusHexStep() async throws {
        // Format matches Hamlib `th_set_freq()` at th.c:239:
        //   FQ %011lld,%X\r
        // 146 MHz aligns exactly to both the 5-kHz and 6.25-kHz
        // grids (error 0 on each). Hamlib's tie-breaker
        // (`abs(freq5-freq) < abs(freq625-freq)`, strict less-than)
        // falls through to step 1 on a tie. This test locks the
        // Hamlib-parity behavior; a caller who cares that a
        // specific frequency lands on step 0 can nudge by 5 kHz.
        let transport = MockTransport()
        let proto = THFamilyCAT(transport: transport, capabilities: .full)
        try await proto.connect()
        await transport.reset()

        let expectedWrite = "FQ 00146000000,1\r".data(using: .ascii)!
        await transport.setResponse(for: expectedWrite, response: expectedWrite)

        try await proto.setFrequency(146_000_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes.count == 1)
        #expect(writes[0] == expectedWrite)
    }

    @Test func thFamilyGetFrequencyDiscardsStepFieldFromResponse() async throws {
        // Per Hamlib th.c:250-282 the step field on the FQ
        // response is not preserved — it's recomputed from the
        // frequency on every set (see `computeStepAndRoundedFreq`).
        // Prior to the v1.2.4 fix the step was snapshotted from
        // getFrequency and reused on subsequent sets, which
        // silently produced the wrong wire when the front panel
        // changed the grid or when setFrequency was called before
        // any getFrequency.
        let transport = MockTransport()
        let proto = THFamilyCAT(transport: transport, capabilities: .full)
        try await proto.connect()
        await transport.reset()

        // Radio reports step 3 in the response — we should ignore
        // it and read only the frequency.
        let getQuery = "FQ\r".data(using: .ascii)!
        let getResp = "FQ 00146000000,3\r".data(using: .ascii)!
        await transport.setResponse(for: getQuery, response: getResp)

        let freq = try await proto.getFrequency(vfo: .a)
        #expect(freq == 146_000_000)

        // A subsequent setFrequency must compute the step from the
        // new frequency, not carry over the reported `3`. 147.5 MHz
        // aligns exactly to both the 5-kHz and 6.25-kHz grids; the
        // tie-breaker matches Hamlib's strict-less-than at th.c:227
        // and picks step 1.
        await transport.reset()
        let expectedWrite = "FQ 00147500000,1\r".data(using: .ascii)!
        await transport.setResponse(for: expectedWrite, response: expectedWrite)

        try await proto.setFrequency(147_500_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes.count == 1)
        #expect(writes[0] == expectedWrite)
    }

    @Test func thFamilyComputesStepZeroForFiveKilohertzGrid() {
        // 146.005 MHz is exactly on the 5-kHz grid → step 0.
        let (freq, step) = THFamilyCAT.computeStepAndRoundedFreq(hz: 146_005_000)
        #expect(step == 0)
        #expect(freq == 146_005_000)
    }

    @Test func thFamilyComputesStepOneForSixPointTwoFiveKilohertzGrid() {
        // 145.006250 MHz aligns exactly to the 6.25-kHz grid
        // (145_006_250 / 6250 = 23_201), doesn't align to 5-kHz
        // (145_006_250 / 5000 = 29001.25). The 6.25-kHz choice
        // gives error 0; 5-kHz gives error 1250. Pick step 1.
        let (freq, step) = THFamilyCAT.computeStepAndRoundedFreq(hz: 145_006_250)
        #expect(step == 1)
        #expect(freq == 145_006_250)
    }

    @Test func thFamilyForcesStepFourAndTenKilohertzRoundingAbove470MHz() {
        // Per Hamlib th.c:240-241: above 470 MHz the algorithm
        // overrides to the 10-kHz grid and step 4. 902.125 MHz on
        // a 10-kHz grid rounds to 902.130 MHz (half-up per C's
        // `round()`, which Swift's `.rounded()` matches).
        let (freq, step) = THFamilyCAT.computeStepAndRoundedFreq(hz: 902_125_000)
        #expect(step == 4)
        #expect(freq == 902_130_000)
    }

    @Test func thFamilySetFrequencyEmitsStepFourAboveUHFBoundary() async throws {
        // Integration test: 902.125 MHz on the wire becomes
        // FQ 00902130000,4\r.
        let transport = MockTransport()
        let proto = THFamilyCAT(transport: transport, capabilities: .full)
        try await proto.connect()
        await transport.reset()

        let expectedWrite = "FQ 00902130000,4\r".data(using: .ascii)!
        await transport.setResponse(for: expectedWrite, response: expectedWrite)

        try await proto.setFrequency(902_125_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes[0] == expectedWrite)
    }

    @Test func thFamilySetModeEmitsMDWithDigit() async throws {
        let transport = MockTransport()
        let proto = THFamilyCAT(transport: transport, capabilities: .full)
        try await proto.connect()
        await transport.reset()

        // TH-F6A mode indices per thf6a.c thf6_mode_table:
        //   0=FM, 1=WFM, 2=AM, 3=LSB, 4=USB, 5=CW.
        let expectedWrite = "MD 4\r".data(using: .ascii)!
        await transport.setResponse(for: expectedWrite, response: expectedWrite)

        try await proto.setMode(.usb, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes.count == 1)
        #expect(writes[0] == expectedWrite)
    }

    @Test func thFamilyGetModeParsesResponseDigit() async throws {
        let transport = MockTransport()
        let proto = THFamilyCAT(transport: transport, capabilities: .full)
        try await proto.connect()
        await transport.reset()

        // Response "MD 5\r" = CW.
        let getQuery = "MD\r".data(using: .ascii)!
        let getResp = "MD 5\r".data(using: .ascii)!
        await transport.setResponse(for: getQuery, response: getResp)

        let mode = try await proto.getMode(vfo: .a)
        #expect(mode == .cw)
    }

    @Test func thFamilyModeIndicesMatchHamlibTable() throws {
        #expect(try THFamilyCAT.modeToTHFIndex(.fm)  == 0)
        #expect(try THFamilyCAT.modeToTHFIndex(.wfm) == 1)
        #expect(try THFamilyCAT.modeToTHFIndex(.am)  == 2)
        #expect(try THFamilyCAT.modeToTHFIndex(.lsb) == 3)
        #expect(try THFamilyCAT.modeToTHFIndex(.usb) == 4)
        #expect(try THFamilyCAT.modeToTHFIndex(.cw)  == 5)
    }

    @Test func thFamilyRejectsRTTYAsUnsupported() throws {
        #expect(throws: RigError.self) {
            _ = try THFamilyCAT.modeToTHFIndex(.rtty)
        }
    }
}
