import Foundation
import Testing
@testable import RigControl

/// `Mode.dataAM` (Hamlib `RIG_MODE_PKTAM`, rigctld `AM-D` / `PKTAM`):
/// AM with the DATA flag on Icom (`icom.c:2508-2511`, read back at
/// `icom.c:2976`) and AM + `DA1` on the TS-590 (`kenwood.c:3012`).
@Suite struct DataAMModeTests {

    private static func cmd(_ to: UInt8, _ body: [UInt8]) -> Data {
        Data([0xFE, 0xFE, to, 0xE0] + body + [0xFD])
    }

    private static func reply(_ from: UInt8, _ body: [UInt8]) -> Data {
        Data([0xFE, 0xFE, 0xE0, from] + body + [0xFD])
    }

    private func icom(_ model: IcomRadioModel, address: UInt8, commandSet: StandardIcomCommandSet,
                      capabilities: RigCapabilities) async throws -> (MockTransport, IcomCIVProtocol) {
        let mock = MockTransport()
        let proto = IcomCIVProtocol(transport: mock, civAddress: address, radioModel: model,
                                    commandSet: commandSet, capabilities: capabilities)
        try await proto.connect()
        await mock.reset()
        return (mock, proto)
    }

    // MARK: - rigctld names

    @Test func rigctldParsesAndPrintsHamlibNames() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        let handler = RigctldCommandHandler(rigController: rig)
        for name in ["PKTAM", "AM-D", "am-d", "DATA-AM"] {
            #expect(try await handler.parseMode(name) == .dataAM, "\(name)")
        }
        #expect(await handler.formatMode(.dataAM) == "PKTAM")
    }

    // MARK: - Icom

    @Test func ic7300SendsAMWithTheDataFlagIn0x26() async throws {
        let (mock, proto) = try await icom(.ic7300, address: 0x94, commandSet: .ic7300,
                                           capabilities: RadioCapabilitiesDatabase.Icom.ic7300)
        try await proto.setMode(.dataAM, vfo: .a)
        #expect(await mock.recordedWrites.last == Self.cmd(0x94, [0x26, 0x00, 0x02, 0x01, 0x01]))

        await mock.setResponse(for: Self.cmd(0x94, [0x26, 0x00]),
                               response: Self.reply(0x94, [0x26, 0x00, 0x02, 0x01, 0x01]))
        #expect(try await proto.getMode(vfo: .a) == .dataAM)
    }

    @Test func ic7600SendsAMThenTheDataFlag() async throws {
        let (mock, proto) = try await icom(.ic7600, address: 0x7A, commandSet: .ic7600,
                                           capabilities: RadioCapabilitiesDatabase.Icom.ic7600)
        try await proto.setMode(.dataAM, vfo: .a)
        let writes = await mock.recordedWrites
        #expect(Array(writes.suffix(2)) == [
            Self.cmd(0x7A, [0x06, 0x02, 0x01]),
            Self.cmd(0x7A, [0x1A, 0x06, 0x01, 0x01]),
        ])

        await mock.setResponse(for: Self.cmd(0x7A, [0x04]), response: Self.reply(0x7A, [0x04, 0x02, 0x01]))
        await mock.setResponse(for: Self.cmd(0x7A, [0x1A, 0x06]),
                               response: Self.reply(0x7A, [0x1A, 0x06, 0x01, 0x01]))
        #expect(try await proto.getMode(vfo: .a) == .dataAM)
        await mock.setResponse(for: Self.cmd(0x7A, [0x1A, 0x06]),
                               response: Self.reply(0x7A, [0x1A, 0x06, 0x00, 0x00]))
        #expect(try await proto.getMode(vfo: .a) == .am)
    }

    /// Hamlib lists PKTAM on exactly these catalog radios (`rigctl -u`,
    /// Hamlib `91e7b97`).
    @Test func catalogAdvertisesDataAMWhereHamlibDoes() {
        let expected: Set<String> = [
            "IC-705", "IC-7100", "IC-7300", "IC-7300MK2", "IC-7600", "IC-7610",
            "IC-7700", "IC-7760", "IC-7800", "IC-7850", "IC-7851", "IC-905",
            "TS-590S", "TS-590SG",
        ]
        let advertising = Set(RadioDefinition.allSupportedRadios
            .filter { $0.capabilities.supportedModes.contains(.dataAM) }
            .map(\.model))
        #expect(advertising == expected)
    }

    // MARK: - Kenwood TS-590

    @Test func ts590SendsMD5ThenDA1AndReadsItBack() async throws {
        let mock = MockTransport()
        let proto = RadioDefinition.Kenwood.ts590SG.createProtocol(transport: mock)
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Data("ID;".utf8), response: Data("ID023;".utf8))
        try await proto.setMode(.dataAM, vfo: .a)
        let sets = await mock.recordedWrites.map { String(decoding: $0, as: UTF8.self) }.filter { $0 != "ID;" }
        #expect(sets == ["MD5;", "DA1;"])

        await mock.setResponse(for: Data("MD;".utf8), response: Data("MD5;".utf8))
        await mock.setResponse(for: Data("DA;".utf8), response: Data("DA1;".utf8))
        #expect(try await proto.getMode(vfo: .a) == .dataAM)
    }
}
