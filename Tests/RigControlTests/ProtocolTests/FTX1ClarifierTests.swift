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

    // MARK: - VFO-qualified overloads

    @Test(arguments: [(VFO.a, "0"), (.main, "0"), (.b, "1"), (.sub, "1")])
    func vfoMapsToCFSideDigit(vfo: VFO, side: String) {
        #expect(String(YaesuCATProtocol.ftx1ClarifierSide(for: vfo)) == side)
    }

    @Test func parsersRejectWrongSide() throws {
        #expect(try YaesuCATProtocol.ftx1ClarifierState(from: "CF10001000", side: "1").txEnabled)
        #expect(try YaesuCATProtocol.ftx1ClarifierOffset(from: "CF101+0300", side: "1") == 300)
        #expect(throws: RigError.self) {
            try YaesuCATProtocol.ftx1ClarifierState(from: "CF00001000", side: "1")
        }
        #expect(throws: RigError.self) {
            try YaesuCATProtocol.ftx1ClarifierOffset(from: "CF001+0300", side: "1")
        }
    }

    @Test func setRITOnSubUsesSideOneAndPreservesSubTX() async throws {
        let (proto, transport) = try await makeProtocol()
        await transport.setChunkedResponse([
            Data("CF10001000;".utf8),
            Data("ID0670;".utf8),
            Data("ID0670;".utf8),
        ])

        try await proto.setRIT(RITXITState(enabled: true, offset: 300), vfo: .sub)

        let writes = await transport.recordedWrites.compactMap { String(data: $0, encoding: .ascii) }
        #expect(writes == ["CF100;", "CF10011000;", "ID;", "CF101+0300;", "ID;"])
    }

    @Test func disableXITOnSubSendsOnlyEnableCommand() async throws {
        let (proto, transport) = try await makeProtocol()
        await transport.setChunkedResponse([
            Data("CF10011000;".utf8),
            Data("ID0670;".utf8),
        ])

        try await proto.setXIT(.disabled, vfo: .b)

        let writes = await transport.recordedWrites.compactMap { String(data: $0, encoding: .ascii) }
        #expect(writes == ["CF100;", "CF10010000;", "ID;"])
    }

    @Test func getXITOnSubReadsSubOffset() async throws {
        let (proto, transport) = try await makeProtocol()
        await transport.setChunkedResponse([
            Data("CF10001000;".utf8),
            Data("CF101-0120;".utf8),
        ])

        #expect(try await proto.getXIT(vfo: .sub) == RITXITState(enabled: true, offset: -120))
        let writes = await transport.recordedWrites.compactMap { String(data: $0, encoding: .ascii) }
        #expect(writes == ["CF100;", "CF101;"])
    }

    @Test func getRITOnSubDisabledSkipsOffsetRead() async throws {
        let (proto, transport) = try await makeProtocol()
        await transport.setChunkedResponse([Data("CF10001000;".utf8)])

        #expect(try await proto.getRIT(vfo: .sub) == .disabled)
        let writes = await transport.recordedWrites.compactMap { String(data: $0, encoding: .ascii) }
        #expect(writes == ["CF100;"])
    }

    @Test func mainOverloadMatchesUnqualifiedCall() async throws {
        let (proto, transport) = try await makeProtocol()
        await transport.setChunkedResponse([
            Data("CF00001000;".utf8),
            Data("ID0670;".utf8),
            Data("ID0670;".utf8),
        ])

        try await proto.setRIT(RITXITState(enabled: true, offset: 250), vfo: .main)

        let writes = await transport.recordedWrites.compactMap { String(data: $0, encoding: .ascii) }
        #expect(writes == ["CF000;", "CF00011000;", "ID;", "CF001+0250;", "ID;"])
    }

    @Test func nonFTX1RadioRejectsSubSideWithoutWriting() async throws {
        let transport = MockTransport()
        let proto = try #require(
            RadioDefinition.Yaesu.ft991A.createProtocol(transport: transport) as? YaesuCATProtocol
        )
        try await proto.connect()
        await transport.reset()

        await #expect(throws: RigError.self) {
            try await proto.setRIT(RITXITState(enabled: true, offset: 100), vfo: .sub)
        }
        await #expect(throws: RigError.self) {
            _ = try await proto.getXIT(vfo: .b)
        }
        #expect(await transport.recordedWrites.isEmpty)
    }
}
