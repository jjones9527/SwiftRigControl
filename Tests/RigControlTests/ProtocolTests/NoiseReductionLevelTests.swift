import Foundation
import Testing
@testable import RigControl

/// rigctld `L NR` / `l NR` write and read the level alone, scaled as
/// Hamlib scales it on each protocol: Icom `14 06` truncates `f × 255`
/// (`icom.c:3555-3557`, `× 240` on the IC-R75), Kenwood `RL` truncates
/// `f × 9` (`ts590.c:649-653`), Yaesu newcat `RL0` rounds `f × 15`
/// (`newcat.c:4555`). Through v1.3.1 `L NR` sent NR-on first, rounded,
/// and switched NR off for 0.
@Suite struct NoiseReductionLevelTests {

    private static func ascii(_ s: String) -> Data { Data(s.utf8) }

    private static func ack(_ address: UInt8) -> Data {
        Data([0xFE, 0xFE, 0xE0, address, 0xFB, 0xFD])
    }

    private static func nrFrame(_ address: UInt8, _ bcd: [UInt8]) -> Data {
        Data([0xFE, 0xFE, address, 0xE0, 0x14, 0x06] + bcd + [0xFD])
    }

    private func session(_ radio: RadioDefinition) async throws -> (RigctldCommandHandler, MockSerialTransport) {
        let rig = try RigController(radio: radio, connection: .mock)
        try await rig.connect()
        let mock = await rig.rawProtocol.transport as! MockSerialTransport
        await mock.reset()
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID0670;"))
        return (RigctldCommandHandler(rigController: rig), mock)
    }

    private func textWrites(_ mock: MockSerialTransport) async -> [String] {
        await mock.recordedWrites
            .map { String(decoding: $0, as: UTF8.self) }
            .filter { $0 != "ID;" }
    }

    // MARK: - Icom

    @Test(arguments: [
        ("0.5", [UInt8(0x01), 0x27]),
        ("1", [0x02, 0x55]),
        ("0", [0x00, 0x00]),
        ("0.2", [0x00, 0x51]),
    ])
    func icomSendsOnlyTheLevelTruncated(value: String, bcd: [UInt8]) async throws {
        let address = IcomRadioModel.ic7600.defaultCIVAddress
        let (handler, mock) = try await session(.Icom.ic7600())
        let frame = Self.nrFrame(address, bcd)
        await mock.setResponse(for: frame, response: Self.ack(address))
        let response = await handler.handle(.setLevel(name: "NR", value: value))
        #expect(response.returnCode == .ok, "L NR \(value)")
        // No 16 40 (NR on/off), only the level.
        #expect(await mock.recordedWrites == [frame], "L NR \(value)")
    }

    @Test func icomR75LevelIsOutOf240() async throws {
        let address = IcomRadioModel.icr75.defaultCIVAddress
        let (handler, mock) = try await session(.Icom.icR75())
        let frame = Self.nrFrame(address, [0x01, 0x20])
        await mock.setResponse(for: frame, response: Self.ack(address))
        #expect(await handler.handle(.setLevel(name: "NR", value: "0.5")).returnCode == .ok)
        #expect(await mock.recordedWrites == [frame])

        await mock.reset()
        let read = Data([0xFE, 0xFE, address, 0xE0, 0x14, 0x06, 0xFD])
        await mock.setResponse(for: read, response: Data([0xFE, 0xFE, 0xE0, address, 0x14, 0x06, 0x01, 0x20, 0xFD]))
        #expect(await handler.handle(.getLevel(name: "NR")).data == ["0.500000"])
    }

    @Test func icomReadsTheLevelWhetherOrNotNRIsOn() async throws {
        let address = IcomRadioModel.ic7600.defaultCIVAddress
        let (handler, mock) = try await session(.Icom.ic7600())
        let read = Data([0xFE, 0xFE, address, 0xE0, 0x14, 0x06, 0xFD])
        await mock.setResponse(for: read, response: Data([0xFE, 0xFE, 0xE0, address, 0x14, 0x06, 0x01, 0x27, 0xFD]))
        let response = await handler.handle(.getLevel(name: "NR"))
        #expect(response.data == ["0.498039"])
        #expect(await mock.recordedWrites == [read])
    }

    // MARK: - Kenwood and Yaesu newcat

    @Test func kenwoodTruncatesNineSteps() async throws {
        for (value, wire) in [("0.5", "RL04;"), ("1", "RL09;"), ("0.95", "RL08;"), ("0", "RL00;")] {
            let (handler, mock) = try await session(.Kenwood.ts590SG)
            #expect(await handler.handle(.setLevel(name: "NR", value: value)).returnCode == .ok)
            #expect(await textWrites(mock) == [wire], "L NR \(value)")
        }
    }

    @Test func yaesuRoundsFifteenSteps() async throws {
        for (value, wire) in [("0.5", "RL008;"), ("1", "RL015;"), ("0.2", "RL003;")] {
            let (handler, mock) = try await session(.Yaesu.ft991A)
            #expect(await handler.handle(.setLevel(name: "NR", value: value)).returnCode == .ok)
            #expect(await textWrites(mock) == [wire], "L NR \(value)")
        }
    }

    @Test func textProtocolsReadTheLevelAlone() async throws {
        let (kenwood, kenwoodMock) = try await session(.Kenwood.ts590SG)
        await kenwoodMock.setResponse(for: Self.ascii("RL;"), response: Self.ascii("RL03;"))
        let k = await kenwood.handle(.getLevel(name: "NR"))
        #expect(k.data == [String(format: "%.6f", 3.0 / 9.0)])
        #expect(await textWrites(kenwoodMock) == ["RL;"])

        let (yaesu, yaesuMock) = try await session(.Yaesu.ft991A)
        await yaesuMock.setResponse(for: Self.ascii("RL0;"), response: Self.ascii("RL006;"))
        let y = await yaesu.handle(.getLevel(name: "NR"))
        #expect(y.data == [String(format: "%.6f", 6.0 / 15.0)])
        #expect(await textWrites(yaesuMock) == ["RL0;"])
    }

    // MARK: - Library API

    @Test func enabledConfigStillSwitchesNROn() async throws {
        let address = IcomRadioModel.ic7600.defaultCIVAddress
        let rig = try RigController(radio: .Icom.ic7600(), connection: .mock)
        try await rig.connect()
        let mock = await rig.rawProtocol.transport as! MockSerialTransport
        await mock.reset()
        let on = Data([0xFE, 0xFE, address, 0xE0, 0x16, 0x40, 0x01, 0xFD])
        let level = Self.nrFrame(address, [0x01, 0x28])
        await mock.setResponse(for: on, response: Self.ack(address))
        await mock.setResponse(for: level, response: Self.ack(address))
        try await rig.setNoiseReduction(.enabled(level: 128))
        #expect(await mock.recordedWrites == [on, level])
    }
}
