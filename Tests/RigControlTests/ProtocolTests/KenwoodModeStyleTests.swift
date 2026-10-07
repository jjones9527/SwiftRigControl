import Foundation
import Testing
@testable import RigControl

/// Wire tests for Kenwood set-command verification and per-radio
/// DATA-mode handling (v1.2.18).
///
/// - Set commands get no reply on real Kenwood radios. `KenwoodProtocol`
///   follows each with `ID;`, as Hamlib `kenwood_transaction` does
///   (`kenwood.c:427-443`), and treats `?;` / `N;` / `E;` / `O;` as a
///   rejection (`kenwood.c:518-600`).
/// - DATA modes follow `KenwoodModeCommandStyle`: `MD` + `DA` on the
///   TS-590S/SG, `OM0<hex>` on the TS-990S, `SF` read-modify-write on the
///   TS-890S, `MD6` / `MD9` on Flex SmartSDR, and `ZZMD07` / `ZZMD09` on
///   PowerSDR / Thetis. Pre-fix code sent `MD12;` / `MD13;` everywhere.
@Suite struct KenwoodModeStyleTests {

    private func make(_ style: KenwoodModeCommandStyle) async throws -> (MockTransport, KenwoodProtocol) {
        let mock = MockTransport()
        let proto = KenwoodProtocol(transport: mock, capabilities: .full, modeStyle: style)
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID019;"))
        return (mock, proto)
    }

    private static func ascii(_ s: String) -> Data { s.data(using: .ascii)! }

    private func sent(_ mock: MockTransport) async -> [String] {
        await mock.recordedWrites.map { String(data: $0, encoding: .ascii) ?? "" }
    }

    // MARK: - ID; verification

    @Test func setCommandIsVerifiedWithID() async throws {
        let (mock, proto) = try await make(.standard)
        try await proto.setFrequency(14_074_000, vfo: .a)
        #expect(await sent(mock) == ["FA00014074000;", "ID;"])
    }

