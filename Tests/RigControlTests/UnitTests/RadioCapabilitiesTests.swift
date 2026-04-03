import Testing
@testable import RigControl

/// Unit tests for radio capabilities and frequency validation
@Suite struct RadioCapabilitiesTests {

    // MARK: - Amateur Band Tests

    @Test func amateurBand20mContainsFrequency() {
        let band20m = Region2AmateurBand.band20m
        #expect(band20m.contains(14_200_000), "14.200 MHz should be in the 20m band")
        #expect(band20m.contains(14_000_000), "14.000 MHz should be at the start of 20m")
        #expect(band20m.contains(14_350_000), "14.350 MHz should be at the end of 20m")
        #expect(!band20m.contains(7_100_000), "7.100 MHz should not be in 20m")
    }

    @Test func amateurBandLookup() {
        // Test 20m band
        let band20m = Region2AmateurBand.band(for: 14_200_000)
        #expect(band20m == .band20m, "14.200 MHz should resolve to 20m band")

        // Test 40m band
        let band40m = Region2AmateurBand.band(for: 7_100_000)
        #expect(band40m == .band40m, "7.100 MHz should resolve to 40m band")

        // Test non-amateur frequency
        let noband = Region2AmateurBand.band(for: 5_000_000)
        #expect(noband == nil, "5.000 MHz is not in an amateur band")
    }

    @Test func amateurBandCommonModes() {
        // 20m should have USB
        #expect(Region2AmateurBand.band20m.commonModes.contains(.usb))

        // 80m should have LSB
        #expect(Region2AmateurBand.band80m.commonModes.contains(.lsb))

        // 30m should have CW and USB (digital) but not voice modes
        #expect(Region2AmateurBand.band30m.commonModes.contains(.cw))
        #expect(Region2AmateurBand.band30m.commonModes.contains(.usb))

        // 2m should have FM
        #expect(Region2AmateurBand.band2m.commonModes.contains(.fm))
    }

    // MARK: - IC-7300 Capability Tests

    @Test func ic7300ValidFrequency() {
        let caps = RadioCapabilitiesDatabase.icomIC7300

        // Test valid HF frequency
        #expect(caps.isFrequencyValid(14_200_000), "14.200 MHz should be valid for IC-7300")

        // Test valid 6m frequency
        #expect(caps.isFrequencyValid(50_100_000), "50.100 MHz should be valid for IC-7300")

        // Test receive-only frequency
        #expect(caps.isFrequencyValid(500_000), "500 kHz should be valid for receive")

        // Test out of range
        #expect(!caps.isFrequencyValid(100_000_000), "100 MHz should be out of range")
    }

    @Test func ic7300TransmitCapability() {
        let caps = RadioCapabilitiesDatabase.icomIC7300

        // Should be able to transmit on 20m
        #expect(caps.canTransmit(on: 14_200_000), "Should be able to transmit on 20m")

        // Should NOT be able to transmit on MW
        #expect(!caps.canTransmit(on: 500_000), "Should NOT transmit on MW (receive only)")

        // Should be able to transmit on 6m
        #expect(caps.canTransmit(on: 50_100_000), "Should be able to transmit on 6m")
    }

    @Test func ic7300BandNames() {
        let caps = RadioCapabilitiesDatabase.icomIC7300

        #expect(caps.bandName(for: 14_200_000) == "20m", "14.200 MHz should be identified as 20m")
        #expect(caps.bandName(for: 7_100_000) == "40m", "7.100 MHz should be identified as 40m")
        #expect(caps.bandName(for: 500_000) == nil, "500 kHz should not have a band name")
    }

    @Test func ic7300SupportedModes() {
        let caps = RadioCapabilitiesDatabase.icomIC7300

        // Test 20m modes
        let modes20m = caps.supportedModes(for: 14_200_000)
        #expect(modes20m.contains(.usb), "IC-7300 should support USB on 20m")
        #expect(modes20m.contains(.cw), "IC-7300 should support CW on 20m")

        // Test receive-only range
        let modesReceive = caps.supportedModes(for: 500_000)
        #expect(!modesReceive.isEmpty, "IC-7300 should have modes for receive frequencies")
    }

    // MARK: - IC-9700 Capability Tests

    @Test func ic9700ValidFrequency() {
        let caps = RadioCapabilitiesDatabase.icomIC9700

        // Should be valid on 2m
        #expect(caps.isFrequencyValid(146_000_000), "146 MHz should be valid on IC-9700")

        // Should be valid on 70cm
        #expect(caps.isFrequencyValid(440_000_000), "440 MHz should be valid on IC-9700")

        // Should be valid on 23cm
        #expect(caps.isFrequencyValid(1_296_000_000), "1296 MHz should be valid on IC-9700")

        // Should be invalid below range
        #expect(!caps.isFrequencyValid(10_000), "10 kHz should be out of range")
    }

    @Test func ic9700TransmitCapability() {
        let caps = RadioCapabilitiesDatabase.icomIC9700

        // Should transmit on 2m
        #expect(caps.canTransmit(on: 146_000_000), "Should transmit on 2m")

        // Should transmit on 70cm
        #expect(caps.canTransmit(on: 440_000_000), "Should transmit on 70cm")

        // Should NOT transmit on HF (receive only)
        #expect(!caps.canTransmit(on: 14_200_000), "Should NOT transmit on HF (receive only)")
    }

    // MARK: - FT-991A Capability Tests

    @Test func ft991AValidFrequency() {
        let caps = RadioCapabilitiesDatabase.yaesuFT991A

        // Should be valid on HF
        #expect(caps.isFrequencyValid(14_200_000), "14.200 MHz should be valid")

        // Should be valid on 2m
        #expect(caps.isFrequencyValid(146_000_000), "146 MHz should be valid")

        // Should be valid on 70cm
        #expect(caps.isFrequencyValid(440_000_000), "440 MHz should be valid")
    }

