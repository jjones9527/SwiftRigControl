import Foundation
import Testing
@testable import RigControl

/// G90 full-power readback (v1.2.20).
///
/// At full power the G90 answers the `14 0A` RF-power read with the
/// non-BCD `02 5F` instead of `02 55`, which decoded to 265 on the 0-255
/// scale (103%). Hamlib clamps it (`g90_get_level`, `xiegu.c:1392-1410`,
/// upstream `b61dd14d`).
@Suite struct XieguG90PowerReadTests {

    private static func reply(_ data: [UInt8]) -> CIVFrame {
        CIVFrame(to: CIVFrame.controllerAddress, from: 0x88,
                 command: [CIVFrame.Command.settings, CIVFrame.SettingsCode.rfPower], data: data)
    }

    private let commandSet = StandardIcomCommandSet(
        civAddress: 0x88, vfoModel: .currentOnly, requiresModeFilter: true, echoesCommands: false
    )

    @Test func malformedFullPowerClampsTo100Percent() throws {
        #expect(try commandSet.parsePowerResponse(Self.reply([0x02, 0x5F])) == 100)
    }

    @Test func wellFormedRepliesAreUnchanged() throws {
        #expect(try commandSet.parsePowerResponse(Self.reply([0x02, 0x55])) == 100)
        #expect(try commandSet.parsePowerResponse(Self.reply([0x01, 0x28])) == 50)
        #expect(try commandSet.parsePowerResponse(Self.reply([0x00, 0x00])) == 0)
    }

    @Test func g90GetPowerNeverExceedsFullScale() async throws {
        let mock = MockTransport()
        let proto = try #require(
            RadioDefinition.Xiegu.g90.createProtocol(transport: mock) as? IcomCIVProtocol
        )
        try await proto.connect()
        await mock.setResponse(
            for: Data([0xFE, 0xFE, 0x88, 0xE0, 0x14, 0x0A, 0xFD]),
            response: Data([0xFE, 0xFE, 0xE0, 0x88, 0x14, 0x0A, 0x02, 0x5F, 0xFD])
        )
        #expect(try await proto.getPower() == 100)
    }
}
