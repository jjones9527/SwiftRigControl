import Foundation
import Testing
@testable import RigControl

/// Elecraft on/off reply validation (v1.2.20).
///
/// `FT`, `TQ`, `RT` and `XT` replies must be the two command letters and
/// one `0` / `1` digit, as Hamlib `parse_binary_response` requires
/// (`elecraft.c:594-608`, upstream `ffe227a3` / `900c4d3`). Before
/// v1.2.20 a malformed reply read as "off".
@Suite struct ElecraftReplyParsingTests {

    private static func ascii(_ s: String) -> Data { s.data(using: .ascii)! }

    @Test(arguments: ["FT0", "FT1"])
    func wellFormedRepliesParse(reply: String) throws {
        #expect(try ElecraftProtocol.parseOnOffReply(reply, command: "FT") == (reply == "FT1"))
    }

    @Test(arguments: ["FT", "FT2", "FT01", "FT1x", "TQ1", "ft1", "", "?"])
    func malformedRepliesThrow(reply: String) {
        #expect(throws: RigError.self) {
            try ElecraftProtocol.parseOnOffReply(reply, command: "FT")
        }
    }

    private func make() async throws -> (MockTransport, ElecraftProtocol) {
        let mock = MockTransport()
        let proto = ElecraftProtocol(transport: mock, capabilities: RadioCapabilitiesDatabase.Elecraft.k3)
        try await proto.connect()
        await mock.reset()
        return (mock, proto)
    }

    @Test func getSplitRejectsTruncatedFT() async throws {
        let (mock, proto) = try await make()
        await mock.setResponse(for: Self.ascii("FT;"), response: Self.ascii("FT;"))
        await #expect(throws: RigError.self) { try await proto.getSplit() }
    }

    @Test func getTXStatusRejectsExtendedTQ() async throws {
        let (mock, proto) = try await make()
        await mock.setResponse(for: Self.ascii("TQ;"), response: Self.ascii("TQ10;"))
        await #expect(throws: RigError.self) { try await proto.getTXStatus() }
    }

    @Test func getTXStatusReadsTransmit() async throws {
        let (mock, proto) = try await make()
        await mock.setResponse(for: Self.ascii("TQ;"), response: Self.ascii("TQ1;"))
        #expect(try await proto.getTXStatus())
    }

    @Test func getRITRejectsMalformedRT() async throws {
        let (mock, proto) = try await make()
        await mock.setResponse(for: Self.ascii("RT;"), response: Self.ascii("RT9;"))
        await #expect(throws: RigError.self) { try await proto.getRIT() }
    }
}