    @Test func ft991ATransmitCapability() {
        let caps = RadioCapabilitiesDatabase.yaesuFT991A

        // Should transmit on 20m
        #expect(caps.canTransmit(on: 14_200_000), "Should transmit on 20m")

        // Should transmit on 2m
        #expect(caps.canTransmit(on: 146_000_000), "Should transmit on 2m")

        // Should NOT transmit on receive-only frequencies
        #expect(!caps.canTransmit(on: 5_000_000), "Should NOT transmit outside amateur bands")
    }

    // MARK: - Kenwood TS-590SG Tests

    @Test func ts590SGValidFrequency() {
        let caps = RadioCapabilitiesDatabase.kenwoodTS590SG

        // Valid HF frequencies
        #expect(caps.isFrequencyValid(14_200_000), "14.200 MHz should be valid")
        #expect(caps.isFrequencyValid(7_100_000), "7.100 MHz should be valid")

        // Out of range (TS-590SG doesn't cover VHF/UHF)
        #expect(!caps.isFrequencyValid(146_000_000), "146 MHz should be out of range")
    }

    // MARK: - Elecraft K3 Tests

    @Test func elecraftK3ValidFrequency() {
        let caps = RadioCapabilitiesDatabase.elecraftK3

        // Valid HF frequencies
        #expect(caps.isFrequencyValid(14_200_000), "14.200 MHz should be valid")

        // Valid 6m frequency
        #expect(caps.isFrequencyValid(50_100_000), "50.100 MHz should be valid")

        // Out of range
        #expect(!caps.isFrequencyValid(146_000_000), "146 MHz should be out of range")
    }

    @Test func elecraftK3TransmitCapability() {
        let caps = RadioCapabilitiesDatabase.elecraftK3

        // Should transmit on amateur bands
        #expect(caps.canTransmit(on: 14_200_000), "Should transmit on 20m")

        // Should NOT transmit on receive-only frequencies
        #expect(!caps.canTransmit(on: 5_000_000), "Should NOT transmit outside amateur bands")
    }

    // MARK: - Edge Case Tests

    @Test func bandEdgeFrequencies() {
        let caps = RadioCapabilitiesDatabase.icomIC7300

        // Test exact band edge frequencies
        #expect(caps.isFrequencyValid(14_000_000), "14.000 MHz should be at start of 20m")
        #expect(caps.isFrequencyValid(14_350_000), "14.350 MHz should be at end of 20m")

        // Just outside band edges (in receive-only gap)
        #expect(caps.isFrequencyValid(14_350_001), "14.350001 MHz should be valid for receive")
        #expect(!caps.canTransmit(on: 14_350_001), "Should NOT transmit just above 20m")
    }

    @Test func frequencyRangeRetrieval() {
        let caps = RadioCapabilitiesDatabase.icomIC7300

        // Get the frequency range containing 20m
        let range = caps.frequencyRange(containing: 14_200_000)
        #expect(range != nil, "Should find a range for 14.200 MHz")
        #expect(range?.bandName == "20m", "Range should be labeled as 20m")
        #expect(range?.canTransmit ?? false, "20m should allow transmit")

        // Get a receive-only range
        let receiveRange = caps.frequencyRange(containing: 500_000)
        #expect(receiveRange != nil, "Should find a range for 500 kHz")
        #expect(!(receiveRange?.canTransmit ?? true), "MW should be receive only")
        #expect(receiveRange?.bandName == nil, "Receive-only range should not have amateur band name")
    }

    // MARK: - All Radio Definitions Tests

    @Test func allRadioDefinitionsHaveCapabilities() {
        let radios: [RadioDefinition] = [
            .icomIC9700(),
            .icomIC7610(),
            .icomIC7300(),
            .icomIC7600(),
            .icomIC7100(),
            .icomIC705(),
            .yaesuFTDX10,
            .yaesuFT991A,
            .kenwoodTS590SG,
            .elecraftK3
        ]

        for radio in radios {
            let caps = radio.capabilities
            #expect(!caps.supportedModes.isEmpty, "\(radio.fullName) should have supported modes")
            #expect(caps.maxPower > 0, "\(radio.fullName) should have max power > 0")
        }
    }

    @Test func radiosWithDetailedFrequencyRanges() {
        // Test radios that have detailed frequency ranges
        let caps = RadioCapabilitiesDatabase.icomIC7300
        #expect(!caps.detailedFrequencyRanges.isEmpty, "IC-7300 should have detailed frequency ranges")

        // Verify ranges are properly ordered
        for i in 0..<(caps.detailedFrequencyRanges.count - 1) {
            let current = caps.detailedFrequencyRanges[i]
            let next = caps.detailedFrequencyRanges[i + 1]
            #expect(current.max < next.min, "Frequency ranges should not overlap")
        }
    }

    // MARK: - Error Message Tests

    @Test func frequencyErrorMessages() {
        // Test that error messages are properly formatted
        let error1 = RigError.frequencyOutOfRange(14_200_000, model: "IC-7300")
        #expect(error1.errorDescription != nil)
        #expect(error1.errorDescription?.contains("14.200") ?? false, "Error should include frequency in MHz")

        let error2 = RigError.transmitNotAllowed(500_000, reason: "Receive only")
        #expect(error2.errorDescription != nil)
        #expect(error2.errorDescription?.contains("0.500") ?? false, "Error should include frequency in MHz")

        let error3 = RigError.modeNotSupported(.fm, frequency: 14_200_000)
        #expect(error3.errorDescription != nil)
        #expect(error3.errorDescription?.contains("FM") ?? false, "Error should include mode")
    }
}
