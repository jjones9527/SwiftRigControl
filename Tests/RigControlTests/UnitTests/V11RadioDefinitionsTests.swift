import Foundation
import Testing
@testable import RigControl

/// Smoke tests for the v1.1 radio definitions: TH-D75, ID-31,
/// ID-51, ID-52, IC-92D, IC-R30, Lab599 TX-500.
///
/// These confirm each definition can be constructed, that the
/// frequency ranges + capabilities look right, and that
/// `RigController` can connect to them via the mock transport.
@Suite struct V11RadioDefinitionsTests {

    // MARK: - Kenwood TH-D75

    @Test func thd75BasicCaps() {
        let caps = RadioCapabilitiesDatabase.Kenwood.thd75
        #expect(caps.maxPower == 5)
        #expect(caps.hasDualReceiver == true)
        #expect(caps.supportsCTCSS == true)
        // 2m TX
        #expect(caps.canTransmit(on: 146_520_000))
        // 70cm TX
        #expect(caps.canTransmit(on: 446_000_000))
        // 1.25m TX (TH-D75 is tri-band)
        #expect(caps.canTransmit(on: 223_500_000))
        // Airband RX-only
        #expect(!caps.canTransmit(on: 121_500_000))
        #expect(caps.isFrequencyValid(121_500_000))
    }

    @Test func thd75ConnectsViaMock() async throws {
        let rig = try RigController(
            radio: .Kenwood.thd75,
            connection: .mock
        )
        try await rig.connect()
        #expect(await rig.radioName == "Kenwood TH-D75")
    }

    // MARK: - Icom ID-31

    @Test func id31BasicCaps() {
        let caps = RadioCapabilitiesDatabase.Icom.id31
        #expect(caps.hasDualReceiver == false)
        #expect(caps.canTransmit(on: 446_000_000))
        #expect(!caps.canTransmit(on: 145_000_000)) // single-band UHF only
        #expect(caps.supportedFunctions.contains(.ctcssTone))
    }

    @Test func id31ConnectsViaMock() async throws {
        let rig = try RigController(
            radio: .Icom.id31(),
            connection: .mock
        )
        try await rig.connect()
        #expect(await rig.radioName == "Icom ID-31")
    }

    // MARK: - Icom ID-51

    @Test func id51BasicCaps() {
        let caps = RadioCapabilitiesDatabase.Icom.id51
        #expect(caps.hasDualReceiver == true) // Main/Sub
        // Dual-band: 2m + 70cm TX
        #expect(caps.canTransmit(on: 146_520_000))
        #expect(caps.canTransmit(on: 446_000_000))
    }

    @Test func id51ConnectsViaMock() async throws {
        let rig = try RigController(
            radio: .Icom.id51(),
            connection: .mock
        )
        try await rig.connect()
        #expect(await rig.radioName == "Icom ID-51")
    }

    // MARK: - Icom ID-52

    @Test func id52BasicCaps() {
        let caps = RadioCapabilitiesDatabase.Icom.id52
        #expect(caps.hasDualReceiver == true)
        // Airband starts at 108 MHz (vs 118 MHz on ID-51).
        #expect(caps.isFrequencyValid(108_500_000))
        #expect(caps.canTransmit(on: 146_520_000))
        #expect(caps.canTransmit(on: 446_000_000))
    }

    @Test func id52ConnectsViaMock() async throws {
        let rig = try RigController(
            radio: .Icom.id52(),
            connection: .mock
        )
        try await rig.connect()
        #expect(await rig.radioName == "Icom ID-52")
    }

    // MARK: - Icom IC-92D

    @Test func ic92dBasicCaps() {
        let caps = RadioCapabilitiesDatabase.Icom.ic92D
        // Broadband RX VFO A starts at 495 kHz.
        #expect(caps.isFrequencyValid(500_000))
        // 2m TX + 70cm TX (70cm EU limit 440 MHz).
        #expect(caps.canTransmit(on: 146_520_000))
        #expect(caps.canTransmit(on: 432_000_000))
        // Hamlib has FROM_VFO/TO_VFO/MCL on this radio.
        #expect(caps.supportedVFOOperations.contains(.memoryToVFO))
        #expect(caps.supportedFunctions.contains(.lock))
        #expect(caps.supportedFunctions.contains(.monitor))
    }

    @Test func ic92dConnectsViaMock() async throws {
        let rig = try RigController(
            radio: .Icom.ic92D(),
            connection: .mock
        )
        try await rig.connect()
        #expect(await rig.radioName == "Icom IC-92D")
    }

    // MARK: - Icom IC-R30

    @Test func icR30BasicCaps() {
        let caps = RadioCapabilitiesDatabase.Icom.icR30
        #expect(caps.powerControl == false)  // receiver only
        #expect(caps.maxPower == 0)
        #expect(caps.antennaCount == 2)
        // Cellular notch (Region-2)
        #expect(caps.isFrequencyValid(820_000_000))
        #expect(!caps.canTransmit(on: 820_000_000))
        // Wideband coverage
        #expect(caps.isFrequencyValid(2_000_000_000))
    }

    @Test func icR30ConnectsViaMock() async throws {
        let rig = try RigController(
            radio: .Icom.icR30(),
            connection: .mock
        )
        try await rig.connect()
        #expect(await rig.radioName == "Icom IC-R30")
    }

    // MARK: - Lab599 TX-500

    @Test func tx500BasicCaps() {
        let caps = RadioCapabilitiesDatabase.Lab599.tx500
        #expect(caps.maxPower == 10)
        #expect(caps.antennaCount == 2)
        // HF coverage 160m–10m
        #expect(caps.canTransmit(on: 1_900_000))
        #expect(caps.canTransmit(on: 14_200_000))
        #expect(caps.canTransmit(on: 28_500_000))
        // Out-of-band RX
        #expect(caps.isFrequencyValid(15_000_000))
        #expect(!caps.canTransmit(on: 15_000_000))
        // VFO ops include UP/DN/BU/BD per Hamlib tx500.c.
        #expect(caps.supportedVFOOperations.contains(.stepUp))
        #expect(caps.supportedVFOOperations.contains(.bandUp))
        // Has compressor as a function bit.
        #expect(caps.supportedFunctions.contains(.compressor))
    }

    @Test func tx500ConnectsViaMock() async throws {
        let rig = try RigController(
            radio: .Lab599.tx500,
            connection: .mock
        )
        try await rig.connect()
        #expect(await rig.radioName == "Lab599 TX-500")
    }
}
