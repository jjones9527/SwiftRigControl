import Foundation
import Testing
@testable import RigControl

/// Yaesu newcat, Kenwood and Elecraft function / VFO-op bytes that
/// differed from Hamlib `91e7b97`, found by comparing both against the
/// same Hamlib simulator (`Scripts/hamlib-set-matrix.py --tx`, 2026-10-30).
@Suite struct TextProtocolHamlibFunctionWireTests {

    private static func ascii(_ s: String) -> Data { Data(s.utf8) }

    /// The first frame the protocol writes for `operation`, with every
    /// set verification (`ID;` / `AI;`) answered.
    private func firstWrite(_ radio: RadioDefinition,
                            replies: [String: String] = [:],
                            _ operation: (any CATProtocol) async throws -> Void) async throws -> String? {
        let mock = MockTransport()
        let proto = radio.createProtocol(transport: mock)
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID0670;"))
        await mock.setResponse(for: Self.ascii("AI;"), response: Self.ascii("AI0;"))
        for (query, reply) in replies {
            await mock.setResponse(for: Self.ascii(query), response: Self.ascii(reply))
        }
        try await operation(proto)
        return await mock.recordedWrites.first.map { String(decoding: $0, as: UTF8.self) }
    }

    private func setFunction(_ function: RigFunction, _ on: Bool) -> (any CATProtocol) async throws -> Void {
        { try await ($0 as! any SupportsFunctions).setFunction(function, enabled: on) }
    }

    private func vfoOp(_ op: VFOOperation) -> (any CATProtocol) async throws -> Void {
        { try await ($0 as! any SupportsVFOOperations).performVFOOperation(op) }
    }

    // MARK: - Yaesu newcat

    @Test func manualNotchIsBP00PlusThreeDigits() async throws {
        // newcat.c:6148 "BP00%03d"; we sent BP001.
        #expect(try await firstWrite(.Yaesu.ft991A, setFunction(.manualNotch, true)) == "BP00001;")
    }

    @Test func compressorDigitFormFollowsTheModel() async throws {
        // newcat.c:6354-6366.
        #expect(try await firstWrite(.Yaesu.ft991A, setFunction(.compressor, true)) == "PR01;")
        #expect(try await firstWrite(.Yaesu.ft950, setFunction(.compressor, true)) == "PR1;")
    }

    @Test func lockIsLK7AndLK4OnTheFTDX101() async throws {
        // newcat.c:6227-6243.
        #expect(try await firstWrite(.Yaesu.ftdx101D, setFunction(.lock, true)) == "LK7;")
        #expect(try await firstWrite(.Yaesu.ftdx101D, setFunction(.lock, false)) == "LK4;")
        #expect(try await firstWrite(.Yaesu.ft991A, setFunction(.lock, true)) == "LK1;")
    }

    @Test func lk4ReadsAsUnlocked() async throws {
        // newcat_get_func: 0 or 4 is off (newcat.c:6834).
        let mock = MockTransport()
        let proto = try #require(RadioDefinition.Yaesu.ftdx101D.createProtocol(transport: mock) as? YaesuCATProtocol)
        try await proto.connect()
        await mock.setResponse(for: Self.ascii("LK;"), response: Self.ascii("LK4;"))
        #expect(try await proto.getFunction(.lock) == false)
        await mock.setResponse(for: Self.ascii("LK;"), response: Self.ascii("LK7;"))
        #expect(try await proto.getFunction(.lock) == true)
    }

    @Test func tuneIsAC003OnTheFT710() async throws {
        // newcat.c:7563-7571.
        let replies = ["AC;": "AC003;"]
        #expect(try await firstWrite(.Yaesu.ft710, replies: replies, vfoOp(.tune)) == "AC003;")
        #expect(try await firstWrite(.Yaesu.ft991A, replies: replies, vfoOp(.tune)) == "AC002;")
    }

    @Test func copyIsVVOnTheFT450Only() async throws {
        // newcat.c:7575-7583 checks RIG_MODEL_FT450; the FT-450D is AB.
        #expect(try await firstWrite(.Yaesu.ft450, vfoOp(.copyVFO)) == "VV;")
        #expect(try await firstWrite(.Yaesu.ft450D, vfoOp(.copyVFO)) == "AB;")
    }

    // MARK: - Kenwood

    @Test func lockFormFollowsTheModel() async throws {
        // ts590.c:486, ts480.c:271, kenwood.c RIG_FUNC_LOCK.
        #expect(try await firstWrite(.Kenwood.ts590SG, setFunction(.lock, true)) == "LK10;")
        #expect(try await firstWrite(.Kenwood.ts480SAT, setFunction(.lock, true)) == "LK11;")
        #expect(try await firstWrite(.Kenwood.ts890S, setFunction(.lock, true)) == "LK1;")
    }

    @Test func tunerFormFollowsTheModel() async throws {
        // ts590.c:490, ts570.c:266, flex6xxx.c:1170.
        #expect(try await firstWrite(.Kenwood.ts590SG, setFunction(.tuner, true)) == "AC110;")
        #expect(try await firstWrite(.Kenwood.ts590SG, setFunction(.tuner, false)) == "AC000;")
        #expect(try await firstWrite(.Kenwood.ts570S, setFunction(.tuner, true)) == "AC 10;")
        #expect(try await firstWrite(.Flex.powerSDR, setFunction(.tuner, true)) == "ZZTU1;")
    }

    @Test func voxIsZZVEOnPowerSDRAndThetis() async throws {
        // flex6xxx.c:1162.
        #expect(try await firstWrite(.Flex.thetis, setFunction(.vox, true)) == "ZZVE1;")
        #expect(try await firstWrite(.Kenwood.ts590SG, setFunction(.vox, true)) == "VX1;")
    }

    @Test func tunerStateReadsTheTXDigit() async throws {
        // kenwood_get_func RIG_FUNC_TUNER: AC P1 P2 P3, P2 is the TX tuner.
        let mock = MockTransport()
        let proto = try #require(RadioDefinition.Kenwood.ts890S.createProtocol(transport: mock) as? KenwoodProtocol)
        try await proto.connect()
        await mock.setResponse(for: Self.ascii("AC;"), response: Self.ascii("AC110;"))
        #expect(try await proto.getFunction(.tuner) == true)
        await mock.setResponse(for: Self.ascii("AC;"), response: Self.ascii("AC100;"))
        #expect(try await proto.getFunction(.tuner) == false)
    }

    // MARK: - Elecraft

    @Test func k4HasThreePreampStages() async throws {
        // K4 caps: preamp 10/20/30 dB, PA1-PA3 by position.
        #expect(RadioDefinition.Elecraft.k4.capabilities.preampLevels == [10, 20, 30])
        #expect(try await firstWrite(.Elecraft.k4) {
            try await ($0 as! any SupportsPreamp).setPreamp(3)
        } == "PA3;")
    }
}
