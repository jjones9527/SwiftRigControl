import Foundation
import Testing
@testable import RigControl

/// Tests for `MeterReading` value type and its calibration curves.
///
/// Curve breakpoints are transcribed from Hamlib's
/// `icom_default_*_cal` tables in `rigs/icom/icom.c`. These tests
/// assert that the same raw input produces the same physical-unit
/// output as Hamlib, so SwiftRigControl behaves identically to
/// a Hamlib-backed app on Icom radios.
@Suite struct MeterReadingTests {

    // MARK: - RF power calibration

    @Test func rfPowerCurveAtBreakpoints() {
        // Spot-check Hamlib's icom_default_rfpower_meter_cal points.
        #expect(MeterReading.decode(kind: .rfPower, raw: 0).watts == 0.0)
        #expect(MeterReading.decode(kind: .rfPower, raw: 21).watts == 5.0)
        #expect(MeterReading.decode(kind: .rfPower, raw: 143).watts == 50.0)
        #expect(MeterReading.decode(kind: .rfPower, raw: 213).watts == 100.0)
        #expect(MeterReading.decode(kind: .rfPower, raw: 255).watts == 120.0)
    }

    @Test func rfPowerCurveInterpolatesBetweenBreakpoints() {
        // Halfway between (21, 5W) and (43, 10W) = (32, 7.5W).
        let r = MeterReading.decode(kind: .rfPower, raw: 32)
        let w = try? #require(r.watts)
        #expect(abs((w ?? 0) - 7.5) < 0.1)
    }

    @Test func rfPowerNormalizedHitsOneAt100W() {
        // raw=213 is the 100 W breakpoint in the curve.
        let r = MeterReading.decode(kind: .rfPower, raw: 213)
        #expect(abs(r.normalized - 1.0) < 0.001)
    }

    // MARK: - SWR calibration

    @Test func swrCurveAtBreakpoints() {
        #expect(MeterReading.decode(kind: .swr, raw: 0).swrRatio == 1.0)
        #expect(MeterReading.decode(kind: .swr, raw: 48).swrRatio == 1.5)
        #expect(MeterReading.decode(kind: .swr, raw: 80).swrRatio == 2.0)
        #expect(MeterReading.decode(kind: .swr, raw: 120).swrRatio == 3.0)
        #expect(MeterReading.decode(kind: .swr, raw: 240).swrRatio == 6.0)
    }

    @Test func swrNormalizedAtMatchedAntenna() {
        let r = MeterReading.decode(kind: .swr, raw: 0)
        #expect(r.normalized == 0.0)  // 1:1 SWR → 0 on the bar
    }

    @Test func swrAccessorsOnlyForSWR() {
        let r = MeterReading.decode(kind: .alc, raw: 100)
        #expect(r.swrRatio == nil)
        #expect(r.watts == nil)
        #expect(r.volts == nil)
    }

    // MARK: - Other meters

    @Test func compCurve() {
        #expect(MeterReading.decode(kind: .comp, raw: 0).dB == 0.0)
        #expect(MeterReading.decode(kind: .comp, raw: 130).dB == 15.0)
        #expect(MeterReading.decode(kind: .comp, raw: 241).dB == 30.0)
    }

    @Test func voltageCurve() {
        #expect(MeterReading.decode(kind: .voltage, raw: 0).volts == 0.0)
        #expect(MeterReading.decode(kind: .voltage, raw: 13).volts == 10.0)
        #expect(MeterReading.decode(kind: .voltage, raw: 241).volts == 16.0)
    }

    @Test func currentCurve() {
        #expect(MeterReading.decode(kind: .current, raw: 0).amps == 0.0)
        #expect(MeterReading.decode(kind: .current, raw: 97).amps == 10.0)
        #expect(MeterReading.decode(kind: .current, raw: 146).amps == 15.0)
        #expect(MeterReading.decode(kind: .current, raw: 241).amps == 25.0)
    }

    @Test func alcSaturatesAtRaw120() {
        let r = MeterReading.decode(kind: .alc, raw: 120)
        #expect(abs(r.normalized - 1.0) < 0.001)
    }

