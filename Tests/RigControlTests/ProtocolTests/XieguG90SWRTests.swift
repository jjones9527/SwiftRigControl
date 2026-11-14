import Foundation
import Testing
@testable import RigControl

@Suite struct XieguG90SWRTests {
    private func makeProtocol(reply: [UInt8]) async throws -> IcomCIVProtocol {
        let mock = MockTransport()
        let proto = try #require(
            RadioDefinition.Xiegu.g90.createProtocol(transport: mock) as? IcomCIVProtocol
        )
        try await proto.connect()
        await mock.setResponse(
            for: Data([0xFE, 0xFE, 0x88, 0xE0, 0x15, 0x12, 0xFD]),
            response: Data([0xFE, 0xFE, 0xE0, 0x88] + reply + [0xFD])
        )
        return proto
    }

    @Test(arguments: [
        [UInt8](arrayLiteral: 0x02, 0x2C), [0x02, 0xA0], [0x0A, 0x00],
        [0x10, 0x00], [0xFF, 0xFF]
    ])
    func rejectsInvalidBCDDigits(data: [UInt8]) async throws {
        let proto = try await makeProtocol(reply: [0x15, 0x12] + data)
        await #expect(throws: RigError.invalidResponse) {
            _ = try await proto.getSWR()
        }
    }

    @Test(arguments: [
        [UInt8](arrayLiteral: 0x15, 0x11, 0x00, 0x48),
        [0x14, 0x12, 0x00, 0x48],
        [0x15, 0x12, 0x48],
        [0x15, 0x12, 0x00, 0x48, 0x00]
    ])
    func rejectsWrongCommandOrLength(reply: [UInt8]) async throws {
        let proto = try await makeProtocol(reply: reply)
        await #expect(throws: RigError.invalidResponse) {
            _ = try await proto.getSWRMeter()
        }
    }

    @Test func rejectsNAK() async throws {
        let proto = try await makeProtocol(reply: [0xFA])
        await #expect(throws: RigError.commandFailed("SWR meter query rejected")) {
            _ = try await proto.getSWRMeter()
        }
    }

    @Test(arguments: [(0x00, 0x00, 0), (0x00, 0x48, 48), (0x02, 0x55, 255), (0x09, 0x99, 255)])
    func acceptsBCDAndPreservesRawClamping(high: Int, low: Int, expected: Int) async throws {
        let proto = try await makeProtocol(reply: [0x15, 0x12, UInt8(high), UInt8(low)])
        #expect(try await proto.getSWRMeter() == UInt8(expected))
    }

    @Test func returnsCalibratedSWR() async throws {
        let proto = try await makeProtocol(reply: [0x15, 0x12, 0x00, 0x48])
        #expect(try await proto.getSWR().swrRatio == 1.5)
    }
}
