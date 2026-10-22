import Foundation
import Testing
@testable import RigControl

/// DATA-mode wire format, one check per protocol family (v1.3.1).
///
/// MacWinlink field report: an FT-710 asked for `.dataUSB` (VARA HF /
/// ARDOP) went to RTTY-U, because the shared newcat table sent `MD09;`.
/// The tests build each radio from its catalog definition so they check
/// the wiring MacWinlink gets, not just the tables.
@Suite struct DataModeWireFormatTests {

    private static func ascii(_ s: String) -> Data { s.data(using: .ascii)! }

    private func sent(_ mock: MockTransport) async -> [String] {
        await mock.recordedWrites.map { String(data: $0, encoding: .ascii) ?? "" }
    }

    private func connect(_ definition: RadioDefinition) async throws -> (MockTransport, any CATProtocol) {
        let mock = MockTransport()
        let proto = definition.createProtocol(transport: mock)
        try await proto.connect()
        await mock.reset()
        return (mock, proto)
    }

    // MARK: - Yaesu newcat

    /// Hamlib `newcat_mode_conv[]`, `newcat.c:10963-10980`.
    static let newcatCodes: [(Mode, String)] = [
        (.lsb, "1"), (.usb, "2"), (.cw, "3"), (.fm, "4"), (.am, "5"),
        (.rtty, "6"), (.cwR, "7"), (.dataLSB, "8"), (.rttyR, "9"),
        (.dataFM, "A"), (.fmN, "B"), (.dataUSB, "C"), (.amN, "D"),
        (.c4fm, "E"), (.dataFMN, "F"),
    ]

    @Test func ft710DataUSBSendsMD0C() async throws {
        let (mock, proto) = try await connect(RadioDefinition.Yaesu.ft710)
        try await proto.setMode(.dataUSB, vfo: .a)
        #expect(await sent(mock) == ["MD0C;"])
    }

    @Test func ft710ReadsMD0CAsDataUSB() async throws {
        let (mock, proto) = try await connect(RadioDefinition.Yaesu.ft710)
        await mock.setResponse(for: Self.ascii("MD0;"), response: Self.ascii("MD0C;"))
        #expect(try await proto.getMode(vfo: .a) == .dataUSB)
    }

    @Test func ft710RTTYUIsNotDataUSB() async throws {
        let (mock, proto) = try await connect(RadioDefinition.Yaesu.ft710)
        await mock.setResponse(for: Self.ascii("MD0;"), response: Self.ascii("MD09;"))
        #expect(try await proto.getMode(vfo: .a) == .rttyR)
    }

    @Test(arguments: newcatCodes)
    func ft710ModeTableMatchesHamlib(mode: Mode, code: String) async throws {
        let (mock, proto) = try await connect(RadioDefinition.Yaesu.ft710)
        try await proto.setMode(mode, vfo: .a)
        #expect(await sent(mock) == ["MD0\(code);"])

        await mock.setResponse(for: Self.ascii("MD0;"), response: Self.ascii("MD0\(code);"))
        #expect(try await proto.getMode(vfo: .a) == mode)
    }

    @Test(arguments: [
        RadioDefinition.Yaesu.ft991A, RadioDefinition.Yaesu.ftdx10,
        RadioDefinition.Yaesu.ftdx101D, RadioDefinition.Yaesu.ft450D,
    ])
    func sharedTableRadiosSendDataUAsC(definition: RadioDefinition) async throws {
        let (mock, proto) = try await connect(definition)
        try await proto.setMode(.dataUSB, vfo: .a)
        try await proto.setMode(.dataFM, vfo: .a)
        #expect(await sent(mock) == ["MD0C;", "MD0A;"], "\(definition.model)")
    }

    @Test func newcatTableHasNoDuplicateCodes() {
        let codes = YaesuCATProtocol.newcatModeCodeTable.values
        #expect(Set(codes).count == codes.count)
    }

    // MARK: - Kenwood (MD + DA, TS-590S/SG only)

    @Test func ts590SGDataUSBSendsMD2ThenDA1() async throws {
        let (mock, proto) = try await connect(RadioDefinition.Kenwood.ts590SG)
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID023;"))
        try await proto.setMode(.dataUSB, vfo: .a)
        #expect(await sent(mock) == ["MD2;", "ID;", "DA1;", "ID;"])
    }

