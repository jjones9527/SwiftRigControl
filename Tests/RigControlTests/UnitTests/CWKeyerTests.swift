import Foundation
import Testing
@testable import RigControl

/// Tests for the Phase 4.2 CW keyer API: typed value wrappers
/// (``CWSpeed``, ``CWPitch``, ``BreakInMode``), the encoding
/// helpers on ``IcomCIVProtocol``, and the dummy-served roundtrip.
///
/// Encoding tests cross-check exact byte sequences against
/// Hamlib's `rigs/icom/icom.c` (the `cw_lookup` table and the
/// CWPITCH formula).
@Suite struct CWKeyerTests {

    // MARK: - Value wrappers

    @Test func cwSpeedClampsLow() {
        #expect(CWSpeed(wpm: 0).wpm == 6)
        #expect(CWSpeed(wpm: -5).wpm == 6)
    }

    @Test func cwSpeedClampsHigh() {
        #expect(CWSpeed(wpm: 100).wpm == 48)
        #expect(CWSpeed(wpm: 49).wpm == 48)
    }

    @Test func cwSpeedAcceptsIntegerLiteral() {
        let speed: CWSpeed = 28
        #expect(speed.wpm == 28)
    }

    @Test func cwPitchClampsLow() {
        #expect(CWPitch(hz: 0).hz == 300)
        #expect(CWPitch(hz: 299).hz == 300)
    }

    @Test func cwPitchClampsHigh() {
        #expect(CWPitch(hz: 1000).hz == 900)
        #expect(CWPitch(hz: 901).hz == 900)
    }

    @Test func cwPitchAcceptsIntegerLiteral() {
        let pitch: CWPitch = 600
        #expect(pitch.hz == 600)
    }

    // MARK: - Icom encoding (Hamlib parity)

    @Test func cwSpeedTableMatchesHamlib() {
        // Spot-check Hamlib's cw_lookup at a handful of points.
        // Format: (icom_byte, wpm).
        let table = IcomCIVProtocol.cwSpeedTable
        #expect(table.first?.byte == 0 && table.first?.wpm == 6)
        #expect(table.last?.byte == 250 && table.last?.wpm == 48)
        // Spot-checks against the Hamlib table:
        #expect(table.contains(where: { $0.byte == 84 && $0.wpm == 20 }))
        #expect(table.contains(where: { $0.byte == 144 && $0.wpm == 30 }))
        #expect(table.contains(where: { $0.byte == 175 && $0.wpm == 35 }))
        #expect(table.count == 43)
    }

    @Test func encodeCWSpeedExactBreakpoints() {
        // Direct lookup at known WPM values.
        #expect(IcomCIVProtocol.encodeCWSpeed(wpm: 6) == 0)
        #expect(IcomCIVProtocol.encodeCWSpeed(wpm: 20) == 84)
        #expect(IcomCIVProtocol.encodeCWSpeed(wpm: 30) == 144)
        #expect(IcomCIVProtocol.encodeCWSpeed(wpm: 48) == 250)
    }

    @Test func encodeCWSpeedClampsToRange() {
        #expect(IcomCIVProtocol.encodeCWSpeed(wpm: 0) == 0)    // → 6 WPM → byte 0
        #expect(IcomCIVProtocol.encodeCWSpeed(wpm: 100) == 250) // → 48 WPM → byte 250
    }

    @Test func decodeCWSpeedRoundtrips() {
        // Every breakpoint in the table should round-trip cleanly.
        for entry in IcomCIVProtocol.cwSpeedTable {
            #expect(IcomCIVProtocol.decodeCWSpeed(byte: Int(entry.byte)) == entry.wpm)
        }
    }

    @Test func decodeCWSpeedNearestNeighbor() {
        // Byte 80 is between (79, 19 WPM) and (84, 20 WPM). It's
        // closer to 79 (distance 1) than to 84 (distance 4) so the
        // decoder should return 19.
        #expect(IcomCIVProtocol.decodeCWSpeed(byte: 80) == 19)
        // Byte 83 is closer to 84 (1) than 79 (4) → 20.
        #expect(IcomCIVProtocol.decodeCWSpeed(byte: 83) == 20)
    }

