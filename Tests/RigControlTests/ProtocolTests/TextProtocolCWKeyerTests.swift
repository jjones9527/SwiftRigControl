import Foundation
import Testing
@testable import RigControl

/// CW keyer and CW text on Yaesu newcat, Kenwood and Elecraft, as Hamlib
/// `91e7b97` sends them (checked on the Hamlib simulators with
/// `Scripts/hamlib-set-matrix.py --tx`, 2026-10-30).
@Suite struct TextProtocolCWKeyerTests {

    private static func ascii(_ s: String) -> Data { Data(s.utf8) }

    /// Every frame written for `operation`, with set verification and the
    /// `KY;` buffer poll answered.
    private func writes(_ radio: RadioDefinition,
                        _ operation: (any CATProtocol) async throws -> Void) async throws -> [String] {
        let mock = MockTransport()
        let proto = radio.createProtocol(transport: mock)
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID0670;"))
        await mock.setResponse(for: Self.ascii("AI;"), response: Self.ascii("AI0;"))
        await mock.setResponse(for: Self.ascii("KY;"), response: Self.ascii("KY0;"))
        try await operation(proto)
        return await mock.recordedWrites
            .map { String(decoding: $0, as: UTF8.self) }
            .filter { $0 != "ID;" && $0 != "AI;" }
    }

    private func keyer(_ p: any CATProtocol) -> any SupportsCWKeyer { p as! any SupportsCWKeyer }
    private func sender(_ p: any CATProtocol) -> any SupportsSendCW { p as! any SupportsSendCW }

    // MARK: - Speed and pitch

    @Test func keySpeedIsKS3Digits() async throws {
        for radio in [RadioDefinition.Yaesu.ft991A, .Kenwood.ts590SG, .Elecraft.k3] {
            #expect(try await writes(radio) { try await self.keyer($0).setCWSpeed(20) } == ["KS020;"], "\(radio.fullName)")
        }
    }

    @Test func yaesuPitchScaleFollowsTheModel() async throws {
        // KP = (hz - min + step/2) / step; newcat.c:4310-4323 + level_gran.
        #expect(try await writes(.Yaesu.ft991A) { try await self.keyer($0).setCWPitch(500) } == ["KP20;"])
        #expect(try await writes(.Yaesu.ft950) { try await self.keyer($0).setCWPitch(500) } == ["KP04;"])
        #expect(try await writes(.Yaesu.ft450) { try await self.keyer($0).setCWPitch(500) } == ["KP01;"])
    }

    @Test func kenwoodPitchFormFollowsTheModel() async throws {
        // ts590.c:679, ts480.c:437, kenwood.c:3658-3668.
        #expect(try await writes(.Kenwood.ts590SG) { try await self.keyer($0).setCWPitch(500) } == ["EX040000004;"])
        #expect(try await writes(.Kenwood.ts480SAT) { try await self.keyer($0).setCWPitch(500) } == ["EX034000002;"])
        #expect(try await writes(.Kenwood.ts890S) { try await self.keyer($0).setCWPitch(500) } == ["PT040;"])
        #expect(try await writes(.Kenwood.ts990S) { try await self.keyer($0).setCWPitch(750) } == ["PT045;"])
    }

    // MARK: - Break-in

    @Test func yaesuBreakInIsBI() async throws {
        #expect(try await writes(.Yaesu.ft991A) { try await self.keyer($0).setBreakIn(.full) } == ["BI1;"])
        #expect(try await writes(.Yaesu.ft991A) { try await self.keyer($0).setBreakIn(.off) } == ["BI0;"])
    }

