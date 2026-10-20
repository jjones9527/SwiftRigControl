import Foundation
import Testing
@testable import RigControl

@Suite struct DStarModeProtocolTests {
    @Test func icomMapsDStarToModeCode17() async throws {
        let proto = IcomCIVProtocol(
            transport: MockTransport(), civAddress: 0xA4,
            radioModel: .ic7100, commandSet: IC7100CommandSet.ic7100,
            capabilities: RadioCapabilitiesDatabase.Icom.ic7100
        )
        #expect(try await proto.modeToIcomCode(.dstar) == 0x17)
        #expect(try await proto.icomCodeToMode(0x17) == .dstar)
        #expect(await !proto.isDataMode(.dstar))
    }

    @Test func thd74SetsAndReadsDStarModeIndex() async throws {
        let mock = MockTransport()
        let proto = THD72Protocol(
            transport: mock,
            capabilities: RadioCapabilitiesDatabase.Kenwood.thd74,
            family: .thd74
        )
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Data("MD 0,1\r".utf8), response: Data("MD 0,1\r".utf8))
        try await proto.setMode(.dstar, vfo: .a)
        #expect(await mock.recordedWrites == [Data("MD 0,1\r".utf8)])

        await mock.setResponse(for: Data("MD 0\r".utf8), response: Data("MD 0,7\r".utf8))
        #expect(try await proto.getMode(vfo: .a) == .dstar)
    }

    @Test func rigctldParsesAndFormatsDStar() async throws {
        let caps = RigCapabilities(supportedModes: [.fm, .dstar])
        let rig = try RigController(
            radio: .dummy(name: "D-STAR Test", capabilities: caps),
            connection: .mock
        )
        try await rig.connect()
        let handler = RigctldCommandHandler(rigController: rig)

        #expect(await handler.handle(.setMode(mode: "DV", passband: 0)).returnCode == .ok)
        let response = await handler.handle(.getMode)
        #expect(response.returnCode == .ok)
        #expect(response.data == ["D-STAR", "6000"])
    }

}
