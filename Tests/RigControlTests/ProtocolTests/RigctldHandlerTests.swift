import Foundation
import Testing
@testable import RigControl

/// Tests for the Phase 4.5 `RigctldCommandHandler` additions:
/// TX-meter levels, CW levels, break-in functions, scanning,
/// antenna selection, and CW send/stop.
///
/// Each test drives the handler against a `RigController` backed
/// by the dummy radio so we can verify the end-to-end path
/// without hardware.
@Suite struct RigctldHandlerTests {

    /// Helper: build a connected controller + handler against a
    /// multi-antenna dummy so antenna and CW tests don't need
    /// separate setup blocks.
    private func makeHandler(antennaCount: Int = 2) async throws -> (RigController, RigctldCommandHandler) {
        let caps = RigCapabilities(antennaCount: antennaCount)
        let rig = try RigController(
            radio: .dummy(name: "Test", capabilities: caps),
            connection: .mock
        )
        try await rig.connect()
        let handler = RigctldCommandHandler(rigController: rig)
        return (rig, handler)
    }

    private func firstLine(_ response: RigctldResponse) -> String {
        response.data.first ?? ""
    }

    // MARK: - TX meters via get_level

    @Test func getLevelSWRReadsFromController() async throws {
        let (rig, handler) = try await makeHandler()
        let proto = await rig.protocol as! DummyCATProtocol
        // Hamlib SWR calibration: raw=48 → ratio=1.5.
        await proto.simulateMeter(.swr, raw: 48)

        let response = await handler.handle(.getLevel(name: "SWR"))
        #expect(response.returnCode == .ok)
        // Float formatted with 6 decimals.
        #expect(firstLine(response) == "1.500000")
    }

    @Test func getLevelRFPowerMeterIsNormalized() async throws {
        let (rig, handler) = try await makeHandler()
        let proto = await rig.protocol as! DummyCATProtocol
        // raw=213 is the 100W breakpoint → normalized = 1.0.
        await proto.simulateMeter(.rfPower, raw: 213)

        let response = await handler.handle(.getLevel(name: "RFPOWER_METER"))
        #expect(response.returnCode == .ok)
        #expect(firstLine(response) == "1.000000")
    }

    @Test func getLevelRFPowerMeterWattsIsWatts() async throws {
        let (rig, handler) = try await makeHandler()
        let proto = await rig.protocol as! DummyCATProtocol
        // raw=143 maps to 50W on the calibration curve.
        await proto.simulateMeter(.rfPower, raw: 143)

        let response = await handler.handle(.getLevel(name: "RFPOWER_METER_WATTS"))
        #expect(response.returnCode == .ok)
        #expect(firstLine(response) == "50.000000")
    }

    @Test func getLevelCompMeterReturnsDB() async throws {
        let (rig, handler) = try await makeHandler()
        let proto = await rig.protocol as! DummyCATProtocol
        // raw=130 → 15 dB compression.
        await proto.simulateMeter(.comp, raw: 130)

        let response = await handler.handle(.getLevel(name: "COMP_METER"))
        #expect(firstLine(response) == "15.000000")
    }

    @Test func getLevelVDMeterReturnsVolts() async throws {
        let (rig, handler) = try await makeHandler()
        let proto = await rig.protocol as! DummyCATProtocol
        // raw=13 → 10 V.
        await proto.simulateMeter(.voltage, raw: 13)

        let response = await handler.handle(.getLevel(name: "VD_METER"))
        #expect(firstLine(response) == "10.000000")
    }

    @Test func getLevelIDMeterReturnsAmps() async throws {
        let (rig, handler) = try await makeHandler()
        let proto = await rig.protocol as! DummyCATProtocol
        // raw=97 → 10 A.
        await proto.simulateMeter(.current, raw: 97)

        let response = await handler.handle(.getLevel(name: "ID_METER"))
        #expect(firstLine(response) == "10.000000")
    }

    // MARK: - CW levels

    @Test func setAndGetKEYSPDRoundtrip() async throws {
        let (_, handler) = try await makeHandler()
        let set = await handler.handle(.setLevel(name: "KEYSPD", value: "25"))
        #expect(set.returnCode == .ok)

        let get = await handler.handle(.getLevel(name: "KEYSPD"))
        #expect(firstLine(get) == "25")
    }

    @Test func setAndGetCWPITCHRoundtrip() async throws {
        let (_, handler) = try await makeHandler()
        let set = await handler.handle(.setLevel(name: "CWPITCH", value: "750"))
        #expect(set.returnCode == .ok)

        let get = await handler.handle(.getLevel(name: "CWPITCH"))
        #expect(firstLine(get) == "750")
    }

    // MARK: - Break-in via set_func/get_func

    @Test func setFuncSBKINSelectsSemi() async throws {
        let (rig, handler) = try await makeHandler()
        let response = await handler.handle(.setFunc(name: "SBKIN", enabled: true))
        #expect(response.returnCode == .ok)
        // Verify the controller actually transitioned.
        let mode = try await rig.breakIn()
        #expect(mode == .semi)
    }