    // MARK: - Description formatting

    @Test func descriptions() {
        #expect(MeterReading.decode(kind: .rfPower, raw: 143).description == "50.0 W")
        #expect(MeterReading.decode(kind: .swr, raw: 80).description == "2.0:1")
        #expect(MeterReading.decode(kind: .voltage, raw: 13).description == "10.0 V")
        #expect(MeterReading.decode(kind: .current, raw: 97).description == "10.0 A")
        #expect(MeterReading.decode(kind: .comp, raw: 130).description == "15.0 dB")
    }

    // MARK: - Dummy radio integration

    @Test func dummyServesSimulatedReadings() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        let proto = await rig.rawProtocol as! DummyCATProtocol

        // Simulate transmitting at ~50 W with 1.5:1 SWR.
        await proto.simulateMeter(.rfPower, raw: 143)
        await proto.simulateMeter(.swr, raw: 48)
        await proto.simulateMeter(.alc, raw: 60)

        let power = try await rig.rfPowerOut()
        let swr = try await rig.swr()
        let alc = try await rig.alc()

        #expect(power.watts == 50.0)
        #expect(swr.swrRatio == 1.5)
        #expect(alc.normalized == 0.5)  // raw=60 / 120 saturation point
    }

    @Test func dummyReportsIdleReadingsByDefault() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()

        let power = try await rig.rfPowerOut()
        let swr = try await rig.swr()
        let voltage = try await rig.voltage()

        // RF power: 0 (not transmitting).
        #expect(power.watts == 0.0)
        // SWR: 1:1 (nothing to measure).
        #expect(swr.swrRatio == 1.0)
        // Voltage: ~13.8 V (defaultraw = 105, curve gives ~13.8).
        #expect(voltage.volts ?? 0 > 13.0)
        #expect(voltage.volts ?? 0 < 14.0)
    }

    @Test func operationsBeforeConnectThrow() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        await #expect(throws: RigError.self) {
            _ = try await rig.rfPowerOut()
        }
    }

    @Test func unsupportedMeterThrows() async throws {
        // Build a capability set without TX-meter flags, then
        // confirm calls throw .unsupportedOperation. We do this
        // through a real protocol, not the dummy — the dummy
        // implements meters regardless of caps (it's a simulator).
        let mock = MockSerialTransport()
        let caps = RigCapabilities(
            // All TX-meter flags default to false.
        )
        let proto = IcomCIVProtocol(
            transport: mock,
            radioModel: .ic7300,
            commandSet: StandardIcomCommandSet(civAddress: 0x94),
            capabilities: caps
        )
        try await proto.connect()
        await #expect(throws: RigError.self) {
            _ = try await proto.getRFPowerOut()
        }
        await #expect(throws: RigError.self) {
            _ = try await proto.getSWR()
        }
    }

    @Test func verifiedRadiosHaveAllMeters() {
        // All four hardware-verified Icoms have all six meters.
        // K2 is Elecraft and has none (no protocol-level support).
        let ic7100 = RigCapabilities.icomIC7100
        let ic7600 = RigCapabilities.icomIC7600
        let ic9700 = RigCapabilities.icomIC9700
        for caps in [ic7100, ic7600, ic9700] {
            #expect(caps.supportsRFPowerMeter)
            #expect(caps.supportsSWRMeter)
            #expect(caps.supportsALCMeter)
            #expect(caps.supportsCompMeter)
            #expect(caps.supportsVoltageMeter)
            #expect(caps.supportsCurrentMeter)
        }
    }
}

// Convenience extension so the verifiedRadiosHaveAllMeters test
// can reach the three Icom capability constants without the
// RadioCapabilitiesDatabase prefix.
private extension RigCapabilities {
    static var icomIC7100: RigCapabilities { RadioCapabilitiesDatabase.icomIC7100 }
    static var icomIC7600: RigCapabilities { RadioCapabilitiesDatabase.icomIC7600 }
    static var icomIC9700: RigCapabilities { RadioCapabilitiesDatabase.icomIC9700 }
}
