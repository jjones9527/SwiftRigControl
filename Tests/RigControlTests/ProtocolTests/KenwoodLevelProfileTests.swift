import Foundation
import Testing
@testable import RigControl

/// Kenwood level wire formats per model, taken from the bytes Hamlib
/// sends for the same model (`Scripts/hamlib-set-matrix.py` against
/// Hamlib 2b5608a; `ts590.c`, `ts890s.c`, `ts2000.c`, `ts480.c`,
/// `kenwood.c`).
@Suite struct KenwoodLevelProfileTests {

    private static func ascii(_ s: String) -> Data { s.data(using: .ascii)! }

    private func connect(_ definition: RadioDefinition) async throws -> (MockTransport, KenwoodProtocol) {
        let mock = MockTransport()
        let proto = try #require(definition.createProtocol(transport: mock) as? KenwoodProtocol)
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID021;"))
        return (mock, proto)
    }

    /// Set frames only; the `ID;` verification after each set is dropped.
    private func sets(_ mock: MockTransport) async -> [String] {
        await mock.recordedWrites.map { String(data: $0, encoding: .ascii) ?? "" }.filter { $0 != "ID;" }
    }

    // MARK: - AGC

    @Test func agcCodesPerModel() async throws {
        let expected: [(RadioDefinition, [String])] = [
            (.Kenwood.ts590SG, ["GT00;", "GT05;", "GT10;", "GT20;"]),
            (.Kenwood.ts590S, ["GT00;", "GT05;", "GT10;", "GT20;"]),
            (.Kenwood.ts2000, ["GT000;", "GT005;", "GT010;", "GT020;"]),
            (.Kenwood.ts890S, ["GC0;", "GC3;", "GC2;", "GC1;"]),
        ]
        for (radio, frames) in expected {
            let (mock, proto) = try await connect(radio)
            for speed in [AGCSpeed.off, .fast, .medium, .slow] {
                try await proto.setAGC(speed)
            }
            #expect(await sets(mock) == frames, "\(radio.model)")
            await #expect(throws: RigError.self) { try await proto.setAGC(.auto) }
        }
    }

    @Test func ts480HasNoMediumAGC() async throws {
        let (mock, ts480) = try await connect(.Kenwood.ts480SAT)
        try await ts480.setAGC(.fast)
        try await ts480.setAGC(.slow)
        #expect(await sets(mock) == ["GT001;", "GT002;"])
        await #expect(throws: RigError.self) { try await ts480.setAGC(.medium) }
    }

    @Test func agcReadsMapLikeHamlib() async throws {
        let (mock, ts590) = try await connect(.Kenwood.ts590SG)
        // ts590_get_level: 0 off, <=5 fast, <=10 medium, else slow.
        for (reply, speed) in [("GT00;", AGCSpeed.off), ("GT03;", .fast), ("GT05;", .fast),
                               ("GT08;", .medium), ("GT15;", .slow), ("GT20;", .slow)] {
            await mock.setResponse(for: Self.ascii("GT;"), response: Self.ascii(reply))
            #expect(try await ts590.getAGC() == speed, "\(reply)")
        }
        let (mock890, ts890) = try await connect(.Kenwood.ts890S)
        await mock890.setResponse(for: Self.ascii("GC;"), response: Self.ascii("GC3;"))
        #expect(try await ts890.getAGC() == .fast)
    }

    // MARK: - Attenuator

    @Test func attenuatorIndexesEachModelsSteps() async throws {
        let (m590, ts590) = try await connect(.Kenwood.ts590SG)          // 12 only
        try await ts590.setAttenuator(12)
        #expect(await sets(m590) == ["RA01;"])
        await #expect(throws: RigError.self) { try await ts590.setAttenuator(6) }

        let (m890, ts890) = try await connect(.Kenwood.ts890S)           // 6/12/18, 1 digit
        try await ts890.setAttenuator(6)
        try await ts890.setAttenuator(18)
        try await ts890.setAttenuator(0)
        #expect(await sets(m890) == ["RA1;", "RA3;", "RA0;"])

        let (m990, ts990) = try await connect(.Kenwood.ts990S)           // 6/12/18
        try await ts990.setAttenuator(12)
        #expect(await sets(m990) == ["RA02;"])

        let (m570, ts570) = try await connect(.Kenwood.ts570D)           // 18 only
        try await ts570.setAttenuator(18)
        #expect(await sets(m570) == ["RA01;"])

        let (m500, tx500) = try await connect(.Lab599.tx500)             // 20 only
        try await tx500.setAttenuator(20)
        #expect(await sets(m500) == ["RA01;"])

        await m590.setResponse(for: Self.ascii("RA;"), response: Self.ascii("RA0100;"))
        #expect(try await ts590.getAttenuator() == 12)
    }

    // MARK: - Squelch, RF, NB

    @Test func ts890SquelchAndNoiseBlankerFormats() async throws {
        let (mock, ts890) = try await connect(.Kenwood.ts890S)
        try await ts890.setSquelch(127)
        try await ts890.setNoiseBlanker(.enabled(level: nil))
        try await ts890.setNoiseBlanker(.off)
        #expect(await sets(mock) == ["SQ127;", "NB11;", "NB10;"])
    }

    @Test func ts590SquelchKeepsReceiverDigit() async throws {
        let (mock, ts590) = try await connect(.Kenwood.ts590SG)
        try await ts590.setSquelch(127)
        try await ts590.setNoiseBlanker(.enabled(level: nil))
        #expect(await sets(mock) == ["SQ0127;", "NB1;"])
    }

    @Test func ts480RFGainIsZeroToHundred() async throws {
        let (mock, ts480) = try await connect(.Kenwood.ts480SAT)
        try await ts480.setRFGain(128)
        try await ts480.setRFGain(255)
        #expect(await sets(mock) == ["RG050;", "RG100;"])
    }

    // MARK: - Secondary levels (0-100 API)

    @Test func secondaryLevelScalesPerModel() async throws {
        let (m590, ts590SG) = try await connect(.Kenwood.ts590SG)
        try await ts590SG.setMonitorGain(50)
        try await ts590SG.setVOXGain(50)
        try await ts590SG.setCompressorLevel(50)
        #expect(await sets(m590) == ["ML010;", "VG004;", "PL050050;"])

        let (m2000, ts2000) = try await connect(.Kenwood.ts2000)
        try await ts2000.setMonitorGain(50)
        #expect(await sets(m2000) == ["ML004;"])

        let (m990, ts990) = try await connect(.Kenwood.ts990S)
        try await ts990.setCompressorLevel(50)
        #expect(await sets(m990) == ["PL127127;"])
    }

    // MARK: - Noise reduction

    @Test func noiseReductionLevelGoesOnRL() async throws {
        let (mock, ts590) = try await connect(.Kenwood.ts590SG)
        try await ts590.setNoiseReduction(.enabled(level: 255))
        try await ts590.setNoiseReduction(.off)
        #expect(await sets(mock) == ["NR1;", "RL09;", "NR0;"])

        await mock.setResponse(for: Self.ascii("NR;"), response: Self.ascii("NR1;"))
        await mock.setResponse(for: Self.ascii("RL;"), response: Self.ascii("RL09;"))
        #expect(try await ts590.getNoiseReduction() == .enabled(level: 255))
    }

    @Test func noiseReductionWithoutLevelIsOnOff() async throws {
        let (mock, ts890) = try await connect(.Kenwood.ts890S)
        try await ts890.setNoiseReduction(.enabled(level: 200))
        #expect(await sets(mock) == ["NR1;"])
    }
}