    @Test func encodeCWPitchAtBreakpoints() {
        // Hamlib formula: round((Hz - 300) * 255 / 600).
        #expect(IcomCIVProtocol.encodeCWPitch(hz: 300) == 0)
        #expect(IcomCIVProtocol.encodeCWPitch(hz: 600) == 128)  // round(127.5) → 128
        #expect(IcomCIVProtocol.encodeCWPitch(hz: 900) == 255)
    }

    @Test func encodeCWPitchClamps() {
        #expect(IcomCIVProtocol.encodeCWPitch(hz: 0) == 0)
        #expect(IcomCIVProtocol.encodeCWPitch(hz: 100) == 0)
        #expect(IcomCIVProtocol.encodeCWPitch(hz: 1000) == 255)
    }

    @Test func decodeCWPitchRoundtrips() {
        // 300 Hz and 900 Hz round-trip exactly.
        #expect(IcomCIVProtocol.decodeCWPitch(byte: 0) == 300)
        #expect(IcomCIVProtocol.decodeCWPitch(byte: 255) == 900)
        // 600 Hz is at byte 128 (rounded); decode gives back ~601 due
        // to the formula's resolution. Within ±2 Hz of the request.
        let recovered = IcomCIVProtocol.decodeCWPitch(byte: 128)
        #expect(abs(recovered - 600) <= 2)
    }

    // MARK: - Dummy roundtrip

    @Test func dummyCWSpeedRoundtrip() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        try await rig.setCWSpeed(CWSpeed(wpm: 25))
        let speed = try await rig.cwSpeed()
        #expect(speed.wpm == 25)
    }

    @Test func dummyCWPitchRoundtrip() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        try await rig.setCWPitch(CWPitch(hz: 750))
        let pitch = try await rig.cwPitch()
        #expect(pitch.hz == 750)
    }

    @Test func dummyBreakInRoundtrip() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        for mode in BreakInMode.allCases {
            try await rig.setBreakIn(mode)
            let read = try await rig.breakIn()
            #expect(read == mode)
        }
    }

    @Test func dummySendCWStoresMessage() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        let proto = await rig.rawProtocol as! DummyCATProtocol

        try await rig.sendCW("CQ CQ DE VA3ZTF")
        #expect(await proto.lastSentCW == "CQ CQ DE VA3ZTF")
        #expect(await proto.isSendingCW == true)

        try await rig.stopCW()
        #expect(await proto.isSendingCW == false)
    }

    @Test func dummyTruncatesCWAt30Chars() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        let proto = await rig.rawProtocol as! DummyCATProtocol

        try await rig.sendCW(String(repeating: "A", count: 100))
        let sent = await proto.lastSentCW
        #expect(sent.count == 30)
    }

    @Test func dummyStripsNonASCII() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        let proto = await rig.rawProtocol as! DummyCATProtocol

        try await rig.sendCW("HÉLLO")
        // É is stripped; remaining ASCII reaches the radio.
        let sent = await proto.lastSentCW
        #expect(sent == "HLLO")
    }

    @Test func cwOperationsBeforeConnectThrow() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        await #expect(throws: RigError.self) {
            try await rig.setCWSpeed(20)
        }
        await #expect(throws: RigError.self) {
            try await rig.sendCW("CQ")
        }
    }

    // MARK: - Capability gating

    @Test func unsupportedRadioThrowsForCW() async throws {
        // Build an IcomCIVProtocol with all-default capabilities
        // (CW flags default to false). All CW calls should throw.
        let mock = MockSerialTransport()
        let caps = RigCapabilities()  // no CW support
        let proto = IcomCIVProtocol(
            transport: mock,
            radioModel: .ic7300,
            commandSet: StandardIcomCommandSet(civAddress: 0x94),
            capabilities: caps
        )
        try await proto.connect()
        await #expect(throws: RigError.self) {
            try await proto.setCWSpeed(CWSpeed(wpm: 20))
        }
        await #expect(throws: RigError.self) {
            try await proto.sendCW("CQ")
        }
        await #expect(throws: RigError.self) {
            try await proto.setBreakIn(.semi)
        }
    }

    @Test func verifiedRadiosSupportCW() {
        for caps in [
            RadioCapabilitiesDatabase.Icom.ic7100,
            RadioCapabilitiesDatabase.Icom.ic7600,
            RadioCapabilitiesDatabase.Icom.ic9700,
        ] {
            #expect(caps.supportsCWKeyer)
            #expect(caps.supportsSendCW)
        }
    }
}
