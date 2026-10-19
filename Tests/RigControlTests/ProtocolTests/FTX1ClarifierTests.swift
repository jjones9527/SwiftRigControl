import Foundation
import Testing
@testable import RigControl

@Suite struct FTX1ClarifierTests {

    private func makeProtocol() async throws -> (YaesuCATProtocol, MockTransport) {
        let transport = MockTransport()
        let proto = try #require(
            RadioDefinition.Yaesu.ftx1.createProtocol(transport: transport) as? YaesuCATProtocol
        )
        try await proto.connect()
        await transport.reset()
        return (proto, transport)
    }

    @Test func parsersValidateExactFTX1Formats() throws {
        let state = try YaesuCATProtocol.ftx1ClarifierState(from: "CF00010000")
        #expect(state.rxEnabled)
        #expect(!state.txEnabled)
        #expect(try YaesuCATProtocol.ftx1ClarifierOffset(from: "CF001-0123") == -123)
        #expect(throws: RigError.self) {
            try YaesuCATProtocol.ftx1ClarifierState(from: "CF000X0000")
        }
        #expect(throws: RigError.self) {
            try YaesuCATProtocol.ftx1ClarifierOffset(from: "CF001+12X3")
        }
    }

    @Test func setRITUsesCFAndPreservesTXClarifier() async throws {
        let (proto, transport) = try await makeProtocol()
        await transport.setChunkedResponse([
            Data("CF00001000;".utf8),
            Data("ID0670;".utf8),
            Data("ID0670;".utf8),
        ])

        try await proto.setRIT(RITXITState(enabled: true, offset: 250))

        let writes = await transport.recordedWrites.compactMap { String(data: $0, encoding: .ascii) }
        #expect(writes == ["CF000;", "CF00011000;", "ID;", "CF001+0250;", "ID;"])
    }

    @Test func setXITUsesCFAndPreservesRXClarifier() async throws {
        let (proto, transport) = try await makeProtocol()
        await transport.setChunkedResponse([
            Data("CF00010000;".utf8),
            Data("ID0670;".utf8),
            Data("ID0670;".utf8),
        ])

        try await proto.setXIT(RITXITState(enabled: true, offset: -75))

        let writes = await transport.recordedWrites.compactMap { String(data: $0, encoding: .ascii) }
        #expect(writes == ["CF000;", "CF00011000;", "ID;", "CF001-0075;", "ID;"])
    }

    @Test func gettersUseCFStateAndSharedOffset() async throws {
        let (proto, transport) = try await makeProtocol()
        await transport.setChunkedResponse([
            Data("CF00011000;".utf8),
            Data("CF001+0042;".utf8),
        ])

        #expect(try await proto.getRIT() == RITXITState(enabled: true, offset: 42))
        let writes = await transport.recordedWrites.compactMap { String(data: $0, encoding: .ascii) }
        #expect(writes == ["CF000;", "CF001;"])
    }
}
