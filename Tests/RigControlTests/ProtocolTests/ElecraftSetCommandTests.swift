import Foundation
import Testing
@testable import RigControl

/// Elecraft set-command verification (v1.2.19).
///
/// Elecraft radios don't echo set commands. Hamlib follows each set with
/// `ID;` and reads for a `?;` / `N;` / `E;` / `O;` rejection ahead of the
/// `ID` reply (`kenwood_transaction`, `kenwood.c:400-443`, `655-700`).
/// Pre-v1.2.19 the K3 / K4 / KX path required an echo of `FA`, `MD`, `PC`,
/// `FR`, `FT` and the RIT commands, which real radios never send. The K2
/// path (write, then wait) is unchanged.
@Suite struct ElecraftSetCommandTests {

    private static func ascii(_ s: String) -> Data { s.data(using: .ascii)! }

    private func make(_ capabilities: RigCapabilities) async throws -> (MockTransport, ElecraftProtocol) {
        let mock = MockTransport()
        let proto = ElecraftProtocol(transport: mock, capabilities: capabilities)
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID017;"))
        return (mock, proto)
    }

    private func sent(_ mock: MockTransport) async -> [String] {
        await mock.recordedWrites.map { String(data: $0, encoding: .ascii) ?? "" }
    }

    @Test func k3SetIsVerifiedWithID() async throws {
        let (mock, proto) = try await make(RadioCapabilitiesDatabase.Elecraft.k3)
        try await proto.setFrequency(14_074_000, vfo: .a)
        try await proto.setMode(.usb, vfo: .a)
        #expect(await sent(mock) == ["FA00014074000;", "ID;", "MD2;", "ID;"])
    }

    @Test func k3RejectionThrowsAndDrainsIDReply() async throws {
        let (mock, proto) = try await make(RadioCapabilitiesDatabase.Elecraft.k3)
        await mock.setChunkedResponse([Self.ascii("?;"), Self.ascii("ID017;")])
        do {
            try await proto.setPower(50)
            Issue.record("expected a throw")
        } catch RigError.commandFailed(_) {
        } catch {
            Issue.record("expected commandFailed, got \(error)")
        }
        #expect(await mock.chunkedResponse.isEmpty)
    }

    @Test func k3SkipsUnsolicitedFrame() async throws {
        let (mock, proto) = try await make(RadioCapabilitiesDatabase.Elecraft.k3)
        await mock.setChunkedResponse([Self.ascii("FA00014074000;"), Self.ascii("ID017;")])
        try await proto.setMode(.cw, vfo: .a)
        #expect(await sent(mock) == ["MD3;", "ID;"])
    }

    @Test func k3PowerStateIsWriteOnly() async throws {
        // PS is in Hamlib's skip list (kenwood.c:409-410): a radio going
        // to standby won't answer ID;.
        let (mock, proto) = try await make(RadioCapabilitiesDatabase.Elecraft.k3)
        await mock.setShouldThrowOnRead(true)
        try await proto.setPowerState(false)
        #expect(await sent(mock) == ["PS0;"])
    }

    @Test func k2PathIsUnchanged() async throws {
        // Hardware-verified behaviour: write, wait, no read.
        let (mock, proto) = try await make(RadioCapabilitiesDatabase.Elecraft.k2)
        await mock.setShouldThrowOnRead(true)
        try await proto.setFrequency(7_074_000, vfo: .a)
        try await proto.setMode(.lsb, vfo: .a)
        #expect(await sent(mock) == ["FA00007074000;", "MD1;"])
    }
}
