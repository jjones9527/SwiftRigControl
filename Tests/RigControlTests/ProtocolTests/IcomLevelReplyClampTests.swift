import Foundation
import Testing
@testable import RigControl

/// Out-of-range Icom level and meter replies must not trap.
///
/// Found by the Hamlib differential audit: `simxiegug90` answered the AF
/// read `14 01` with `55 00`, which three-digit BCD decodes to 500. The
/// level parsers passed that straight to `UInt8(_:)`, which traps
/// ("Not enough bits to represent the passed value") and kills the host
/// app. Hamlib reads the same reply without trouble (`icom_get_level`
/// divides by 255). Levels are now clamped to 0–255 through
/// `BCDEncoding.decodeLevel(_:)`.
@Suite struct IcomLevelReplyClampTests {

    @Test func decodeLevelClampsToCIVScale() {
        #expect(BCDEncoding.decodeLevel([0x00, 0x00]) == 0)
        #expect(BCDEncoding.decodeLevel([0x01, 0x28]) == 128)
        #expect(BCDEncoding.decodeLevel([0x02, 0x55]) == 255)
        #expect(BCDEncoding.decodeLevel([0x02, 0x56]) == 255)
        #expect(BCDEncoding.decodeLevel([0x55, 0x00]) == 255)
        #expect(BCDEncoding.decodeLevel([0x09, 0x99]) == 255)
        #expect(BCDEncoding.decodeLevel([0x00]) == 0)
    }

    private func connected(_ radio: RadioDefinition) async throws -> (MockTransport, IcomCIVProtocol) {
        let mock = MockTransport()
        let proto = try #require(radio.createProtocol(transport: mock) as? IcomCIVProtocol)
        try await proto.connect()
        return (mock, proto)
    }

    /// The exact exchange that crashed the audit client.
    @Test func g90AFReadWithOutOfRangeReplyClamps() async throws {
        let (mock, g90) = try await connected(.Xiegu.g90)
        await mock.setResponse(
            for: Data([0xFE, 0xFE, 0x88, 0xE0, 0x14, 0x01, 0xFD]),
            response: Data([0xFE, 0xFE, 0xE0, 0x88, 0x14, 0x01, 0x55, 0x00, 0xFD])
        )
        #expect(try await g90.getAFGain() == 255)
    }

    @Test func meterReadWithOutOfRangeReplyClamps() async throws {
        let (mock, g90) = try await connected(.Xiegu.g90)
        await mock.setResponse(
            for: Data([0xFE, 0xFE, 0x88, 0xE0, 0x15, 0x02, 0xFD]),
            response: Data([0xFE, 0xFE, 0xE0, 0x88, 0x15, 0x02, 0x09, 0x99, 0xFD])
        )
        #expect(try await g90.getSMeterLevel() == 255)
    }

    @Test func inRangeReplyIsUnchanged() async throws {
        let (mock, g90) = try await connected(.Xiegu.g90)
        await mock.setResponse(
            for: Data([0xFE, 0xFE, 0x88, 0xE0, 0x14, 0x01, 0xFD]),
            response: Data([0xFE, 0xFE, 0xE0, 0x88, 0x14, 0x01, 0x01, 0x28, 0xFD])
        )
        #expect(try await g90.getAFGain() == 128)
    }
}
