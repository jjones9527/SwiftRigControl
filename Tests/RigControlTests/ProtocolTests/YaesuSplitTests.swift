import Foundation
import Testing
@testable import RigControl

/// Yaesu newcat split, per Hamlib `newcat_set_split_vfo` /
/// `newcat_get_split_vfo` (`newcat.c:2770-2950`): `ST` where the radio
/// has it (the FT-891 through `ft891.c:377-466`), otherwise the TX VFO
/// with `FT` (`newcat_set_tx_vfo`, `newcat.c:8248-8320`). Through v1.3.1
/// split threw on every radio without `ST`, so WSJT-X split failed on the
/// FT-991A, FT-891, FT-950 and FTDX-1200/3000/5000/9000.
@Suite struct YaesuSplitTests {

    private static func ascii(_ s: String) -> Data { Data(s.utf8) }

    private func connect(_ radio: RadioDefinition, replies: [String: String] = [:]) async throws
        -> (MockTransport, YaesuCATProtocol)
    {
        let mock = MockTransport()
        let proto = try #require(radio.createProtocol(transport: mock) as? YaesuCATProtocol)
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID0670;"))
        await mock.setResponse(for: Self.ascii("AI;"), response: Self.ascii("AI0;"))
        for (query, reply) in replies {
            await mock.setResponse(for: Self.ascii(query), response: Self.ascii(reply))
        }
        return (mock, proto)
    }

    private func sets(_ mock: MockTransport) async -> [String] {
        await mock.recordedWrites
            .map { String(decoding: $0, as: UTF8.self) }
            .filter { $0 != "ID;" && $0 != "AI;" }
    }

    /// FT2 / FT3 radios (newcat.c:8301-8307).
    @Test(arguments: [
        RadioDefinition.Yaesu.ft991A, .Yaesu.ft991, .Yaesu.ft950, .Yaesu.ft2000,
        .Yaesu.ftdx1200, .Yaesu.ftdx3000, .Yaesu.ftdx5000,
    ])
    func splitIsTheTXVFOWithFT23(radio: RadioDefinition) async throws {
        let (mock, proto) = try await connect(radio)
        try await proto.setSplit(true)
        try await proto.setSplit(false)
        #expect(await sets(mock) == ["FT3;", "FT2;"], "\(radio.fullName)")
    }

    @Test(arguments: [RadioDefinition.Yaesu.ftdx9000, .Yaesu.ft450, .Yaesu.ft450D])
    func splitIsTheTXVFOWithFT01(radio: RadioDefinition) async throws {
        let (mock, proto) = try await connect(radio)
        try await proto.setSplit(true)
        try await proto.setSplit(false)
        #expect(await sets(mock) == ["FT1;", "FT0;"], "\(radio.fullName)")
    }

    @Test func ftdx9000SelectVFOUsesFT01() async throws {
        let (mock, proto) = try await connect(.Yaesu.ftdx9000)
        try await proto.selectVFO(.b)
        #expect(await sets(mock) == ["FT1;"])
    }

    @Test func splitReadsTheTXVFO() async throws {
        let (_, proto) = try await connect(.Yaesu.ft991A, replies: ["FT;": "FT1;"])
        #expect(try await proto.getSplit() == true)
        let (_, off) = try await connect(.Yaesu.ft991A, replies: ["FT;": "FT0;"])
        #expect(try await off.getSplit() == false)
    }

    @Test func ft891UsesST() async throws {
        let (mock, proto) = try await connect(.Yaesu.ft891, replies: ["ST;": "ST2;"])
        try await proto.setSplit(true)
        #expect(await sets(mock) == ["ST1;"])
        // ST2 is split + 5 kHz (ft891.c:466).
        #expect(try await proto.getSplit() == true)
    }

    @Test func rigctldSplitWorksOnTheFT991A() async throws {
        let rig = try RigController(radio: .Yaesu.ft991A, connection: .mock)
        try await rig.connect()
        let mock = await rig.rawProtocol.transport as! MockSerialTransport
        await mock.reset()
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID0670;"))
        let response = await RigctldCommandHandler(rigController: rig).handle(.setSplitVFO(enabled: true, txVFO: "VFOB"))
        #expect(response.returnCode == .ok)
        #expect(await mock.recordedWrites.first == Self.ascii("FT3;"))
    }
}
