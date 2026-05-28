import Foundation
import Testing
@testable import RigControl

/// Smoke tests for the FlexRadio family — Flex 6000-series via
/// SmartSDR's TCP CAT bridge, and PowerSDR/Thetis via virtual
/// serial CAT.
///
/// All three reuse the Kenwood text protocol; the differences are
/// in capabilities (PowerSDR/Thetis advertise a richer function
/// and meter set per Hamlib `flex6xxx.c`).
@Suite struct FlexRadioDefinitionsTests {

    // MARK: - Flex 6000-series

    @Test func flex6000BasicCaps() {
        let caps = RadioCapabilitiesDatabase.Flex.flex6000
        #expect(caps.maxPower == 100)
        #expect(caps.antennaCount == 3)               // RIG_ANT_1 | _2 | _3
        #expect(caps.hasDualReceiver == true)         // multi-slice
        #expect(caps.hasATU == true)
        // HF TX
        #expect(caps.canTransmit(on: 14_200_000))
        // 6m TX
        #expect(caps.canTransmit(on: 50_125_000))
        // 2m TX
        #expect(caps.canTransmit(on: 146_520_000))
        // Wideband receive between 77 and 135 MHz blocked
        #expect(!caps.isFrequencyValid(100_000_000))
        // 30 kHz lower receive edge
        #expect(caps.isFrequencyValid(30_000))
        // 165 MHz upper receive edge
        #expect(caps.isFrequencyValid(165_000_000))
        // F6K_MODES — no RTTY bit in Hamlib's F6K_MODES set
        #expect(caps.supportedModes.contains(.cw))
        #expect(caps.supportedModes.contains(.dataUSB))
        #expect(caps.supportsCWKeyer == true)
    }

    @Test func flex6000ConnectsViaMock() async throws {
        let rig = try RigController(
            radio: .Flex.flex6000,
            connection: .mock
        )
        try await rig.connect()
        #expect(await rig.radioName == "FlexRadio 6000-series")
    }

    // MARK: - PowerSDR

    @Test func powerSDRCapsSuperset() {
        let caps = RadioCapabilitiesDatabase.Flex.powerSDR
        #expect(caps.maxPower == 100)
        #expect(caps.antennaCount == 3)
        // POWERSDR_LEVEL_ALL includes RFPOWER_METER + SWR.
        #expect(caps.supportsRFPowerMeter == true)
        #expect(caps.supportsSWRMeter == true)
        // POWERSDR_FUNC_ALL includes VOX / ANF / MUTE / TUNER as
        // pure on/off bits (SQL / NB / RIT / XIT live on traits).
        #expect(caps.supportedFunctions.contains(.vox))
        #expect(caps.supportedFunctions.contains(.autoNotch))
        #expect(caps.supportedFunctions.contains(.mute))
        #expect(caps.supportedFunctions.contains(.tuner))
        // POWERSDR_VFO_OP — band step + tuning step.
        #expect(caps.supportedVFOOperations.contains(.stepUp))
        #expect(caps.supportedVFOOperations.contains(.bandUp))
    }

    @Test func powerSDRConnectsViaMock() async throws {
        let rig = try RigController(
            radio: .Flex.powerSDR,
            connection: .mock
        )
        try await rig.connect()
        #expect(await rig.radioName == "FlexRadio PowerSDR")
    }

    // MARK: - Thetis

    @Test func thetisMatchesPowerSDR() {
        let p = RadioCapabilitiesDatabase.Flex.powerSDR
        let t = RadioCapabilitiesDatabase.Flex.thetis
        // Same Hamlib macros; surface should be identical.
        #expect(p.supportedFunctions == t.supportedFunctions)
        #expect(p.supportedVFOOperations == t.supportedVFOOperations)
        #expect(p.antennaCount == t.antennaCount)
        #expect(p.supportsRFPowerMeter == t.supportsRFPowerMeter)
        #expect(p.supportsSWRMeter == t.supportsSWRMeter)
    }

    @Test func thetisConnectsViaMock() async throws {
        let rig = try RigController(
            radio: .Flex.thetis,
            connection: .mock
        )
        try await rig.connect()
        #expect(await rig.radioName == "FlexRadio Thetis")
    }

    // MARK: - Manufacturer brand tag

    @Test func flexManufacturerBrand() {
        // Hamlib lists Flex as `mfg_name = "FlexRadio"`; SwiftRigControl
        // matches via the .flex Manufacturer case.
        #expect(RadioDefinition.Flex.flex6000.manufacturer == .flex)
        #expect(RadioDefinition.Flex.powerSDR.manufacturer == .flex)
        #expect(RadioDefinition.Flex.thetis.manufacturer == .flex)
        #expect(RadioDefinition.Manufacturer.flex.rawValue == "FlexRadio")
    }
}
