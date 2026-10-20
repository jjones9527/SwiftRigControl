import Foundation
import Testing
@testable import RigControl

@Suite struct QRPLabsQMXProtocolTests {
    private static func ascii(_ value: String) -> Data { value.data(using: .ascii)! }

    private func make() async throws -> (MockTransport, QRPLabsQMXProtocol) {
        let transport = MockTransport()
        let proto = QRPLabsQMXProtocol(transport: transport)
        try await transport.open()
        return (transport, proto)
    }

    @Test func catalogMetadataAndCapabilities() {
        let radio = RadioDefinition.QRPLabs.qmx
        #expect(radio.manufacturer == .qrpLabs)
        #expect(radio.model == "QMX")
        #expect(radio.defaultBaudRate == 115_200)
        #expect(radio.preferredDataMode == .usb)
        #expect(radio.verificationStatus == .definition)
        #expect(radio.capabilities.supportedModes == [.lsb, .usb, .cw, .cwR])
        #expect(radio.capabilities.supportsRFPowerMeter)
        #expect(radio.capabilities.supportsSWRMeter)
    }

    @Test func qmxModeStyleUsesPlainUSB() async throws {
        let transport = MockTransport()
        let proto = KenwoodProtocol(transport: transport,
                                    capabilities: RadioCapabilitiesDatabase.QRPLabs.qmx,
                                    modeStyle: .qmx)
        try await proto.connect()
        await transport.reset()
        await transport.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID017;"))
        try await proto.setMode(.usb, vfo: .a)
        #expect(await transport.recordedWrites == [Self.ascii("MD2;"), Self.ascii("ID;")])
    }

    @Test func powerMeterDecodesTenthsOfAWatt() async throws {
        let (transport, proto) = try await make()
        await transport.setResponse(for: Self.ascii("PC;"), response: Self.ascii("PC45;"))
        let reading = try await proto.getRFPowerOut()
        #expect(reading.raw == 45)
        #expect(reading.watts == 4.5)
        #expect(reading.normalized == 0.75)
    }

    @Test func swrMeterDecodesHundredths() async throws {
        let (transport, proto) = try await make()
        await transport.setResponse(for: Self.ascii("SW;"), response: Self.ascii("SW121;"))
        let reading = try await proto.getSWR()
        #expect(reading.raw == 121)
        #expect(reading.swrRatio == 1.21)
    }

    @Test func bareMeterReplyMeansNotTransmitting() async throws {
        let (transport, proto) = try await make()
        await transport.setResponse(for: Self.ascii("PC;"), response: Self.ascii("PC;"))
        let reading = try await proto.getRFPowerOut()
        #expect(reading.watts == 0)
    }

    @Test func definitionBuildsDedicatedAdapter() {
        let proto = RadioDefinition.QRPLabs.qmx.createProtocol(transport: MockTransport())
        #expect(proto is QRPLabsQMXProtocol)
        #expect(proto is any SupportsSplit)
        #expect(proto is any SupportsTXMeters)
    }
}
