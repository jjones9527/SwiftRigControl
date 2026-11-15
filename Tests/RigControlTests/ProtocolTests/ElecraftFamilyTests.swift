import Foundation
import Testing
@testable import RigControl

/// Locks the K2 / K3-family split. Through v1.3.1 `isK2` was
/// `maxPower <= 15`, so the 12 W KX2 and 15 W KX3 got K2 timing,
/// unverified sets and K2 level codes. Hamlib drives them from `k3.c`.
@Suite struct ElecraftFamilyTests {

    private static func ascii(_ s: String) -> Data { s.data(using: .ascii)! }
    private static let idQuery = ascii("ID;")
    private static let idReply = ascii("ID017;")

    private func connect(_ definition: RadioDefinition) async throws -> (MockTransport, ElecraftProtocol) {
        let mock = MockTransport()
        let proto = try #require(definition.createProtocol(transport: mock) as? ElecraftProtocol)
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Self.idQuery, response: Self.idReply)
        await mock.setResponse(for: Self.ascii("RVM;"), response: Self.ascii("RVM04.36;"))
        return (mock, proto)
    }

    private func sent(_ mock: MockTransport) async -> [String] {
        await mock.recordedWrites.map { String(data: $0, encoding: .ascii) ?? "" }
    }

    static let k3Family: [RadioDefinition] = [
        .Elecraft.k3, .Elecraft.k3S, .Elecraft.k4, .Elecraft.kx2, .Elecraft.kx3,
    ]

    // MARK: - Family identity

    @Test func factoriesUseTheirHamlibFamily() async throws {
        let (_, k2) = try await connect(.Elecraft.k2)
        #expect(k2.family == .k2)
        for definition in Self.k3Family {
            let (_, proto) = try await connect(definition)
            let expected: ElecraftProtocol.Family = definition.model.hasPrefix("KX") ? .kx : .k3
            #expect(proto.family == expected, "\(definition.model)")
        }
    }

    @Test func inferenceNoLongerTakesKXRadiosForK2() {
        typealias Caps = RadioCapabilitiesDatabase.Elecraft
        #expect(ElecraftProtocol.inferredFamily(for: Caps.k2) == .k2)
        #expect(ElecraftProtocol.inferredFamily(for: Caps.kx2) == .kx)
        #expect(ElecraftProtocol.inferredFamily(for: Caps.kx3) == .kx)
        #expect(ElecraftProtocol.inferredFamily(for: Caps.k3) == .k3)
        #expect(ElecraftProtocol.inferredFamily(for: Caps.k4) == .k3)
    }

    @Test(arguments: ["KX2", "KX3"])
    func kxRadiosUseK3Timeout(model: String) async throws {
        let definition = try #require(Self.k3Family.first { $0.model == model })
        let (_, proto) = try await connect(definition)
        // Hamlib k3.c: `.timeout = 1000`, `.post_write_delay = 0`.
        #expect(await proto.responseTimeout == 1.0)
        let (_, k2) = try await connect(.Elecraft.k2)
        #expect(await k2.responseTimeout == 2.0)
    }

    @Test func kx3SetCommandsAreVerifiedWithID() async throws {
        let (mock, kx3) = try await connect(.Elecraft.kx3)
        try await kx3.setFrequency(7_074_000, vfo: .a)
        #expect(await sent(mock) == ["FA00007074000;", "ID;"])
    }

    @Test func kx3RejectedSetThrows() async throws {
        let (mock, kx3) = try await connect(.Elecraft.kx3)
        await mock.setChunkedResponse([Self.ascii("?;"), Self.idReply])
        await #expect(throws: RigError.self) {
            try await kx3.setFrequency(7_074_000, vfo: .a)
        }
    }

    @Test func k2SetCommandsStayUnverified() async throws {
        // The hardware-verified K2 path is unchanged (ROADMAP 5.8.1).
        let (mock, k2) = try await connect(.Elecraft.k2)
        try await k2.setFrequency(7_074_000, vfo: .a)
        #expect(await sent(mock) == ["FA00007074000;"])
    }

    // MARK: - Power (watts on every Elecraft)

    @Test func kx2PowerIsWatts() async throws {
        let (mock, kx2) = try await connect(.Elecraft.kx2)
        try await kx2.setPower(10)
        try await kx2.setPower(50)   // clamped to the KX2's 12 W
        #expect(await sent(mock) == ["PC010;", "ID;", "PC012;", "ID;"])

        await mock.setResponse(for: Self.ascii("PC;"), response: Self.ascii("PC010;"))
        #expect(try await kx2.getPower() == 10)
    }

    @Test func k3PowerWireIsUnchanged() async throws {
        let (mock, k3) = try await connect(.Elecraft.k3)
        try await k3.setPower(50)
        #expect(await sent(mock) == ["PC050;", "ID;"])
        await mock.setResponse(for: Self.ascii("PC;"), response: Self.ascii("PC050;"))
        #expect(try await k3.getPower() == 50)
    }

    /// A radio left in K22 extended mode replies `PCnnnx` (k3.c:2333-2352).
    @Test func extendedPowerRepliesAreRead() async throws {
        let (mock, kx3) = try await connect(.Elecraft.kx3)
        await mock.setResponse(for: Self.ascii("PC;"), response: Self.ascii("PC0500;"))
        #expect(try await kx3.getPower() == 5)
        await mock.setResponse(for: Self.ascii("PC;"), response: Self.ascii("PC1001;"))
        #expect(try await kx3.getPower() == 100)
        await mock.setResponse(for: Self.ascii("PC;"), response: Self.ascii("PC0502;"))
        await #expect(throws: RigError.self) { _ = try await kx3.getPower() }
    }

    // MARK: - S-meter

    @Test(arguments: ["K3", "K3S", "K4", "KX2", "KX3"])
    func k3FamilyReadsSM(model: String) async throws {
        let definition = try #require(Self.k3Family.first { $0.model == model })
        let (mock, proto) = try await connect(definition)
        await mock.setResponse(for: Self.ascii("SM;"), response: Self.ascii("SM0012;"))
        let strength = try await proto.getSignalStrength()
        #expect(await sent(mock) == ((model == "K3" || model == "K3S") ? ["RVM;", "SM;"] : ["SM;"]))
        #expect(strength.raw == 12)
    }

    @Test(arguments: [(0, -54), (1, -42), (2, -36), (3, -24), (4, -12), (5, -6),
                      (6, 0), (7, 10), (8, 15), (9, 20), (10, 30), (11, 35),
                      (12, 40), (13, 50), (14, 55), (15, 60), (21, 60)])
    func standardSMCalibration(raw: Int, dB: Int) async throws {
        for definition in Self.k3Family {
            let (mock, proto) = try await connect(definition)
            await mock.setResponse(for: Self.ascii("SM;"), response: Self.ascii(String(format: "SM%04d;", raw)))
            let strength = try await proto.getSignalStrength()
            #expect(strength.calibratedDBRelativeToS9 == dB)
            #expect(strength.raw == raw)
        }
    }

    @Test(arguments: ["SM012;", "SM00012;", "SM-012;", "SM 012;", "SM00x2;", "SMH012;"])
    func standardSMRejectsMalformedReplies(reply: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k3)
        await mock.setResponse(for: Self.ascii("SM;"), response: Self.ascii(reply))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getSignalStrength() }
    }

    @Test func rigctldK3StrengthUsesCalibratedDB() async throws {
        let rig = try RigController(radio: .Elecraft.k3, connection: .mock)
        try await rig.connect()
        let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
        await mock.setResponse(for: Self.ascii("RVM;"), response: Self.ascii("RVM04.36;"))
        await mock.setResponse(for: Self.ascii("SM;"), response: Self.ascii("SM0004;"))
        let handler = RigctldCommandHandler(rigController: rig)
        #expect(await handler.handle(.getLevel(name: "STRENGTH")).data == ["-12"])
    }

    @Test(arguments: ["RVM04.37;", "RVM04.67;", "RVM05.00;"])
    func highResolutionFirmwareAndCache(reply: String) async throws {
        for radio in [RadioDefinition.Elecraft.k3, .Elecraft.k3S] {
            let (mock, proto) = try await connect(radio)
            await mock.setResponse(for: Self.ascii("RVM;"), response: Self.ascii(reply))
            await mock.setResponse(for: Self.ascii("SMH;"), response: Self.ascii("SMH042;"))
            #expect(try await proto.getSignalStrength().calibratedDBRelativeToS9 == 0)
            #expect(try await proto.getSignalStrength().sUnits == 9)
            #expect(await sent(mock) == ["RVM;", "SMH;", "SMH;"])
            await proto.disconnect()
            try await proto.connect()
            await mock.reset()
            await mock.setResponse(for: Self.ascii("RVM;"), response: Self.ascii("RVM04.36;"))
            await mock.setResponse(for: Self.ascii("SM;"), response: Self.ascii("SM0006;"))
            #expect(try await proto.getSignalStrength().sUnits == 9)
            #expect(await sent(mock) == ["RVM;", "SM;"])
        }
    }

    @Test(arguments: [(0, -54), (5, -48), (14, -36), (42, 0), (50, 7), (83, 40), (103, 60), (106, 60)])
    func highResolutionCalibration(raw: Int, dB: Int) async throws {
        let (mock, proto) = try await connect(.Elecraft.k3)
        await mock.setResponse(for: Self.ascii("RVM;"), response: Self.ascii("RVM04.37;"))
        await mock.setResponse(for: Self.ascii("SMH;"), response: Self.ascii(String(format: "SMH%03d;", raw)))
        let strength = try await proto.getSignalStrength()
        #expect(strength.raw == raw)
        #expect(strength.calibratedDBRelativeToS9 == dB)
    }

    @Test(arguments: ["RVM4.37;", "RVD04.37;", "RVM04.x7;", "RVM04.370;"])
    func rejectsInvalidFirmwareAndRetries(reply: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k3)
        await mock.setResponse(for: Self.ascii("RVM;"), response: Self.ascii(reply))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getSignalStrength() }
        await mock.setResponse(for: Self.ascii("RVM;"), response: Self.ascii("?;"))
        await mock.setResponse(for: Self.ascii("SM;"), response: Self.ascii("SM0006;"))
        #expect(try await proto.getSignalStrength().sUnits == 9)
    }

    @Test(arguments: ["SMH42;", "SMH0042;", "SMH-42;", "SMH0x2;", "SM0042;"])
    func rejectsInvalidHighResolutionMeter(reply: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k3)
        await mock.setResponse(for: Self.ascii("RVM;"), response: Self.ascii("RVM04.37;"))
        await mock.setResponse(for: Self.ascii("SMH;"), response: Self.ascii(reply))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getSignalStrength() }
    }

    // MARK: - AGC (Hamlib k3.c:1939-1962, 2180-2207)

    @Test func k3FamilyAGCCodes() async throws {
        for definition in Self.k3Family {
            let (mock, proto) = try await connect(definition)
            try await proto.setAGC(.off)
            try await proto.setAGC(.fast)
            try await proto.setAGC(.medium)
            try await proto.setAGC(.slow)
            #expect(await sent(mock) == ["GT000;", "ID;", "GT002;", "ID;", "GT004;", "ID;", "GT004;", "ID;"],
                    "\(definition.model)")
            await #expect(throws: RigError.self) { try await proto.setAGC(.auto) }
        }
    }

    @Test func k3FamilyAGCReadback() async throws {
        let (mock, kx3) = try await connect(.Elecraft.kx3)
        for (reply, expected) in [("GT000;", AGCSpeed.off), ("GT002;", .fast), ("GT004;", .slow)] {
            await mock.setResponse(for: Self.ascii("GT;"), response: Self.ascii(reply))
            #expect(try await kx3.getAGC() == expected)
        }
        await mock.setResponse(for: Self.ascii("GT;"), response: Self.ascii("GT001;"))
        await #expect(throws: RigError.self) { try await kx3.getAGC() }
    }

    @Test func k2AGCCodesAreUnchanged() async throws {
        let (mock, k2) = try await connect(.Elecraft.k2)
        try await k2.setAGC(.fast)
        try await k2.setAGC(.slow)
        #expect(await sent(mock) == ["GT000;", "GT001;"])
    }

    // MARK: - Attenuator

    @Test func k3FamilyAttenuatorIsTenDB() async throws {
        let (mock, kx3) = try await connect(.Elecraft.kx3)
        try await kx3.setAttenuator(20)   // no second step on the K3 family
        #expect(await sent(mock) == ["RA01;", "ID;"])
        await mock.setResponse(for: Self.ascii("RA;"), response: Self.ascii("RA01;"))
        #expect(try await kx3.getAttenuator() == 10)
    }

    @Test func k2AttenuatorKeepsSecondStep() async throws {
        let (mock, k2) = try await connect(.Elecraft.k2)
        try await k2.setAttenuator(20)
        #expect(await sent(mock) == ["RA02;"])
        await mock.setResponse(for: Self.ascii("RA;"), response: Self.ascii("RA02;"))
        #expect(try await k2.getAttenuator() == 20)
    }

    @Test(arguments: [0, 3, 6, 9, 12, 15, 18, 21])
    func k4AttenuationUsesDBAndEnable(dB: Int) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        try await proto.setAttenuator(dB)
        let frame = String(format: "RA%02d%d;", dB, dB == 0 ? 0 : 1)
        #expect(await sent(mock) == [frame, "ID;"])
        await mock.setResponse(for: Self.ascii("RA;"), response: Self.ascii(frame))
        #expect(try await proto.getAttenuator() == dB)
        await mock.setResponse(for: Self.ascii("RA;"), response: Self.ascii(String(format: "RA%02d0;", dB)))
        #expect(try await proto.getAttenuator() == 0)
    }

    @Test(arguments: [-1, 1, 5, 10, 20, 22, 24])
    func k4RejectsUnsupportedAttenuation(dB: Int) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await #expect(throws: RigError.self) { try await proto.setAttenuator(dB) }
        #expect(await sent(mock).isEmpty)
    }

    @Test(arguments: ["RA01;", "RA0151;", "RA151x;", "RA152;", "RA241;", "RA101;", "RA-31;", "RB151;"])
    func k4RejectsMalformedAttenuation(reply: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("RA;"), response: Self.ascii(reply))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getAttenuator() }
    }

    @Test(arguments: [(0, 0, 60), (127, 30, 30), (255, 60, 0)])
    func k4GainUsesNativeScales(level: Int, audio: Int, reduction: Int) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        try await proto.setAFGain(level)
        try await proto.setRFGain(level)
        let af = String(format: "AG%03d;", audio)
        let rf = String(format: "RG-%02d;", reduction)
        #expect(await sent(mock) == [af, "ID;", rf, "ID;"])
        await mock.setResponse(for: Self.ascii("AG;"), response: Self.ascii(af))
        await mock.setResponse(for: Self.ascii("RG;"), response: Self.ascii(rf))
        let expected = level == 127 ? 128 : level
        #expect(try await proto.getAFGain() == expected)
        #expect(try await proto.getRFGain() == expected)
    }

    @Test(arguments: ["AG061;", "AG250;", "AG60;", "AG0060;", "AG-01;", "AG0x1;"])
    func k4RejectsInvalidAFGain(reply: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("AG;"), response: Self.ascii(reply))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getAFGain() }
    }

    @Test(arguments: ["RG-61;", "RG250;", "RG+00;", "RG-0;", "RG-000;", "RG-x0;"])
    func k4RejectsInvalidRFGain(reply: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("RG;"), response: Self.ascii(reply))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFGain() }
    }

    @Test(arguments: [0, 33, 50, 100])
    func microphoneGainUsesModelScale(level: Int) async throws {
        for definition in Self.k3Family {
            let (mock, proto) = try await connect(definition)
            let maximum = ["K3", "K3S"].contains(definition.model) ? 60 : 80
            let raw = level * maximum / 100
            let frame = String(format: "MG%03d;", raw)
            try await proto.setMicGain(level)
            #expect(await sent(mock) == [frame, "ID;"])
            await mock.setResponse(for: Self.ascii("MG;"), response: Self.ascii(frame))
            #expect(try await proto.getMicGain() == (raw * 100 + maximum / 2) / maximum)
        }
    }

    @Test(arguments: ["MG081;", "MG999;", "MG80;", "MG0080;", "MG-01;", "MG0x1;", "AG080;"])
    func microphoneGainRejectsMalformedReplies(reply: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("MG;"), response: Self.ascii(reply))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getMicGain() }
    }

    @Test func k3MicrophoneGainRejectsKXRange() async throws {
        let (mock, proto) = try await connect(.Elecraft.k3)
        await mock.setResponse(for: Self.ascii("MG;"), response: Self.ascii("MG061;"))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getMicGain() }
    }

    @Test func k2MicrophoneGainIsUnavailableWithoutCommands() async throws {
        let (mock, proto) = try await connect(.Elecraft.k2)
        await #expect(throws: RigError.self) { try await proto.setMicGain(50) }
        await #expect(throws: RigError.self) { _ = try await proto.getMicGain() }
        #expect(await sent(mock).isEmpty)
    }

    @Test func rigctldElecraftMicrophoneGain() async throws {
        for definition in Self.k3Family {
            let rig = try RigController(radio: definition, connection: .mock)
            try await rig.connect()
            let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
            let raw = ["K3", "K3S"].contains(definition.model) ? 30 : 40
            await mock.setResponse(for: Self.ascii("MG;"), response: Self.ascii(String(format: "MG%03d;", raw)))
            let handler = RigctldCommandHandler(rigController: rig)
            #expect(await handler.handle(.getLevel(name: "MICGAIN")).data == ["0.500000"])
        }
    }

    @Test(arguments: [0, 33, 50, 100])
    func compressorLevelUsesModelScale(level: Int) async throws {
        for definition in Self.k3Family {
            let (mock, proto) = try await connect(definition)
            let maximum = definition.model == "K4" ? 30 : 40
            let raw = level * maximum / 100
            let frame = String(format: "CP%03d;", raw)
            try await proto.setCompressorLevel(level)
            #expect(await sent(mock) == [frame, "ID;"])
            await mock.setResponse(for: Self.ascii("CP;"), response: Self.ascii(frame))
            #expect(try await proto.getCompressorLevel() == (raw * 100 + maximum / 2) / maximum)
        }
    }

    @Test(arguments: ["CP041;", "CP999;", "CP30;", "CP0030;", "CP-01;", "CP0x1;", "MG030;"])
    func compressorRejectsInvalidReplies(reply: String) async throws {
        for definition in Self.k3Family {
            let (mock, proto) = try await connect(definition)
            await mock.setResponse(for: Self.ascii("CP;"), response: Self.ascii(reply))
            await #expect(throws: RigError.invalidResponse) { _ = try await proto.getCompressorLevel() }
        }
    }

    @Test func k4CompressorRejectsK3Maximum() async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("CP;"), response: Self.ascii("CP040;"))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getCompressorLevel() }
    }

    @Test func k2CompressorLevelSendsNoCommands() async throws {
        let (mock, proto) = try await connect(.Elecraft.k2)
        await #expect(throws: RigError.self) { try await proto.setCompressorLevel(50) }
        await #expect(throws: RigError.self) { _ = try await proto.getCompressorLevel() }
        #expect(await sent(mock).isEmpty)
    }

    @Test func rigctldElecraftCompressorLevel() async throws {
        for definition in Self.k3Family {
            let rig = try RigController(radio: definition, connection: .mock)
            try await rig.connect()
            let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
            let raw = definition.model == "K4" ? 15 : 20
            await mock.setResponse(for: Self.ascii("CP;"), response: Self.ascii(String(format: "CP%03d;", raw)))
            let handler = RigctldCommandHandler(rigController: rig)
            #expect(await handler.handle(.getLevel(name: "COMP")).data == ["0.500000"])
        }
    }

    @Test(arguments: [(0, 0, 0), (33, 19, 32), (50, 30, 50), (100, 60, 100)])
    func monitorGainUsesCurrentModeScale(level: Int, raw: Int, readback: Int) async throws {
        for definition in Self.k3Family {
            let (mock, proto) = try await connect(definition)
            let frame = String(format: "ML%03d;", raw)
            try await proto.setMonitorGain(level)
            #expect(await sent(mock) == [frame, "ID;"])
            await mock.setResponse(for: Self.ascii("ML;"), response: Self.ascii(frame))
            #expect(try await proto.getMonitorGain() == readback)
        }
    }

    @Test(arguments: ["ML061;", "ML999;", "ML60;", "ML0060;", "ML-01;", "ML0x1;", "MG060;"])
    func monitorGainRejectsInvalidReplies(reply: String) async throws {
        for definition in Self.k3Family {
            let (mock, proto) = try await connect(definition)
            await mock.setResponse(for: Self.ascii("ML;"), response: Self.ascii(reply))
            await #expect(throws: RigError.invalidResponse) { _ = try await proto.getMonitorGain() }
        }
    }

    @Test func k2MonitorGainSendsNoCommands() async throws {
        let (mock, proto) = try await connect(.Elecraft.k2)
        await #expect(throws: RigError.self) { try await proto.setMonitorGain(50) }
        await #expect(throws: RigError.self) { _ = try await proto.getMonitorGain() }
        #expect(await sent(mock).isEmpty)
    }

    @Test func rigctldElecraftMonitorGain() async throws {
        for definition in Self.k3Family {
            let rig = try RigController(radio: definition, connection: .mock)
            try await rig.connect()
            let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
            await mock.setResponse(for: Self.ascii("ML;"), response: Self.ascii("ML030;"))
            let handler = RigctldCommandHandler(rigController: rig)
            #expect(await handler.handle(.getLevel(name: "MONITOR_GAIN")).data == ["0.500000"])
        }
    }

    @Test(arguments: [0, 5, 10])
    func k4NoiseReductionLevelAndState(level: Int) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        let on = String(format: "NR%02d1;", level)
        let off = String(format: "NR%02d0;", level)
        try await proto.setNoiseReduction(.enabled(level: level))
        #expect(await sent(mock) == [on, "ID;"])
        await mock.setResponse(for: Self.ascii("NR;"), response: Self.ascii(on))
        #expect(try await proto.getNoiseReduction() == .enabled(level: level))
        try await proto.setNoiseReduction(.off)
        #expect(await sent(mock).suffix(3) == ["NR;", off, "ID;"])
        await mock.setResponse(for: Self.ascii("NR;"), response: Self.ascii(off))
        #expect(try await proto.getNoiseReduction() == .off)
        #expect(try await proto.getNoiseReductionLevel() == Double(level) / 10)
        try await proto.setNoiseReductionLevel(0.7)
        #expect(await sent(mock).suffix(3) == ["NR;", "NR070;", "ID;"])
    }

    @Test(arguments: ["NR1;", "NR111;", "NR052;", "NR-11;", "NR05x;", "NR0051;", "NB051;"])
    func k4RejectsMalformedNoiseReduction(reply: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("NR;"), response: Self.ascii(reply))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getNoiseReduction() }
    }

    @Test func k4RejectsInvalidNRBeforeWriting() async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        for level in [-1, 11] {
            await #expect(throws: RigError.self) { try await proto.setNoiseReduction(.enabled(level: level)) }
        }
        for fraction in [-0.1, 1.1, Double.nan, Double.infinity] {
            await #expect(throws: RigError.self) { try await proto.setNoiseReductionLevel(fraction) }
        }
        #expect(await sent(mock).isEmpty)
    }

    @Test func rigctldK4ReadsNRLevelWhileOff() async throws {
        let rig = try RigController(radio: .Elecraft.k4, connection: .mock)
        try await rig.connect()
        let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
        await mock.setResponse(for: Self.ascii("NR;"), response: Self.ascii("NR070;"))
        let handler = RigctldCommandHandler(rigController: rig)
        #expect(await handler.handle(.getLevel(name: "NR")).data == ["0.700000"])
    }

    @Test(arguments: [0, 5, 10, 15])
    func k4NoiseBlankerLevelAndState(level: Int) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        let frame = String(format: "NB%02d1;", level)
        try await proto.setNoiseBlanker(.enabled(level: level))
        #expect(await sent(mock) == [frame, "ID;"])
        await mock.setResponse(for: Self.ascii("NB;"), response: Self.ascii(frame))
        #expect(try await proto.getNoiseBlanker() == .enabled(level: level))
        await mock.setResponse(for: Self.ascii("NB;"), response: Self.ascii(String(format: "NB%02d0;", level)))
        #expect(try await proto.getNoiseBlanker() == .off)
    }

    @Test func k4NoiseBlankerTogglePreservesStoredLevel() async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        try await proto.setNoiseBlanker(.off)
        try await proto.setNoiseBlanker(.enabled())
        #expect(await sent(mock) == ["NB0;", "ID;", "NB1;", "ID;"])
        await mock.setResponse(for: Self.ascii("NB;"), response: Self.ascii("NB1;"))
        #expect(try await proto.getNoiseBlanker() == .enabled())
        await mock.setResponse(for: Self.ascii("NB;"), response: Self.ascii("NB0;"))
        #expect(try await proto.getNoiseBlanker() == .off)
    }

    @Test(arguments: ["NB2;", "NB161;", "NB152;", "NB-11;", "NB05x;", "NB0051;", "NR051;"])
    func k4RejectsMalformedNoiseBlanker(reply: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("NB;"), response: Self.ascii(reply))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getNoiseBlanker() }
    }

    @Test func k4RejectsInvalidNBLevelBeforeWriting() async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        for level in [-1, 16] {
            await #expect(throws: RigError.self) { try await proto.setNoiseBlanker(.enabled(level: level)) }
        }
        #expect(await sent(mock).isEmpty)
    }

    @Test(arguments: [0, 1, 2, 3])
    func k4PreampUsesStageAndEnable(stage: Int) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        let frame = "PA" + String(stage) + (stage == 0 ? "0;" : "1;")
        try await proto.setPreamp(stage)
        #expect(await sent(mock) == [frame, "ID;"])
        await mock.setResponse(for: Self.ascii("PA;"), response: Self.ascii(frame))
        #expect(try await proto.getPreamp() == stage)
        await mock.setResponse(for: Self.ascii("PA;"), response: Self.ascii("PA" + String(stage) + "0;"))
        #expect(try await proto.getPreamp() == 0)
        await mock.setResponse(for: Self.ascii("PA;"), response: Self.ascii("PA" + String(stage) + ";"))
        #expect(try await proto.getPreamp() == stage)
    }

    @Test(arguments: ["PA;", "PA4;", "PA41;", "PA12;", "PA111;", "PA-1;", "PAx1;", "RA11;"])
    func k4RejectsMalformedPreamp(reply: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("PA;"), response: Self.ascii(reply))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getPreamp() }
    }

    @Test func k4RejectsInvalidPreampBeforeWriting() async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        for stage in [-1, 4] {
            await #expect(throws: RigError.self) { try await proto.setPreamp(stage) }
        }
        #expect(await sent(mock).isEmpty)
    }

    @Test func rigctldK4DisabledPreampReportsZero() async throws {
        let rig = try RigController(radio: .Elecraft.k4, connection: .mock)
        try await rig.connect()
        let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
        await mock.setResponse(for: Self.ascii("PA;"), response: Self.ascii("PA30;"))
        let handler = RigctldCommandHandler(rigController: rig)
        #expect(await handler.handle(.getLevel(name: "PREAMP")).data == ["0"])
    }

    @Test(arguments: [("GT0;", AGCSpeed.off), ("GT1;", .slow), ("GT2;", .fast),
                      ("GT000;", .off), ("GT002;", .fast), ("GT004;", .slow),
                      ("GT0000;", .off), ("GT0020;", .off), ("GT0040;", .off),
                      ("GT0021;", .fast), ("GT0041;", .slow)])
    func k4AGCReadsProtocolVariants(reply: String, expected: AGCSpeed) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("GT;"), response: Self.ascii(reply))
        #expect(try await proto.getAGC() == expected)
        #expect(await sent(mock) == ["GT;"])
    }

    @Test(arguments: ["GT;", "GT3;", "GT001;", "GT02;", "GT0022;", "GT0021x;", "GT-02;", "GC002;"])
    func k4AGCRejectsInvalidReplies(reply: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("GT;"), response: Self.ascii(reply))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getAGC() }
    }

    @Test(arguments: [0, 1, 2])
    func k4APFPreservesBandwidth(bandwidth: Int) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("AP;"), response: Self.ascii("AP0" + String(bandwidth) + ";"))
        #expect(try await proto.getFunction(.audioPeakFilter) == false)
        try await proto.setFunction(.audioPeakFilter, enabled: true)
        #expect(await sent(mock).suffix(3) == ["AP;", "AP1" + String(bandwidth) + ";", "ID;"])
        await mock.setResponse(for: Self.ascii("AP;"), response: Self.ascii("AP1" + String(bandwidth) + ";"))
        #expect(try await proto.getFunction(.audioPeakFilter))
        try await proto.setFunction(.audioPeakFilter, enabled: false)
        #expect(await sent(mock).suffix(3) == ["AP;", "AP0" + String(bandwidth) + ";", "ID;"])
    }

    @Test(arguments: ["AP;", "AP1;", "AP13;", "AP20;", "AP-1;", "AP10x;", "NP10;"])
    func k4APFRejectsMalformedReplyBeforeSetting(reply: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("AP;"), response: Self.ascii(reply))
        await #expect(throws: RigError.invalidResponse) { try await proto.setFunction(.audioPeakFilter, enabled: true) }
        #expect(await sent(mock) == ["AP;"])
    }

    @Test(arguments: [("GT0040;", "0"), ("GT2;", "2"), ("GT1;", "3")])
    func rigctldK4AGCUsesHamlibCodes(reply: String, expected: String) async throws {
        let rig = try RigController(radio: .Elecraft.k4, connection: .mock)
        try await rig.connect()
        let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
        await mock.setResponse(for: Self.ascii("GT;"), response: Self.ascii(reply))
        let handler = RigctldCommandHandler(rigController: rig)
        #expect(await handler.handle(.getLevel(name: "AGC")).data == [expected])
    }

    @Test(arguments: [0, 1, 2])
    func rigctldK4APFUsesEnableFieldAndPreservesBandwidth(bandwidth: Int) async throws {
        let rig = try RigController(radio: .Elecraft.k4, connection: .mock)
        try await rig.connect()
        let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID017;"))
        let handler = RigctldCommandHandler(rigController: rig)
        for enabled in [false, true] {
            let state = enabled ? "1" : "0"
            let targetState = enabled ? "0" : "1"
            await mock.setResponse(for: Self.ascii("AP;"), response: Self.ascii("AP" + state + String(bandwidth) + ";"))
            #expect(await handler.handle(.getFunc(name: "APF")).data == [state])
            let result = await handler.handle(.setFunc(name: "APF", enabled: !enabled))
            #expect(result.returnCode == .ok)
            let writes = await mock.recordedWrites.map { String(data: $0, encoding: .ascii) ?? "" }
            #expect(writes.suffix(3) == ["AP;", "AP" + targetState + String(bandwidth) + ";", "ID;"])
        }
    }

    @Test(arguments: ["C", "V", "D"])
    func k4VOXPreservesModeGroup(mode: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        for enabled in [false, true] {
            await mock.setResponse(for: Self.ascii("VX;"), response: Self.ascii("VX" + mode + (enabled ? "1;" : "0;")))
            #expect(try await proto.getFunction(.vox) == enabled)
            try await proto.setFunction(.vox, enabled: !enabled)
            #expect(await sent(mock).suffix(3) == ["VX;", "VX" + mode + (enabled ? "0;" : "1;"), "ID;"])
        }
    }

    @Test(arguments: ["VX;", "VX1;", "VXQ1;", "VXV2;", "VXV10;", "VXv1;", "VGC1;"])
    func k4VOXRejectsMalformedRepliesBeforeWriting(reply: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("VX;"), response: Self.ascii(reply))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getFunction(.vox) }
        await #expect(throws: RigError.invalidResponse) { try await proto.setFunction(.vox, enabled: true) }
        #expect(await sent(mock) == ["VX;", "VX;"])
    }

    @Test func otherElecraftVOXCommandsAreUnchanged() async throws {
        for definition in [RadioDefinition.Elecraft.k2, .Elecraft.k3, .Elecraft.k3S, .Elecraft.kx2, .Elecraft.kx3] {
            let (mock, proto) = try await connect(definition)
            try await proto.setFunction(.vox, enabled: true)
            try await proto.setFunction(.vox, enabled: false)
            let writes = await sent(mock).filter { $0 != "ID;" }
            #expect(writes == ["VX1;", "VX0;"])
        }
    }

    @Test(arguments: ["C", "V", "D"])
    func rigctldK4VOXUsesModeGroup(mode: String) async throws {
        let rig = try RigController(radio: .Elecraft.k4, connection: .mock)
        try await rig.connect()
        let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID017;"))
        await mock.setResponse(for: Self.ascii("VX;"), response: Self.ascii("VX" + mode + "0;"))
        let handler = RigctldCommandHandler(rigController: rig)
        #expect(await handler.handle(.getFunc(name: "VOX")).data == ["0"])
        #expect(await handler.handle(.setFunc(name: "VOX", enabled: true)).returnCode == .ok)
        let writes = await mock.recordedWrites.map { String(data: $0, encoding: .ascii) ?? "" }
        #expect(writes.suffix(3) == ["VX;", "VX" + mode + "1;", "ID;"])
    }

    // MARK: - Filter width and memory

    @Test func kx3UsesBWFilterWidthAndHundredMemories() async throws {
        let (mock, kx3) = try await connect(.Elecraft.kx3)
        try await kx3.setIFFilter(.filter3)
        #expect(await sent(mock) == ["BW0050;", "ID;"])
        #expect(try await kx3.getMemoryChannelCount() == 100)
    }

    // MARK: - Level scales (Hamlib k3.c k3_set_level / kx3_set_level)

    /// Bridge-equivalent input: rigctl `L AF 0.5` becomes level 127.
    @Test func k3AFAndRFUseTwoFiftyScale() async throws {
        let (mock, k3) = try await connect(.Elecraft.k3)
        try await k3.setAFGain(127)
        try await k3.setRFGain(127)
        #expect(await sent(mock) == ["AG125;", "ID;", "RG125;", "ID;"])
        await mock.setResponse(for: Self.ascii("AG;"), response: Self.ascii("AG250;"))
        #expect(try await k3.getAFGain() == 255)
    }

    @Test func kxAFIsZeroToSixtyAndRFIsOneNinetyToTwoFifty() async throws {
        let (mock, kx3) = try await connect(.Elecraft.kx3)
        try await kx3.setAFGain(127)
        try await kx3.setRFGain(127)
        try await kx3.setRFGain(0)
        #expect(await sent(mock) == ["AG030;", "ID;", "RG220;", "ID;", "RG190;", "ID;"])
        await mock.setResponse(for: Self.ascii("RG;"), response: Self.ascii("RG250;"))
        #expect(try await kx3.getRFGain() == 255)
        await mock.setResponse(for: Self.ascii("AG;"), response: Self.ascii("AG060;"))
        #expect(try await kx3.getAFGain() == 255)
    }

    @Test func k3FamilySquelchIsZeroToTwentyNine() async throws {
        for definition in Self.k3Family where definition.model != "K4" {
            let (mock, proto) = try await connect(definition)
            try await proto.setSquelch(77)          // rigctl L SQL 0.3
            #expect(await sent(mock) == ["SQ009;", "ID;"], "\(definition.model)")
            await mock.setResponse(for: Self.ascii("SQ;"), response: Self.ascii("SQ029;"))
            #expect(try await proto.getSquelch() == 255)
        }
    }

    @Test(arguments: [(0, 0, 0), (77, 12, 77), (127, 20, 128), (255, 40, 255)])
    func k4SquelchUsesFortySteps(level: Int, wire: Int, readback: Int) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        try await proto.setSquelch(level)
        let frame = String(format: "SQ%03d;", wire)
        #expect(await sent(mock) == [frame, "ID;"])
        await mock.setResponse(for: Self.ascii("SQ;"), response: Self.ascii(frame))
        #expect(try await proto.getSquelch() == readback)
    }

    @Test(arguments: ["SQ041;", "SQ255;", "SQ40;", "SQ0040;", "SQ-01;", "SQ0x1;", "AG040;"])
    func k4RejectsInvalidSquelch(reply: String) async throws {
        let (mock, proto) = try await connect(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("SQ;"), response: Self.ascii(reply))
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getSquelch() }
    }

    @Test func rigctldK4SquelchUsesNativeScale() async throws {
        let rig = try RigController(radio: .Elecraft.k4, connection: .mock)
        try await rig.connect()
        let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
        await mock.setResponse(for: Self.ascii("SQ;"), response: Self.ascii("SQ040;"))
        let handler = RigctldCommandHandler(rigController: rig)
        #expect(await handler.handle(.getLevel(name: "SQL")).data == ["1.000000"])
    }

    @Test func k2LevelsStayUnscaled() async throws {
        let (mock, k2) = try await connect(.Elecraft.k2)
        try await k2.setAFGain(127)
        try await k2.setSquelch(77)
        #expect(await sent(mock) == ["AG127;", "SQ077;"])
    }
}
