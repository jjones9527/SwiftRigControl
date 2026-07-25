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
        let transport = MockTransport()
        let proto = THFamilyCAT(transport: transport, capabilities: .full)
        try await proto.connect()
        await transport.reset()

        // Default step index = 0 → hex "0".
        // Format matches Hamlib th_set_freq(): "FQ %011lld,%X\r".
        let expectedWrite = "FQ 00146000000,0\r".data(using: .ascii)!
        await transport.setResponse(for: expectedWrite, response: expectedWrite)

        try await proto.setFrequency(146_000_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes.count == 1)
        #expect(writes[0] == expectedWrite)
    }

    @Test func thFamilyGetFrequencyRoundTripsStep() async throws {
        let transport = MockTransport()
        let proto = THFamilyCAT(transport: transport, capabilities: .full)
        try await proto.connect()
        await transport.reset()

        // Radio's stored step is 3 (hex "3"). getFrequency should
        // snapshot it so the next setFrequency emits step=3.
        let getQuery = "FQ\r".data(using: .ascii)!
        let getResp = "FQ 00146000000,3\r".data(using: .ascii)!
        await transport.setResponse(for: getQuery, response: getResp)

        let freq = try await proto.getFrequency(vfo: .a)
        #expect(freq == 146_000_000)

        // Now setFrequency should emit hex "3" as the step.
        await transport.reset()
        let expectedWrite = "FQ 00147500000,3\r".data(using: .ascii)!
        await transport.setResponse(for: expectedWrite, response: expectedWrite)

        try await proto.setFrequency(147_500_000, vfo: .a)

        let writes = await transport.recordedWrites
        #expect(writes.count == 1)
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
