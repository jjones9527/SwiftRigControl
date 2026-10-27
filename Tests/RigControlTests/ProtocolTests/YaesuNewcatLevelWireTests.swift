import Foundation
import Testing
@testable import RigControl

/// Newcat level / function wire bytes, checked against what Hamlib sends
/// for the same models (found by Scripts/hamlib-diff-audit.py and
/// confirmed in `rigs/yaesu/newcat.c`).
@Suite struct YaesuNewcatLevelWireTests {

    private static func ascii(_ s: String) -> Data { s.data(using: .ascii)! }

    private func sent(_ mock: MockTransport) async -> [String] {
        await mock.recordedWrites.map { String(data: $0, encoding: .ascii) ?? "" }
    }

    private func connect(_ definition: RadioDefinition) async throws -> (MockTransport, YaesuCATProtocol) {
        let mock = MockTransport()
        let proto = try #require(definition.createProtocol(transport: mock) as? YaesuCATProtocol)
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID0800;"))
        return (mock, proto)
    }

    // MARK: - Queries carry the receiver digit (newcat.c:5061, 5189, 6646-6680)

    @Test func agcQueryIsGT0() async throws {
        let (mock, ft710) = try await connect(.Yaesu.ft710)
        await mock.setResponse(for: Self.ascii("GT0;"), response: Self.ascii("GT03;"))
        #expect(try await ft710.getAGC() == .slow)
        #expect(await sent(mock) == ["GT0;"])
    }

    @Test func attenuatorQueryIsRA0() async throws {
        let (mock, ft710) = try await connect(.Yaesu.ft710)
        await mock.setResponse(for: Self.ascii("RA0;"), response: Self.ascii("RA02;"))
        #expect(try await ft710.getAttenuator() == 12)
        #expect(await sent(mock) == ["RA0;"])
    }

    // MARK: - Attenuator indexes the model's list (newcat.c:4492-4533)

    @Test func attenuatorCodeFollowsEachRadiosStepList() async throws {
        let (mock710, ft710) = try await connect(.Yaesu.ft710)        // 6 / 12 / 18
        try await ft710.setAttenuator(12)
        try await ft710.setAttenuator(18)
        #expect(await sent(mock710) == ["RA02;", "ID;", "RA03;", "ID;"])

        let (mock991, ft991A) = try await connect(.Yaesu.ft991A)      // 12 only
        try await ft991A.setAttenuator(12)
        try await ft991A.setAttenuator(0)
        #expect(await sent(mock991) == ["RA01;", "ID;", "RA00;", "ID;"])
        await #expect(throws: RigError.self) { try await ft991A.setAttenuator(6) }

        await mock991.setResponse(for: Self.ascii("RA0;"), response: Self.ascii("RA01;"))
        #expect(try await ft991A.getAttenuator() == 12)

        let (mock450, ft450D) = try await connect(.Yaesu.ft450D)      // 20 only
        try await ft450D.setAttenuator(20)
        #expect(await sent(mock450) == ["RA01;", "ID;"])
    }

    // MARK: - Squelch / RF gain scales (Hamlib level_gran steps)

    @Test func squelchScalesToZeroToHundredRadios() async throws {
        let (mock, ft710) = try await connect(.Yaesu.ft710)
        try await ft710.setSquelch(77)          // 30% of 255
        #expect(await sent(mock) == ["SQ0030;", "ID;"])
        await mock.setResponse(for: Self.ascii("SQ0;"), response: Self.ascii("SQ0030;"))
        #expect(try await ft710.getSquelch() == 77)
    }

    @Test func squelchStaysZeroTo255OnOlderRadios() async throws {
        let (mock, ft450D) = try await connect(.Yaesu.ft450D)
        try await ft450D.setSquelch(77)
        #expect(await sent(mock) == ["SQ0077;", "ID;"])
    }

    @Test func ft891RFGainIsZeroToThirty() async throws {
        let (mock, ft891) = try await connect(.Yaesu.ft891)
        try await ft891.setRFGain(255)
        try await ft891.setRFGain(128)
        #expect(await sent(mock) == ["RG0030;", "ID;", "RG0015;", "ID;"])
        await mock.setResponse(for: Self.ascii("RG0;"), response: Self.ascii("RG0030;"))
        #expect(try await ft891.getRFGain() == 255)
    }

    // MARK: - NB / NR (newcat.c:6258-6330, RL level 4549-4590)

    @Test func noiseBlankerSetsAndReadsWithReceiverDigit() async throws {
        let (mock, ft710) = try await connect(.Yaesu.ft710)
        try await ft710.setNoiseBlanker(.enabled(level: nil))
        try await ft710.setNoiseBlanker(.off)
        #expect(await sent(mock) == ["NB01;", "ID;", "NB00;", "ID;"])
        await mock.setResponse(for: Self.ascii("NB0;"), response: Self.ascii("NB01;"))
        #expect(try await ft710.getNoiseBlanker() == .enabled(level: nil))
    }

    @Test func noiseReductionSetsStateThenLevel() async throws {
        let (mock, ft710) = try await connect(.Yaesu.ft710)
        try await ft710.setNoiseReduction(.enabled(level: 128))
        try await ft710.setNoiseReduction(.off)
        #expect(await sent(mock) == ["NR01;", "ID;", "RL008;", "ID;", "NR00;", "ID;"])
    }

    @Test func noiseReductionReadsStateAndLevel() async throws {
        let (mock, ft710) = try await connect(.Yaesu.ft710)
        await mock.setResponse(for: Self.ascii("NR0;"), response: Self.ascii("NR01;"))
        await mock.setResponse(for: Self.ascii("RL0;"), response: Self.ascii("RL015;"))
        #expect(try await ft710.getNoiseReduction() == .enabled(level: 255))
        #expect(await sent(mock) == ["NR0;", "RL0;"])
    }

    @Test func ft450NoiseReductionLevelTopsOutAtEleven() async throws {
        let (mock, ft450D) = try await connect(.Yaesu.ft450D)
        try await ft450D.setNoiseReduction(.enabled(level: 255))
        #expect(await sent(mock) == ["NR01;", "ID;", "RL011;", "ID;"])
    }

    // MARK: - Frequency read width (newcat_get_freq reads every digit)

    @Test func frequencyReadAcceptsAnyDigitWidth() async throws {
        let (mock, ft710) = try await connect(.Yaesu.ft710)
        await mock.setResponse(for: Self.ascii("FA;"), response: Self.ascii("FA07074100;"))
        #expect(try await ft710.getFrequency(vfo: .a) == 7_074_100)
        await mock.setResponse(for: Self.ascii("FA;"), response: Self.ascii("FA014074000;"))
        #expect(try await ft710.getFrequency(vfo: .a) == 14_074_000)
        await mock.setResponse(for: Self.ascii("FA;"), response: Self.ascii("FA01407X000;"))
        await #expect(throws: RigError.self) { try await ft710.getFrequency(vfo: .a) }
    }

    // MARK: - Quirks modifiers keep every field

    @Test func modifiersPreserveOtherFields() {
        let ftx1 = YaesuCATProtocol.Quirks.ftx1.withTargetableMode(false).withVerifyCommand("AI")
        #expect(ftx1.usesFTX1ClarifierCommands)
        #expect(!ftx1.hasTargetableMode)
        #expect(ftx1.verifyCommand == "AI")
        let scaled = ftx1.withLevelScales(squelchMax: 100)
        #expect(scaled.squelchMax == 100)
        #expect(scaled.usesFTX1ClarifierCommands)
        #expect(scaled.attenuatorSteps == [6, 12, 18])
    }
}
