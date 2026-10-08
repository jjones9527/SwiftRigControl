import Foundation
import Testing
@testable import RigControl

/// Yaesu newcat set-command verification (v1.2.19).
///
/// Newcat radios don't answer set commands. Hamlib `newcat_set_cmd`
/// (`newcat.c:10911-11095`) writes `FA` / `FB` / `TX` / `MD` / `ST` with no
/// read, follows every other set with `ID;` (`AI;` on the FTDX-9000) and
/// treats a `?;` before that reply as "busy, resend". `AC` is sent once and
/// drained (`newcat_set_ac_cmd`, upstream `635d11fe`). Pre-v1.2.19 most
/// sets read one reply expecting an echo that real radios never send.
@Suite struct YaesuSetCommandTests {

    private static func ascii(_ s: String) -> Data { s.data(using: .ascii)! }

    private func make(_ quirks: YaesuCATProtocol.Quirks = .newcatNoST,
                      capabilities: RigCapabilities = .full) async throws -> (MockTransport, YaesuCATProtocol) {
        let mock = MockTransport()
        let proto = YaesuCATProtocol(transport: mock, capabilities: capabilities, quirks: quirks)
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID0670;"))
        return (mock, proto)
    }

    private func sent(_ mock: MockTransport) async -> [String] {
        await mock.recordedWrites.map { String(data: $0, encoding: .ascii) ?? "" }
    }

    // MARK: - Write-only commands

    @Test func frequencyModePTTAndSplitAreWriteOnly() async throws {
        // newcat.c:10966-10973. A read here would wait out the timeout.
        let (mock, proto) = try await make(.newcatWithSTDX)
        await mock.setShouldThrowOnRead(true)
        try await proto.setFrequency(14_074_000, vfo: .a)
        try await proto.setMode(.usb, vfo: .a)
        try await proto.setPTT(true)
        try await proto.setSplit(true)
        #expect(await sent(mock) == ["FA014074000;", "MD02;", "TX1;", "ST1;"])
    }

    // MARK: - ID; verification

    @Test func otherSetsAreVerifiedWithID() async throws {
        let (mock, proto) = try await make()
        try await proto.setPower(50)
        #expect(await sent(mock) == ["PC050;", "ID;"])
    }

    @Test func questionMarkIsRetriedThenThrows() async throws {
        // "?;" means busy (newcat.c:11034-11075): read the ID reply,
        // resend, and give up after the second refusal.
        let (mock, proto) = try await make()
        await mock.setChunkedResponse([
            Self.ascii("?;"), Self.ascii("ID0670;"),
            Self.ascii("?;"), Self.ascii("ID0670;"),
        ])
        do {
            try await proto.setPower(50)
            Issue.record("expected a throw")
        } catch RigError.commandFailed(_) {
        } catch {
            Issue.record("expected commandFailed, got \(error)")
        }
        #expect(await sent(mock) == ["PC050;", "ID;", "PC050;", "ID;"])
        #expect(await mock.chunkedResponse.isEmpty)
    }

    @Test func questionMarkThenAcceptedSucceeds() async throws {
        let (mock, proto) = try await make()
        await mock.setChunkedResponse([Self.ascii("?;"), Self.ascii("ID0670;"), Self.ascii("ID0670;")])
        try await proto.setPower(50)
        #expect(await sent(mock).count == 4)
    }

    @Test func nReplyThrowsUnsupportedWithoutRetry() async throws {
        let (mock, proto) = try await make()
        await mock.setChunkedResponse([Self.ascii("N;"), Self.ascii("ID0670;")])
        do {
            try await proto.setPower(50)
            Issue.record("expected a throw")
        } catch RigError.unsupportedOperation(_) {
        } catch {
            Issue.record("expected unsupportedOperation, got \(error)")
        }
        #expect(await sent(mock) == ["PC050;", "ID;"])
    }

    @Test func unsolicitedFrameBeforeIDIsSkipped() async throws {
        let (mock, proto) = try await make()
        await mock.setChunkedResponse([Self.ascii("FA014074000;"), Self.ascii("ID0670;")])
        try await proto.setPower(50)
        #expect(await sent(mock) == ["PC050;", "ID;"])
    }

