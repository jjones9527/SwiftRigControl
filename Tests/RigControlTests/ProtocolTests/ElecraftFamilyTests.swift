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
            #expect(proto.family == .k3, "\(definition.model)")
        }
    }

    @Test func inferenceNoLongerTakesKXRadiosForK2() {
        typealias Caps = RadioCapabilitiesDatabase.Elecraft
        #expect(ElecraftProtocol.inferredFamily(for: Caps.k2) == .k2)
        #expect(ElecraftProtocol.inferredFamily(for: Caps.kx2) == .k3)
        #expect(ElecraftProtocol.inferredFamily(for: Caps.kx3) == .k3)
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

    // MARK: - S-meter

    @Test(arguments: ["K3", "K3S", "K4", "KX2", "KX3"])
    func k3FamilyReadsSM(model: String) async throws {
        let definition = try #require(Self.k3Family.first { $0.model == model })
        let (mock, proto) = try await connect(definition)
        await mock.setResponse(for: Self.ascii("SM;"), response: Self.ascii("SM0012;"))
        let strength = try await proto.getSignalStrength()
        #expect(await sent(mock) == ["SM;"])
        #expect(strength.raw == 12)
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

    // MARK: - Filter width and memory

    @Test func kx3UsesBWFilterWidthAndHundredMemories() async throws {
        let (mock, kx3) = try await connect(.Elecraft.kx3)
        try await kx3.setIFFilter(.filter3)
        #expect(await sent(mock) == ["BW0050;", "ID;"])
        #expect(try await kx3.getMemoryChannelCount() == 100)
    }
}