    @Test func kenwoodBreakInIsTheDelay() async throws {
        // Hamlib RIG_FUNC_FBKIN: SD0000 / SD0050.
        #expect(try await writes(.Kenwood.ts590SG) { try await self.keyer($0).setBreakIn(.full) } == ["SD0000;"])
        #expect(try await writes(.Kenwood.ts590SG) { try await self.keyer($0).setBreakIn(.semi) } == ["SD0050;"])
        await #expect(throws: RigError.self) {
            _ = try await self.writes(.Kenwood.ts590SG) { try await self.keyer($0).setBreakIn(.off) }
        }
    }

    @Test func rigctldFullBreakInOffIsTheSemiDelayOnKenwood() async throws {
        let rig = try RigController(radio: .Kenwood.ts590SG, connection: .mock)
        try await rig.connect()
        let mock = await rig.rawProtocol.transport as! MockSerialTransport
        await mock.reset()
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID023;"))
        let response = await RigctldCommandHandler(rigController: rig).handle(.setFunc(name: "FBKIN", enabled: false))
        #expect(response.returnCode == .ok)
        #expect(await mock.recordedWrites.first == Self.ascii("SD0050;"))
    }

    // MARK: - CW text

    @Test func yaesuSendsThroughKeyerMemoryOne() async throws {
        // newcat_send_morse: KM1<text> then KY6; stored messages 1-5 play
        // as KY6-KYA, or KY1-KY5 on the FT-710.
        #expect(try await writes(.Yaesu.ft991A) { try await self.sender($0).sendCW("cq test") } == ["KM1CQ TEST;", "KY6;"])
        #expect(try await writes(.Yaesu.ft991A) { try await self.sender($0).sendCW("5") } == ["KYA;"])
        #expect(try await writes(.Yaesu.ft710) { try await self.sender($0).sendCW("3") } == ["KY3;"])
        await #expect(throws: RigError.self) {
            _ = try await self.writes(.Yaesu.ft450) { try await self.sender($0).sendCW("4") }   // FT-450: 1-3
        }
    }

    @Test func kenwoodTextFormFollowsTheModel() async throws {
        let pad = { (s: String) in s + String(repeating: " ", count: 24 - s.count) }
        #expect(try await writes(.Kenwood.ts590SG) { try await self.sender($0).sendCW("CQ") } == ["KY;", "KY " + pad("CQ") + ";"])
        #expect(try await writes(.Kenwood.ts590S) { try await self.sender($0).sendCW("CQ") }
                == ["KY;", "KY " + String(repeating: " ", count: 22) + "CQ;"])
        #expect(try await writes(.Kenwood.ts890S) { try await self.sender($0).sendCW("CQ") } == ["KY;", "KY2CQ;"])
        #expect(try await writes(.Kenwood.ts890S) { try await self.sender($0).stopCW() } == ["KY0;"])
    }

    @Test func longTextGoesOutIn24CharacterChunks() async throws {
        let text = String(repeating: "A", count: 30)
        let sent = try await writes(.Elecraft.k3) { try await self.sender($0).sendCW(text) }
        #expect(sent == ["KY;", "KY " + String(repeating: "A", count: 24) + ";", "KY;", "KY AAAAAA;"])
    }

    @Test func elecraftTextAndStopFollowTheModel() async throws {
        #expect(try await writes(.Elecraft.k3) { try await self.sender($0).sendCW("CQ") } == ["KY;", "KY CQ;"])
        #expect(try await writes(.Elecraft.k3) { try await self.sender($0).stopCW() } == ["KY \u{04};"])
        #expect(try await writes(.Elecraft.k4) { try await self.sender($0).stopCW() } == ["KY @;"])
    }

    // MARK: - Related

    @Test func powerSDRModeReplyMayHaveOneDigit() async throws {
        // Hamlib parses ZZMD with %d (flex6xxx.c:269).
        let mock = MockTransport()
        let proto = try #require(RadioDefinition.Flex.powerSDR.createProtocol(transport: mock) as? KenwoodProtocol)
        try await proto.connect()
        await mock.setResponse(for: Self.ascii("ZZMD;"), response: Self.ascii("ZZMD4;"))
        #expect(try await proto.getMode(vfo: .a) == .cw)
    }
}