    @Test func ts590SGReadsMD2PlusDA1AsDataUSB() async throws {
        let (mock, proto) = try await connect(RadioDefinition.Kenwood.ts590SG)
        await mock.setResponse(for: Self.ascii("MD;"), response: Self.ascii("MD2;"))
        await mock.setResponse(for: Self.ascii("DA;"), response: Self.ascii("DA1;"))
        #expect(try await proto.getMode(vfo: .a) == .dataUSB)
    }

    // MARK: - Elecraft K3 family (MD + DT)

    @Test func k3DataUSBSendsMD6ThenDT0() async throws {
        let (mock, proto) = try await connect(RadioDefinition.Elecraft.k3)
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID017;"))
        try await proto.setMode(.dataUSB, vfo: .a)
        #expect(await sent(mock) == ["MD6;", "ID;", "DT0;", "ID;"])
    }

    @Test(arguments: [
        (Mode.dataUSB, "MD6;", "DT0;"), (Mode.dataLSB, "MD9;", "DT0;"),
        (Mode.rtty, "MD6;", "DT2;"), (Mode.rttyR, "MD9;", "DT2;"),
    ])
    func k3DataModesRoundTrip(mode: Mode, md: String, dt: String) async throws {
        let (mock, proto) = try await connect(RadioDefinition.Elecraft.k3)
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID017;"))
        try await proto.setMode(mode, vfo: .a)
        #expect(await sent(mock) == [md, "ID;", dt, "ID;"])

        await mock.setResponse(for: Self.ascii("MD;"), response: Self.ascii(md))
        await mock.setResponse(for: Self.ascii("DT;"), response: Self.ascii(dt))
        #expect(try await proto.getMode(vfo: .a) == mode)
    }

    @Test func k3VoiceModeSendsNoDT() async throws {
        let (mock, proto) = try await connect(RadioDefinition.Elecraft.k3)
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID017;"))
        try await proto.setMode(.usb, vfo: .a)
        #expect(await sent(mock) == ["MD2;", "ID;"])
    }

    /// The KX3's 15 W max power trips the `isK2` heuristic; it must still
    /// get the K3 mode table.
    @Test func kx3UsesK3ModeTable() async throws {
        let (mock, proto) = try await connect(RadioDefinition.Elecraft.kx3)
        try await proto.setMode(.dataUSB, vfo: .a)
        #expect(await sent(mock).filter { $0.hasPrefix("MD") || $0.hasPrefix("DT") }
                == ["MD6;", "DT0;"])
    }

    // MARK: - Elecraft K2 (own table, no DT)

    @Test func k2DataUSBSendsMD9() async throws {
        let (mock, proto) = try await connect(RadioDefinition.Elecraft.k2)
        try await proto.setMode(.dataUSB, vfo: .a)
        try await proto.setMode(.dataLSB, vfo: .a)
        #expect(await sent(mock) == ["MD9;", "MD6;"])
    }

    @Test func k2ReadsMD9AsDataUSB() async throws {
        let (mock, proto) = try await connect(RadioDefinition.Elecraft.k2)
        await mock.setResponse(for: Self.ascii("MD;"), response: Self.ascii("MD9;"))
        #expect(try await proto.getMode(vfo: .a) == .dataUSB)
    }

    @Test func k2RejectsRTTY() async throws {
        let (_, proto) = try await connect(RadioDefinition.Elecraft.k2)
        await #expect(throws: RigError.self) { try await proto.setMode(.rtty, vfo: .a) }
    }

    // MARK: - Icom CI-V (base mode + DATA flag), via the Xiegu G90

    @Test func g90DataUSBSendsUSBPlusDataFlag() async throws {
        let (mock, proto) = try await connect(RadioDefinition.Xiegu.g90)
        try await proto.setMode(.dataUSB, vfo: .a)
        let writes = await mock.recordedWrites
        #expect(writes.contains(Data([0xFE, 0xFE, 0x88, 0xE0, 0x06, 0x01, 0x01, 0xFD])))
        #expect(writes.last == Data([0xFE, 0xFE, 0x88, 0xE0, 0x1A, 0x06, 0x01, 0x01, 0xFD]))
    }
}