    @Test func questionMarkReplyThrowsCommandFailed() async throws {
        let (mock, proto) = try await make(.standard)
        // The rejection arrives first, then the ID reply, which must be
        // consumed so the next transaction starts clean.
        await mock.setChunkedResponse([Self.ascii("?;"), Self.ascii("ID019;")])
        await #expect(throws: RigError.self) {
            try await proto.setPower(50)
        }
        #expect(await mock.chunkedResponse.isEmpty)
    }

    @Test func nReplyThrowsUnsupported() async throws {
        let (mock, proto) = try await make(.standard)
        await mock.setChunkedResponse([Self.ascii("N;"), Self.ascii("ID019;")])
        do {
            try await proto.setSplit(true)
            Issue.record("expected a throw")
        } catch RigError.unsupportedOperation(_) {
        } catch {
            Issue.record("expected unsupportedOperation, got \(error)")
        }
    }

    @Test func unsolicitedAutoInfoIsSkipped() async throws {
        // Hamlib skips an unexpected FA / FB while waiting for the
        // verification reply (kenwood.c:691-696).
        let (mock, proto) = try await make(.standard)
        await mock.setChunkedResponse([Self.ascii("FA00014074000;"), Self.ascii("ID019;")])
        try await proto.setMode(.usb, vfo: .a)
        #expect(await sent(mock) == ["MD2;", "ID;"])
    }

    // MARK: - TS-590S / TS-590SG: MD + DA

    @Test func dataSubModeSetsDA1ForDataUSB() async throws {
        let (mock, proto) = try await make(.dataSubMode)
        try await proto.setMode(.dataUSB, vfo: .a)
        #expect(await sent(mock) == ["MD2;", "ID;", "DA1;", "ID;"])
    }

    @Test func dataSubModeClearsDAForVoiceSSB() async throws {
        let (mock, proto) = try await make(.dataSubMode)
        try await proto.setMode(.lsb, vfo: .a)
        #expect(await sent(mock) == ["MD1;", "ID;", "DA0;", "ID;"])
    }

    @Test func dataSubModeSkipsDAForCW() async throws {
        let (mock, proto) = try await make(.dataSubMode)
        try await proto.setMode(.cw, vfo: .a)
        #expect(await sent(mock) == ["MD3;", "ID;"])
    }

    @Test func dataSubModeReadsDA() async throws {
        let (mock, proto) = try await make(.dataSubMode)
        await mock.setResponse(for: Self.ascii("MD;"), response: Self.ascii("MD1;"))
        await mock.setResponse(for: Self.ascii("DA;"), response: Self.ascii("DA1;"))
        #expect(try await proto.getMode(vfo: .a) == .dataLSB)
    }

    // MARK: - TS-990S: OM0<hex>

    @Test func operatingModeSendsHexDataCode() async throws {
        // ts990s.c:106-108 — C = LSB-D1, D = USB-D1, E = FM-D1.
        let (mock, proto) = try await make(.operatingMode)
        try await proto.setMode(.dataUSB, vfo: .a)
        try await proto.setMode(.usb, vfo: .a)
        #expect(await sent(mock) == ["OM0D;", "ID;", "OM02;", "ID;"])
    }

    @Test func operatingModeReadsDataProfiles() async throws {
        let (mock, proto) = try await make(.operatingMode)
        await mock.setResponse(for: Self.ascii("OM0;"), response: Self.ascii("OM0C;"))
        #expect(try await proto.getMode(vfo: .a) == .dataLSB)
        // DATA-2 profile (H = USB-D2) reads back as DATA-USB.
        await mock.setResponse(for: Self.ascii("OM0;"), response: Self.ascii("OM0H;"))
        #expect(try await proto.getMode(vfo: .a) == .dataUSB)
    }

    // MARK: - TS-890S: SF read-modify-write

    @Test func setFrequencyAndModeRewritesSFRecord() async throws {
        // kenwood.c:2602-2630 — mode character at offset 14.
        let (mock, proto) = try await make(.setFrequencyAndMode)
        await mock.setResponse(for: Self.ascii("SF0;"),
                               response: Self.ascii("SF0000140740002000;"))
        try await proto.setMode(.dataUSB, vfo: .a)
        #expect(await sent(mock) == ["SF0;", "SF000014074000D000;", "ID;"])
    }

    @Test func setFrequencyAndModeReadsVFOB() async throws {
        let (mock, proto) = try await make(.setFrequencyAndMode)
        await mock.setResponse(for: Self.ascii("SF1;"),
                               response: Self.ascii("SF1000070740001000;"))
        #expect(try await proto.getMode(vfo: .b) == .lsb)
    }

    // MARK: - Flex SmartSDR: MD6 / MD9

    @Test func flexDigitalUsesDIGLAndDIGU() async throws {
        let (mock, proto) = try await make(.flexDigital)
        try await proto.setMode(.dataUSB, vfo: .a)
        try await proto.setMode(.dataLSB, vfo: .a)
        #expect(await sent(mock) == ["MD9;", "ID;", "MD6;", "ID;"])
    }

    @Test func flexDigitalRejectsRTTY() async throws {
        // flex6xxx.c:58-70 has no RTTY or CW-R.
        let (_, proto) = try await make(.flexDigital)
        await #expect(throws: RigError.self) {
            try await proto.setMode(.rtty, vfo: .a)
        }
    }

    @Test func flexDigitalReadsDIGL() async throws {
        let (mock, proto) = try await make(.flexDigital)
        await mock.setResponse(for: Self.ascii("MD;"), response: Self.ascii("MD6;"))
        #expect(try await proto.getMode(vfo: .a) == .dataLSB)
    }

    // MARK: - PowerSDR / Thetis: ZZMD

    @Test func powerSDRUsesZZMD() async throws {
        let (mock, proto) = try await make(.powerSDR)
        try await proto.setMode(.dataUSB, vfo: .a)
        try await proto.setMode(.usb, vfo: .a)
        #expect(await sent(mock) == ["ZZMD07;", "ID;", "ZZMD01;", "ID;"])
    }

    @Test func powerSDRReadsZZMD() async throws {
        let (mock, proto) = try await make(.powerSDR)
        await mock.setResponse(for: Self.ascii("ZZMD;"), response: Self.ascii("ZZMD09;"))
        #expect(try await proto.getMode(vfo: .a) == .dataLSB)
    }

    // MARK: - Catalog wiring

    @Test(arguments: [
        ("TS-890S", KenwoodModeCommandStyle.setFrequencyAndMode),
        ("TS-990S", KenwoodModeCommandStyle.operatingMode),
        ("TS-590SG", KenwoodModeCommandStyle.dataSubMode),
        ("TS-590S", KenwoodModeCommandStyle.dataSubMode),
        ("TS-2000", KenwoodModeCommandStyle.standard),
        ("TS-480SAT", KenwoodModeCommandStyle.standard),
    ])
    func kenwoodCatalogStyles(model: String, style: KenwoodModeCommandStyle) async throws {
        let radio = try #require(RadioDefinition.Kenwood.allRadios.first { $0.model == model })
        let proto = try #require(radio.createProtocol(transport: MockTransport()) as? KenwoodProtocol)
        #expect(await proto.modeStyle == style)
    }

    @Test func flexCatalogStyles() async throws {
        let expected: [(RadioDefinition, KenwoodModeCommandStyle)] = [
            (.Flex.flex6000, .flexDigital),
            (.Flex.powerSDR, .powerSDR),
            (.Flex.thetis, .powerSDR),
            (.Flex.sdrConsole, .standard),
            (.Flex.pihpsdr, .standard),
        ]
        for (radio, style) in expected {
            let proto = try #require(radio.createProtocol(transport: MockTransport()) as? KenwoodProtocol)
            #expect(await proto.modeStyle == style, "\(radio.model)")
        }
    }

    @Test func advertisedDataModesMatchStyle() async throws {
        // A radio must not advertise DATA modes its style rejects.
        let radios = RadioDefinition.Kenwood.allRadios + RadioDefinition.Flex.allRadios
            + RadioDefinition.Lab599.allRadios
        for radio in radios {
            guard let proto = radio.createProtocol(transport: MockTransport()) as? KenwoodProtocol else {
                continue  // TH / TM handhelds use other protocols
            }
            let style = await proto.modeStyle
            for mode in radio.capabilities.supportedModes {
                // `.dataSubMode` sets DATA modes as the voice base mode
                // plus `DA1;`, so check the base mode's code.
                let probe = style == .dataSubMode
                    ? KenwoodProtocol.splitDataMode(mode).base : mode
                #expect(
                    (try? KenwoodProtocol.modeCode(for: probe, style: style)) != nil
                        || mode == .fmN,
                    "\(radio.model) advertises \(mode.rawValue) but \(style) cannot set it"
                )
            }
        }
    }
}
