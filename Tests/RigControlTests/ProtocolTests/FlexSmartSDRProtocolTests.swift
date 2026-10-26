import Foundation
import Testing
@testable import RigControl

@Suite struct FlexSmartSDRProtocolTests {
    private func connectedProtocol(slice: Int = 0) async throws -> (MockTransport, FlexSmartSDRProtocol) {
        let transport = MockTransport()
        let proto = FlexSmartSDRProtocol(transport: transport, slice: slice)
        let subscribe = "C0|sub slice \(slice)\n".data(using: .ascii)!
        await transport.setResponse(for: subscribe, response: "R0|0|\n".data(using: .ascii)!)
        try await proto.connect()
        await transport.reset()
        return (transport, proto)
    }

    @Test func connectSubscribesToSelectedSlice() async throws {
        let transport = MockTransport()
        let proto = FlexSmartSDRProtocol(transport: transport, slice: 3)
        let command = "C0|sub slice 3\n".data(using: .ascii)!
        await transport.setResponse(for: command, response: "R0|0|\n".data(using: .ascii)!)

        try await proto.connect()

        #expect(await transport.recordedWrites == [command])
    }

    @Test func frequencySetUsesMHzAndAutopan() async throws {
        let (transport, proto) = try await connectedProtocol(slice: 2)
        let command = "C1|slice tune 2 14.230000 autopan=1\n".data(using: .ascii)!
        await transport.setResponse(for: command, response: "R1|0|\n".data(using: .ascii)!)

        try await proto.setFrequency(14_230_000, vfo: .a)

        #expect(await transport.recordedWrites == [command])
    }

    @Test func getFrequencyParsesAsynchronousSliceStatus() async throws {
        let (transport, proto) = try await connectedProtocol(slice: 1)
        await transport.setChunkedResponse([
            "S1234|slice 1 RF_frequency=7.074000 mode=DIGU tx=1\n".data(using: .ascii)!,
            "R1|0|\n".data(using: .ascii)!,
            "S1234|slice 1 RF_frequency=7.074000 mode=DIGU tx=1\n".data(using: .ascii)!,
            "R2|0|\n".data(using: .ascii)!,
        ])

        #expect(try await proto.getFrequency(vfo: .a) == 7_074_000)
        #expect(try await proto.getMode(vfo: .a) == .dataUSB)
    }

    @Test func setModeUsesNativeSmartSDRNames() async throws {
        let (transport, proto) = try await connectedProtocol(slice: 0)
        let command = "C1|slice set 0 mode=DIGL\n".data(using: .ascii)!
        await transport.setResponse(for: command, response: "R1|0|\n".data(using: .ascii)!)

        try await proto.setMode(.dataLSB, vfo: .a)

        #expect(await transport.recordedWrites == [command])
    }

    @Test func pttUsesDAXTransmitSliceAndXmitCommands() async throws {
        let (transport, proto) = try await connectedProtocol(slice: 2)
        let commands = [
            "C1|dax audio set 3 tx=1\n",
            "C2|slice set 2 tx=1\n",
            "C3|xmit 1\n",
        ]
        for (index, command) in commands.enumerated() {
            await transport.setResponse(
                for: command.data(using: .ascii)!,
                response: "R\(index + 1)|0|\n".data(using: .ascii)!
            )
        }

        try await proto.setPTT(true)

        let writes = await transport.recordedWrites.map { String(data: $0, encoding: .ascii)! }
        #expect(writes == commands)
    }

    @Test func cwxReplacesSpacesWithDELAndCanStop() async throws {
        let (transport, proto) = try await connectedProtocol()
        let send = "C1|cwx send \"CQ\u{7F}TEST\"\n".data(using: .ascii)!
        let stop = "C2|cwx clear\n".data(using: .ascii)!
        await transport.setResponse(for: send, response: "R1|0|\n".data(using: .ascii)!)
        await transport.setResponse(for: stop, response: "R2|0|\n".data(using: .ascii)!)

        try await proto.sendCW("CQ TEST")
        try await proto.stopCW()

        #expect(await transport.recordedWrites == [send, stop])
    }

    @Test func commandErrorIsSurfaced() async throws {
        let (transport, proto) = try await connectedProtocol()
        let command = "C1|slice set 0 mode=USB\n".data(using: .ascii)!
        await transport.setResponse(for: command, response: "R1|50001000|\n".data(using: .ascii)!)

        await #expect(throws: RigError.self) {
            try await proto.setMode(.usb, vfo: .a)
        }
    }

    @Test func emptyStatusValuesKeepPreviousState() async throws {
        let (transport, proto) = try await connectedProtocol(slice: 0)
        await proto.parseStatus("S1|slice 0 RF_frequency=14.074000 mode=USB tx=1")
        await proto.parseStatus("S1|interlock state=TRANSMITTING")
        // Hamlib 780da9c: empty `mode=` / `state=` values are rejected,
        // not copied, so they must not clear what was already known.
        await proto.parseStatus("S1|slice 0 RF_frequency= mode= tx=")
        await proto.parseStatus("S1|interlock state=")
        await transport.setChunkedResponse([
            "R1|0|\n".data(using: .ascii)!,
            "R2|0|\n".data(using: .ascii)!,
            "R3|0|\n".data(using: .ascii)!,
        ])

        #expect(try await proto.getFrequency(vfo: .a) == 14_074_000)
        #expect(try await proto.getMode(vfo: .a) == .usb)
        #expect(try await proto.getPTT())
    }

    @Test func nonTransmittingStateClearsPTT() async throws {
        let (transport, proto) = try await connectedProtocol(slice: 0)
        await proto.parseStatus("S1|slice 0 tx=1")
        await proto.parseStatus("S1|interlock state=TRANSMITTING")
        await proto.parseStatus("S1|interlock state=READY")
        await transport.setChunkedResponse(["R1|0|\n".data(using: .ascii)!])

        #expect(try await proto.getPTT() == false)
    }

    @Test func statusForOtherSliceIsIgnored() async throws {
        let (transport, proto) = try await connectedProtocol(slice: 1)
        await proto.parseStatus("S1|slice 1 mode=CW")
        await proto.parseStatus("S1|slice 0 mode=AM")
        await transport.setChunkedResponse(["R1|0|\n".data(using: .ascii)!])

        #expect(try await proto.getMode(vfo: .a) == .cw)
    }

    @Test func narrowFMUsesSmartSDRModeListToken() throws {
        #expect(try FlexSmartSDRProtocol.smartSDRMode(for: .fmN) == "NFM")
        #expect(FlexSmartSDRProtocol.mode(from: "NFM") == .fmN)
        #expect(FlexSmartSDRProtocol.mode(from: "FMN") == .fmN)
    }

    @Test func catalogContainsAllEightNativeSlices() {
        let slices = RadioDefinition.Flex.allRadios.filter { $0.model.hasPrefix("SmartSDR Slice") }
        let expected = ["A", "B", "C", "D", "E", "F", "G", "H"]
            .map { "SmartSDR Slice \($0)" }
        #expect(slices.map(\.model) == expected)
        #expect(slices.allSatisfy { $0.capabilities.supportsSendCW })
        #expect(slices.allSatisfy { !$0.capabilities.hasVFOB })
    }
}
