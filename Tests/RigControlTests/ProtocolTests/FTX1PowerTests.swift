import Foundation
import Testing
@testable import RigControl

/// FTX-1 `PC` carries the head: `PC1nnn` field head, `PC2nnn` SPA-1
/// (Hamlib `ftx1_audio.c:310-455`).
@Suite struct FTX1PowerTests {

    private static func ascii(_ s: String) -> Data { Data(s.utf8) }

    private func connect(reply: String) async throws -> (MockTransport, YaesuCATProtocol) {
        let mock = MockTransport()
        let proto = try #require(RadioDefinition.Yaesu.ftx1.createProtocol(transport: mock) as? YaesuCATProtocol)
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID0840;"))
        await mock.setResponse(for: Self.ascii("PC;"), response: Self.ascii(reply))
        return (mock, proto)
    }

    private func sets(_ mock: MockTransport) async -> [String] {
        await mock.recordedWrites
            .map { String(decoding: $0, as: UTF8.self) }
            .filter { $0 != "ID;" && $0 != "PC;" }
    }

    @Test func fieldHeadSetsPC1() async throws {
        for (watts, wire) in [(5, "PC1005;"), (10, "PC1010;"), (50, "PC1010;"), (0, "PC10.5;")] {
            let (mock, ftx1) = try await connect(reply: "PC1006;")
            try await ftx1.setPower(watts)
            #expect(await sets(mock) == [wire], "\(watts) W")
        }
    }

    @Test func spa1SetsPC2() async throws {
        for (watts, wire) in [(50, "PC2050;"), (100, "PC2100;"), (2, "PC2005;")] {
            let (mock, ftx1) = try await connect(reply: "PC2075;")
            try await ftx1.setPower(watts)
            #expect(await sets(mock) == [wire], "\(watts) W")
        }
    }

    @Test(arguments: [("PC1005;", 5), ("PC10.5;", 1), ("PC2100;", 100), ("PC2050;", 50)])
    func readsTheWattsAfterTheHeadDigit(reply: String, watts: Int) async throws {
        let (_, ftx1) = try await connect(reply: reply)
        #expect(try await ftx1.getPower() == watts)
    }

    @Test func rejectsAnUnknownHead() async throws {
        let (_, ftx1) = try await connect(reply: "PC3005;")
        await #expect(throws: RigError.self) { _ = try await ftx1.getPower() }
    }

    @Test func otherNewcatRadiosKeepPlainPC() async throws {
        let mock = MockTransport()
        let proto = RadioDefinition.Yaesu.ft991A.createProtocol(transport: mock)
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID0670;"))
        try await (proto as! YaesuCATProtocol).setPower(50)
        #expect(await mock.recordedWrites.map { String(decoding: $0, as: UTF8.self) } == ["PC050;", "ID;"])
    }
}