    @Test func silentRadioTimesOut() async throws {
        let (mock, proto) = try await make()
        await mock.setShouldThrowOnRead(true)
        await #expect(throws: RigError.self) {
            try await proto.setPower(50)
        }
        #expect(await sent(mock) == ["PC050;", "ID;", "PC050;", "ID;"])
    }

    @Test func ftdx9000VerifiesWithAI() async throws {
        // newcat.c:10926-10927.
        #expect(RadioDefinition.Yaesu.ftdx9000.capabilities.powerControl)
        let mock = MockTransport()
        let proto = try #require(
            RadioDefinition.Yaesu.ftdx9000.createProtocol(transport: mock) as? YaesuCATProtocol
        )
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Self.ascii("AI;"), response: Self.ascii("AI0;"))
        try await proto.setPower(200)
        #expect(await sent(mock) == ["PC050;", "AI;"])
        #expect(YaesuCATProtocol.Quirks.newcatNoST.verifyCommand == "ID")
    }

    // MARK: - AC tuner drain (upstream 635d11fe)

    @Test func tuneIsDrainedThroughID() async throws {
        let (mock, proto) = try await make()
        try await proto.performVFOOperation(.tune)
        #expect(await sent(mock) == ["AC002;", "ID;"])
    }

    @Test func rejectedTuneThrowsAndIsNotResent() async throws {
        // A resent AC002; would start a second tune cycle.
        let (mock, proto) = try await make()
        await mock.setChunkedResponse([Self.ascii("?;"), Self.ascii("ID0670;")])
        do {
            try await proto.performVFOOperation(.tune)
            Issue.record("expected a throw")
        } catch RigError.commandFailed(_) {
        } catch {
            Issue.record("expected commandFailed, got \(error)")
        }
        #expect(await sent(mock) == ["AC002;", "ID;"])
        #expect(await mock.chunkedResponse.isEmpty, "ID reply must be consumed")
    }

    @Test func tunerFunctionUsesACDrain() async throws {
        let (mock, proto) = try await make()
        try await proto.setFunction(.tuner, enabled: true)
        let writes = await sent(mock)
        #expect(writes.first?.hasPrefix("AC") == true)
        #expect(writes.last == "ID;")
    }

    // MARK: - RIT readback

    @Test func getRITReadsIFAndNeverSendsRC() async throws {
        // RC; clears the clarifier (Hamlib newcat_set_rit); the offset
        // comes from IF; (newcat_get_rit, newcat.c:3011-3070).
        let (mock, proto) = try await make()
        await mock.setResponse(for: Self.ascii("RT;"), response: Self.ascii("RT1;"))
        await mock.setResponse(for: Self.ascii("IF;"),
                               response: Self.ascii("IF001014074000+0150000020000;"))
        let state = try await proto.getRIT()
        #expect(state.enabled)
        #expect(state.offset == 150)
        let writes = await sent(mock)
        #expect(writes == ["RT;", "IF;"])
    }

    @Test func ritOffsetParsesEightAndNineDigitRecords() throws {
        // FT-450 (8 digits, offset at 13) and FT-991 (9 digits, at 14).
        #expect(try YaesuCATProtocol.ritOffset(fromIF: "IF00114074000-0050000020000",
                                              frequencyDigits: 8) == -50)
        #expect(try YaesuCATProtocol.ritOffset(fromIF: "IF001014074000+9999000020000",
                                              frequencyDigits: 9) == 9999)
        #expect(throws: RigError.self) {
            try YaesuCATProtocol.ritOffset(fromIF: "IF001014074", frequencyDigits: 9)
        }
    }

    // MARK: - Power state (newcat_set_powerstat, newcat.c:3719-3800)

    @Test func powerOffIsWriteOnly() async throws {
        let (mock, proto) = try await make()
        await mock.setShouldThrowOnRead(true)
        try await proto.setPowerState(false)
        #expect(await sent(mock) == ["PS0;"])
    }

    @Test func powerOnSendsPS1TwiceThenWaitsForFA() async throws {
        // The first PS1; only wakes the radio; FA; polls until it answers.
        let (mock, proto) = try await make()
        await mock.setResponse(for: Self.ascii("FA;"), response: Self.ascii("FA014074000;"))
        try await proto.setPowerState(true)
        #expect(await sent(mock) == ["PS1;", "PS1;", "FA;"])
    }
}
