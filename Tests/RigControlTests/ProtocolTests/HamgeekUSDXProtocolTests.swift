import Foundation
import Testing
@testable import RigControl

@Suite struct HamgeekUSDXProtocolTests {
    private static func ascii(_ value: String) -> Data { value.data(using: .ascii)! }

    private func make() async throws -> (MockTransport, HamgeekUSDXProtocol) {
        let transport = MockTransport()
        let proto = HamgeekUSDXProtocol(transport: transport)
        try await proto.connect()
        await transport.reset()
        return (transport, proto)
    }

    @Test func catalogMetadataMatchesHamlib() {
        let radio = RadioDefinition.Hamgeek.usdx
        #expect(radio.manufacturer == .hamgeek)
        #expect(radio.defaultBaudRate == 115_200)
        #expect(radio.preferredDataMode == .usb)
        #expect(!radio.capabilities.hasVFOB)
        #expect(!radio.capabilities.hasSplit)
        #expect(radio.capabilities.maxPower == 5)
        #expect(radio.verificationStatus == .definition)
    }

    @Test func frequencyUsesOnlyFAWithoutIDVerification() async throws {
        let (transport, proto) = try await make()
        try await proto.setFrequency(14_074_000, vfo: .a)
        #expect(await transport.recordedWrites == [Self.ascii("FA00014074000;")])

        await transport.setResponse(for: Self.ascii("FA;"), response: Self.ascii("FA00014074000;"))
        #expect(try await proto.getFrequency(vfo: .main) == 14_074_000)
    }

    @Test func aliasesFirmwareLimitedModes() async throws {
        let (transport, proto) = try await make()
        try await proto.setMode(.dataUSB, vfo: .a)
        try await proto.setMode(.dataLSB, vfo: .a)
        try await proto.setMode(.cwR, vfo: .a)
        #expect(await transport.recordedWrites == [
            Self.ascii("MD2;"), Self.ascii("MD1;"), Self.ascii("MD3;")
        ])
    }

    @Test func modeReadbackUsesMDOneThroughFive() async throws {
        let (transport, proto) = try await make()
        await transport.setResponse(for: Self.ascii("MD;"), response: Self.ascii("MD5;"))
        #expect(try await proto.getMode(vfo: .a) == .am)
    }

    @Test func pttReleaseDrainsRX0Reply() async throws {
        let (transport, proto) = try await make()
        await transport.setResponse(for: Self.ascii("RX;"), response: Self.ascii("RX0;"))
        try await proto.setPTT(true)
        try await proto.setPTT(false)
        #expect(await transport.recordedWrites == [Self.ascii("TX;"), Self.ascii("RX;")])
        #expect(try await proto.getPTT() == false)
    }

    @Test func nonPrintableFirmwareGarbageIsRemoved() async throws {
        let (transport, proto) = try await make()
        await transport.setResponse(
            for: Self.ascii("MD;"),
            response: Data([0x00, 0xFF]) + Self.ascii("MD2;")
        )
        #expect(try await proto.getMode(vfo: .a) == .usb)
    }

    @Test func vfoBIsRejectedAndVfoADoesNotWrite() async throws {
        let (transport, proto) = try await make()
        try await proto.selectVFO(.a)
        #expect(await transport.recordedWrites.isEmpty)
        await #expect(throws: RigError.self) {
            try await proto.selectVFO(.b)
        }
    }

    @Test func definitionBuildsDedicatedMinimalAdapter() {
        let proto = RadioDefinition.Hamgeek.usdx.createProtocol(transport: MockTransport())
        #expect(proto is HamgeekUSDXProtocol)
        #expect(!(proto is any SupportsSplit))
        #expect(!(proto is any SupportsPower))
    }
}
