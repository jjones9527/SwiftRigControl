import Foundation
import Testing
@testable import RigControl

/// RF power units, end to end.
///
/// CI-V `14 0A` is a 0–255 fraction of rated output on every Icom and
/// Xiegu: Hamlib sends `fraction × 255` whatever the wattage
/// (`icom.c:3558`). Kenwood, Yaesu newcat and Elecraft `PC` is watts
/// (`kenwood.c:3459`, `ftdx101mp.c:121`, `k3.c:2023`).
///
/// Through v1.3.1 rigctld `L RFPOWER` always converted to watts and the
/// catalog said `.percentage` for nearly every radio, so on a 200 W
/// IC-7851 `L RFPOWER 0.5` keyed full power, on a 10 W IC-705 `1.0` gave
/// 10%, and the 200 W Kenwood / Yaesu radios got a percentage in `PC`.
/// The CI-V frames below were checked against Hamlib `91e7b97` with
/// `Scripts/hamlib-set-matrix.py`.
@Suite struct PowerUnitsTests {

    private static func ack(_ address: UInt8) -> Data {
        Data([0xFE, 0xFE, 0xE0, address, 0xFB, 0xFD])
    }

    private static func powerFrame(_ address: UInt8, _ bcd: [UInt8]) -> Data {
        Data([0xFE, 0xFE, address, 0xE0, 0x14, 0x0A] + bcd + [0xFD])
    }

    private func makeIcom(_ radio: RadioDefinition, address: UInt8) async throws
        -> (RigController, RigctldCommandHandler, MockSerialTransport)
    {
        let rig = try RigController(radio: radio, connection: .mock)
        try await rig.connect()
        let mock = await rig.rawProtocol.transport as! MockSerialTransport
        await mock.reset()
        return (rig, RigctldCommandHandler(rigController: rig), mock)
    }

    // MARK: - Catalog

    /// Every catalog radio's `powerUnits` matches what its protocol's
    /// `setPower` takes.
    @Test func catalogPowerUnitsFollowTheProtocol() {
        let transport = MockSerialTransport()
        for radio in RadioDefinition.allSupportedRadios {
            let caps = radio.capabilities
            if radio.createProtocol(transport: transport) is IcomCIVProtocol {
                #expect(caps.powerUnits == .percentage, "\(radio.fullName)")
            } else {
                #expect(caps.powerUnits == .watts(max: caps.maxPower), "\(radio.fullName)")
            }
        }
    }

    @Test func capabilitiesDefaultToWatts() {
        #expect(RigCapabilities(maxPower: 15).powerUnits == .watts(max: 15))
        #expect(RigCapabilities(maxPower: 10, powerUnits: .percentage).powerUnits == .percentage)
    }

    // MARK: - rigctld RFPOWER on CI-V radios

    @Test(arguments: [
        ("IC-705 (10 W)", RadioDefinition.Icom.ic705(), UInt8(0xA4)),
        ("IC-7851 (200 W)", RadioDefinition.Icom.ic7851(), UInt8(0x8E)),
        ("G90 (20 W)", RadioDefinition.Xiegu.g90, UInt8(0x88)),
    ])
    func rigctldRFPowerSendsAFractionOf255(name: String, radio: RadioDefinition, address: UInt8) async throws {
        for (value, bcd) in [("0.5", [UInt8(0x01), 0x27]), ("1", [0x02, 0x55]), ("0.05", [0x00, 0x12])] {
            let (_, handler, mock) = try await makeIcom(radio, address: address)
            let frame = Self.powerFrame(address, bcd)
            await mock.setResponse(for: frame, response: Self.ack(address))
            let response = await handler.handle(.setLevel(name: "RFPOWER", value: value))
            #expect(response.returnCode == .ok, "\(name) \(value)")
            #expect(await mock.recordedWrites.contains(frame), "\(name) L RFPOWER \(value)")
        }
    }

    @Test func rigctldRFPowerReadsAFractionOf255() async throws {
        let (_, handler, mock) = try await makeIcom(.Icom.ic705(), address: 0xA4)
        await mock.setResponse(
            for: Data([0xFE, 0xFE, 0xA4, 0xE0, 0x14, 0x0A, 0xFD]),
            response: Self.powerFrame(0xA4, [0x01, 0x27]).replacingAddresses(radio: 0xA4)
        )
        let response = await handler.handle(.getLevel(name: "RFPOWER"))
        // 127/255 is 49%. Through v1.3.1 this was 49 / 10 W, clamped to 1.0.
        #expect(response.data == ["0.490000"])
    }

    // MARK: - RigController.setPower range

    @Test func percentageRadiosAcceptZeroToHundred() async throws {
        let (rig, _, mock) = try await makeIcom(.Icom.ic705(), address: 0xA4)
        let frame = Self.powerFrame(0xA4, [0x01, 0x27])
        await mock.setResponse(for: frame, response: Self.ack(0xA4))
        try await rig.setPower(50)   // threw "between 0 and 10" through v1.3.1
        #expect(await mock.recordedWrites.contains(frame))
        await #expect(throws: RigError.self) { try await rig.setPower(101) }
    }

    // MARK: - Watts on the wire

    @Test func yaesuNewcatPCIsWatts() async throws {
        let mock = MockTransport()
        let proto = try #require(
            RadioDefinition.Yaesu.ftdx101MP.createProtocol(transport: mock) as? YaesuCATProtocol
        )
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Data("ID;".utf8), response: Data("ID0682;".utf8))
        try await proto.setPower(150)
        #expect(await mock.recordedWrites.first == Data("PC150;".utf8))

        await mock.reset()
        await mock.setResponse(for: Data("PC;".utf8), response: Data("PC150;".utf8))
        #expect(try await proto.getPower() == 150)
    }

    @Test func kenwoodPCIsWatts() async throws {
        let mock = MockTransport()
        let proto = try #require(
            RadioDefinition.Lab599.tx500.createProtocol(transport: mock) as? KenwoodProtocol
        )
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Data("ID;".utf8), response: Data("ID019;".utf8))
        try await proto.setPower(5)
        #expect(await mock.recordedWrites.first == Data("PC005;".utf8))   // was PC050

        await mock.reset()
        await mock.setResponse(for: Data("PC;".utf8), response: Data("PC010;".utf8))
        #expect(try await proto.getPower() == 10)
    }
}

private extension Data {
    /// Turns a frame addressed to the radio into the radio's reply.
    func replacingAddresses(radio: UInt8) -> Data {
        var bytes = [UInt8](self)
        bytes[2] = 0xE0
        bytes[3] = radio
        return Data(bytes)
    }
}
