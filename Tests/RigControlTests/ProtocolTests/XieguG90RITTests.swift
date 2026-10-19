import Foundation
import Testing
@testable import RigControl

/// G90 RIT parity with Hamlib upstream `aff6e940`.
@Suite struct XieguG90RITTests {

    private func makeProtocol() async throws -> (IcomCIVProtocol, MockTransport) {
        let transport = MockTransport()
        let proto = try #require(
            RadioDefinition.Xiegu.g90.createProtocol(transport: transport) as? IcomCIVProtocol
        )
        try await proto.connect()
        await transport.reset()
        return (proto, transport)
    }

    @Test func positiveOffsetUsesSingle2100Transaction() async throws {
        let (proto, transport) = try await makeProtocol()

        try await proto.setRIT(RITXITState(enabled: true, offset: 500))

        let writes = await transport.recordedWrites
        #expect(writes == [Data([0xFE, 0xFE, 0x88, 0xE0, 0x21, 0x00, 0x00, 0x05, 0x00, 0xFD])])
    }

    @Test func negativeOffsetUsesBCDMagnitudeAndSign() async throws {
        let (proto, transport) = try await makeProtocol()

        try await proto.setRIT(RITXITState(enabled: true, offset: -123))

        let writes = await transport.recordedWrites
        #expect(writes == [Data([0xFE, 0xFE, 0x88, 0xE0, 0x21, 0x00, 0x23, 0x01, 0x01, 0xFD])])
    }

    @Test func disablingWritesZeroWithout2101FollowUp() async throws {
        let (proto, transport) = try await makeProtocol()

        try await proto.setRIT(RITXITState(enabled: false, offset: 400))

        let writes = await transport.recordedWrites
        #expect(writes == [Data([0xFE, 0xFE, 0x88, 0xE0, 0x21, 0x00, 0x00, 0x00, 0x00, 0xFD])])
    }

    @Test func rejectsOutOfRangeAndZeroEnabledState() async throws {
        let (proto, _) = try await makeProtocol()

        await #expect(throws: RigError.self) {
            try await proto.setRIT(RITXITState(enabled: true, offset: 501))
        }
        await #expect(throws: RigError.self) {
            try await proto.setRIT(RITXITState(enabled: true, offset: 0))
        }
    }

    @Test func readbackIsExplicitlyUnsupported() async throws {
        let (proto, transport) = try await makeProtocol()

        await #expect(throws: RigError.self) {
            try await proto.getRIT()
        }
        #expect(await transport.recordedWrites.isEmpty)
    }
}