    @Test func setFuncFBKINSelectsFull() async throws {
        let (rig, handler) = try await makeHandler()
        let response = await handler.handle(.setFunc(name: "FBKIN", enabled: true))
        #expect(response.returnCode == .ok)
        let mode = try await rig.breakIn()
        #expect(mode == .full)
    }

    @Test func setFuncSBKINOffTurnsBreakInOff() async throws {
        let (rig, handler) = try await makeHandler()
        // First enable semi, then disable.
        _ = await handler.handle(.setFunc(name: "SBKIN", enabled: true))
        _ = await handler.handle(.setFunc(name: "SBKIN", enabled: false))
        let mode = try await rig.breakIn()
        #expect(mode == .off)
    }

    @Test func getFuncSBKINReflectsState() async throws {
        let (rig, handler) = try await makeHandler()
        try await rig.setBreakIn(.semi)

        let semi = await handler.handle(.getFunc(name: "SBKIN"))
        #expect(firstLine(semi) == "1")

        let full = await handler.handle(.getFunc(name: "FBKIN"))
        #expect(firstLine(full) == "0")
    }

    @Test func setFuncUnknownReturnsNotImplemented() async throws {
        let (_, handler) = try await makeHandler()
        let response = await handler.handle(.setFunc(name: "NOTAREAL", enabled: true))
        #expect(response.returnCode == .notImplemented)
    }

    // MARK: - Antenna

    @Test func setAntPassesThroughToController() async throws {
        let (rig, handler) = try await makeHandler(antennaCount: 2)
        let response = await handler.handle(.setAntenna(antenna: 2, option: nil))
        #expect(response.returnCode == .ok)
        let ant = try await rig.antenna()
        #expect(ant == 2)
    }

    @Test func getAntReturnsFourFieldsHamlibFormat() async throws {
        let (rig, handler) = try await makeHandler(antennaCount: 2)
        try await rig.selectAntenna(1)

        let response = await handler.handle(.getAntenna(antenna: 1))
        #expect(response.returnCode == .ok)
        // Hamlib's get_ant returns: AntCurr Option AntTx AntRx.
        // SwiftRigControl emits them as one value with embedded
        // newlines (joined with '\n' inside the data field), so
        // the response's first line carries them all when default-
        // formatted.
        let formatted = response.formatDefault()
        // First line is AntCurr.
        let firstLine = formatted.split(separator: "\n").first ?? ""
        #expect(firstLine == "1")
        // Total: four whitespace-separated tokens after formatting.
        let tokens = formatted.split(whereSeparator: { $0.isWhitespace })
        #expect(tokens.count == 4)
    }

    @Test func setAntOnSingleAntennaRadioErrors() async throws {
        let (_, handler) = try await makeHandler(antennaCount: 1)
        let response = await handler.handle(.setAntenna(antenna: 1, option: nil))
        // CATProtocol throws .unsupportedOperation; our error
        // mapper turns that into .notSupported in rigctld terms.
        #expect(response.returnCode != .ok)
    }

    // MARK: - Scan

    @Test func scanMEMStartsMemoryScan() async throws {
        let (rig, handler) = try await makeHandler()
        let response = await handler.handle(.scan(function: "MEM", channel: 0))
        #expect(response.returnCode == .ok)
        let proto = await rig.protocol as! DummyCATProtocol
        #expect(await proto.activeScan == .memory)
    }

    @Test func scanSTOPStopsScan() async throws {
        let (rig, handler) = try await makeHandler()
        try await rig.startScan(.vfo)

        let response = await handler.handle(.scan(function: "STOP", channel: 0))
        #expect(response.returnCode == .ok)
        let proto = await rig.protocol as! DummyCATProtocol
        #expect(await proto.activeScan == nil)
    }

    @Test func scanWithUnknownFunctionReturnsInvalidParam() async throws {
        let (_, handler) = try await makeHandler()
        let response = await handler.handle(.scan(function: "BOGUS", channel: 0))
        #expect(response.returnCode == .invalidParam)
    }

    @Test func scanIsCaseInsensitive() async throws {
        let (rig, handler) = try await makeHandler()
        let response = await handler.handle(.scan(function: "vfo", channel: 0))
        #expect(response.returnCode == .ok)
        let proto = await rig.protocol as! DummyCATProtocol
        #expect(await proto.activeScan == .vfo)
    }

    // MARK: - CW send/stop

    @Test func sendMorseDeliversToController() async throws {
        let (rig, handler) = try await makeHandler()
        let response = await handler.handle(.sendMorse(text: "CQ DE VA3ZTF"))
        #expect(response.returnCode == .ok)
        let proto = await rig.protocol as! DummyCATProtocol
        #expect(await proto.lastSentCW == "CQ DE VA3ZTF")
    }

    @Test func stopMorseCallsController() async throws {
        let (rig, handler) = try await makeHandler()
        try await rig.sendCW("CQ")

        let response = await handler.handle(.stopMorse)
        #expect(response.returnCode == .ok)
        let proto = await rig.protocol as! DummyCATProtocol
        #expect(await proto.isSendingCW == false)
    }
}
