import XCTest
@testable import RigControl

final class RadioCapabilitiesTests: XCTestCase {

    // MARK: - Amateur Band Tests

    func testAmateurBand20mContainsFrequency() {
        let band20m = AmateurBand.band20m
        XCTAssertTrue(band20m.contains(14_200_000), "14.200 MHz should be in the 20m band")
        XCTAssertTrue(band20m.contains(14_000_000), "14.000 MHz should be at the start of 20m")
        XCTAssertTrue(band20m.contains(14_350_000), "14.350 MHz should be at the end of 20m")
        XCTAssertFalse(band20m.contains(7_100_000), "7.100 MHz should not be in 20m")
    }

    func testAmateurBandLookup() {
        // Test 20m band
        let band20m = AmateurBand.band(for: 14_200_000)
        XCTAssertEqual(band20m, .band20m, "14.200 MHz should resolve to 20m band")

        // Test 40m band
        let band40m = AmateurBand.band(for: 7_100_000)
        XCTAssertEqual(band40m, .band40m, "7.100 MHz should resolve to 40m band")

        // Test non-amateur frequency
        let noband = AmateurBand.band(for: 5_000_000)
        XCTAssertNil(noband, "5.000 MHz is not in an amateur band")
    }

    func testAmateurBandCommonModes() {
        // 20m should have USB
        XCTAssertTrue(AmateurBand.band20m.commonModes.contains(.usb))

        // 80m should have LSB
        XCTAssertTrue(AmateurBand.band80m.commonModes.contains(.lsb))

        // 30m should have CW and USB (digital) but not voice modes
        XCTAssertTrue(AmateurBand.band30m.commonModes.contains(.cw))
        XCTAssertTrue(AmateurBand.band30m.commonModes.contains(.usb))

        // 2m should have FM
        XCTAssertTrue(AmateurBand.band2m.commonModes.contains(.fm))
    }

    // MARK: - IC-7300 Capability Tests

    func testIC7300ValidFrequency() {
        let caps = RadioCapabilitiesDatabase.icomIC7300

        // Test valid HF frequency
        XCTAssertTrue(caps.isFrequencyValid(14_200_000), "14.200 MHz should be valid for IC-7300")

        // Test valid 6m frequency
        XCTAssertTrue(caps.isFrequencyValid(50_100_000), "50.100 MHz should be valid for IC-7300")

        // Test receive-only frequency
        XCTAssertTrue(caps.isFrequencyValid(500_000), "500 kHz should be valid for receive")

        // Test out of range
        XCTAssertFalse(caps.isFrequencyValid(100_000_000), "100 MHz should be out of range")
    }

    func testIC7300TransmitCapability() {
        let caps = RadioCapabilitiesDatabase.icomIC7300

        // Should be able to transmit on 20m
        XCTAssertTrue(caps.canTransmit(on: 14_200_000), "Should be able to transmit on 20m")

        // Should NOT be able to transmit on MW
        XCTAssertFalse(caps.canTransmit(on: 500_000), "Should NOT transmit on MW (receive only)")

        // Should be able to transmit on 6m
        XCTAssertTrue(caps.canTransmit(on: 50_100_000), "Should be able to transmit on 6m")
    }

    func testIC7300BandNames() {
        let caps = RadioCapabilitiesDatabase.icomIC7300

        XCTAssertEqual(caps.bandName(for: 14_200_000), "20m", "14.200 MHz should be identified as 20m")
        XCTAssertEqual(caps.bandName(for: 7_100_000), "40m", "7.100 MHz should be identified as 40m")
        XCTAssertNil(caps.bandName(for: 500_000), "500 kHz should not have a band name")
    }

    func testIC7300SupportedModes() {
        let caps = RadioCapabilitiesDatabase.icomIC7300

        // Test 20m modes
        let modes20m = caps.supportedModes(for: 14_200_000)
        XCTAssertTrue(modes20m.contains(.usb), "IC-7300 should support USB on 20m")
        XCTAssertTrue(modes20m.contains(.cw), "IC-7300 should support CW on 20m")

        // Test receive-only range
        let modesReceive = caps.supportedModes(for: 500_000)
        XCTAssertFalse(modesReceive.isEmpty, "IC-7300 should have modes for receive frequencies")
    }

    // MARK: - IC-9700 Capability Tests

    func testIC9700ValidFrequency() {
        let caps = RadioCapabilitiesDatabase.icomIC9700

        // Should be valid on 2m
        XCTAssertTrue(caps.isFrequencyValid(146_000_000), "146 MHz should be valid on IC-9700")

        // Should be valid on 70cm
        XCTAssertTrue(caps.isFrequencyValid(440_000_000), "440 MHz should be valid on IC-9700")

        // Should be valid on 23cm
        XCTAssertTrue(caps.isFrequencyValid(1_296_000_000), "1296 MHz should be valid on IC-9700")

        // Should be invalid below range
        XCTAssertFalse(caps.isFrequencyValid(10_000), "10 kHz should be out of range")
    }

    func testIC9700TransmitCapability() {
        let caps = RadioCapabilitiesDatabase.icomIC9700

        // Should transmit on 2m
        XCTAssertTrue(caps.canTransmit(on: 146_000_000), "Should transmit on 2m")

        // Should transmit on 70cm
        XCTAssertTrue(caps.canTransmit(on: 440_000_000), "Should transmit on 70cm")

        // Should NOT transmit on HF (receive only)
        XCTAssertFalse(caps.canTransmit(on: 14_200_000), "Should NOT transmit on HF (receive only)")
    }

    // MARK: - FT-991A Capability Tests

    func testFT991AValidFrequency() {
        let caps = RadioCapabilitiesDatabase.yaesuFT991A

        // Should be valid on HF
        XCTAssertTrue(caps.isFrequencyValid(14_200_000), "14.200 MHz should be valid")

        // Should be valid on 2m
        XCTAssertTrue(caps.isFrequencyValid(146_000_000), "146 MHz should be valid")

        // Should be valid on 70cm
        XCTAssertTrue(caps.isFrequencyValid(440_000_000), "440 MHz should be valid")
    }

    func testFT991ATransmitCapability() {
        let caps = RadioCapabilitiesDatabase.yaesuFT991A

        // Should transmit on 20m
        XCTAssertTrue(caps.canTransmit(on: 14_200_000), "Should transmit on 20m")

        // Should transmit on 2m
        XCTAssertTrue(caps.canTransmit(on: 146_000_000), "Should transmit on 2m")

        // Should NOT transmit on receive-only frequencies
        XCTAssertFalse(caps.canTransmit(on: 5_000_000), "Should NOT transmit outside amateur bands")
    }

    // MARK: - Kenwood TS-590SG Tests

    func testTS590SGValidFrequency() {
        let caps = RadioCapabilitiesDatabase.kenwoodTS590SG

        // Valid HF frequencies
        XCTAssertTrue(caps.isFrequencyValid(14_200_000), "14.200 MHz should be valid")
        XCTAssertTrue(caps.isFrequencyValid(7_100_000), "7.100 MHz should be valid")

        // Out of range (TS-590SG doesn't cover VHF/UHF)
        XCTAssertFalse(caps.isFrequencyValid(146_000_000), "146 MHz should be out of range")
    }

    // MARK: - Elecraft K3 Tests

    func testElecraftK3ValidFrequency() {
        let caps = RadioCapabilitiesDatabase.elecraftK3

        // Valid HF frequencies
        XCTAssertTrue(caps.isFrequencyValid(14_200_000), "14.200 MHz should be valid")

        // Valid 6m frequency
        XCTAssertTrue(caps.isFrequencyValid(50_100_000), "50.100 MHz should be valid")

        // Out of range
        XCTAssertFalse(caps.isFrequencyValid(146_000_000), "146 MHz should be out of range")
    }

    func testElecraftK3TransmitCapability() {
        let caps = RadioCapabilitiesDatabase.elecraftK3

        // Should transmit on amateur bands
        XCTAssertTrue(caps.canTransmit(on: 14_200_000), "Should transmit on 20m")

        // Should NOT transmit on receive-only frequencies
        XCTAssertFalse(caps.canTransmit(on: 5_000_000), "Should NOT transmit outside amateur bands")
    }

    // MARK: - Edge Case Tests

    func testBandEdgeFrequencies() {
        let caps = RadioCapabilitiesDatabase.icomIC7300

        // Test exact band edge frequencies
        XCTAssertTrue(caps.isFrequencyValid(14_000_000), "14.000 MHz should be at start of 20m")
        XCTAssertTrue(caps.isFrequencyValid(14_350_000), "14.350 MHz should be at end of 20m")

        // Just outside band edges (in receive-only gap)
        XCTAssertTrue(caps.isFrequencyValid(14_350_001), "14.350001 MHz should be valid for receive")
        XCTAssertFalse(caps.canTransmit(on: 14_350_001), "Should NOT transmit just above 20m")
    }

    func testFrequencyRangeRetrieval() {
        let caps = RadioCapabilitiesDatabase.icomIC7300

        // Get the frequency range containing 20m
        let range = caps.frequencyRange(containing: 14_200_000)
        XCTAssertNotNil(range, "Should find a range for 14.200 MHz")
        XCTAssertEqual(range?.bandName, "20m", "Range should be labeled as 20m")
        XCTAssertTrue(range?.canTransmit ?? false, "20m should allow transmit")

        // Get a receive-only range
        let receiveRange = caps.frequencyRange(containing: 500_000)
        XCTAssertNotNil(receiveRange, "Should find a range for 500 kHz")
        XCTAssertFalse(receiveRange?.canTransmit ?? true, "MW should be receive only")
        XCTAssertNil(receiveRange?.bandName, "Receive-only range should not have amateur band name")
    }

    // MARK: - All Radio Definitions Tests

    func testAllRadioDefinitionsHaveCapabilities() {
        // Test that all major radio definitions return valid capabilities
        let radios: [RadioDefinition] = [
            .icomIC9700,
            .icomIC7610,
            .icomIC7300,
            .icomIC7600,
            .icomIC7100,
            .icomIC705,
            .yaesuFTDX10,
            .yaesuFT991A,
            .kenwoodTS590SG,
            .elecraftK3
        ]

        for radio in radios {
            let caps = radio.capabilities
            XCTAssertFalse(caps.supportedModes.isEmpty, "\(radio.fullName) should have supported modes")
            XCTAssertGreaterThan(caps.maxPower, 0, "\(radio.fullName) should have max power > 0")
        }
    }

    func testRadiosWithDetailedFrequencyRanges() {
        // Test radios that have detailed frequency ranges
        let caps = RadioCapabilitiesDatabase.icomIC7300
        XCTAssertFalse(caps.detailedFrequencyRanges.isEmpty, "IC-7300 should have detailed frequency ranges")

        // Verify ranges are properly ordered
        for i in 0..<(caps.detailedFrequencyRanges.count - 1) {
            let current = caps.detailedFrequencyRanges[i]
            let next = caps.detailedFrequencyRanges[i + 1]
            XCTAssertLessThan(current.max, next.min, "Frequency ranges should not overlap")
        }
    }

    // MARK: - Error Message Tests

    func testFrequencyErrorMessages() {
        // Test that error messages are properly formatted
        let error1 = RigError.frequencyOutOfRange(14_200_000, model: "IC-7300")
        XCTAssertNotNil(error1.errorDescription)
        XCTAssertTrue(error1.errorDescription?.contains("14.200") ?? false, "Error should include frequency in MHz")

        let error2 = RigError.transmitNotAllowed(500_000, reason: "Receive only")
        XCTAssertNotNil(error2.errorDescription)
        XCTAssertTrue(error2.errorDescription?.contains("0.500") ?? false, "Error should include frequency in MHz")

        let error3 = RigError.modeNotSupported(.fm, frequency: 14_200_000)
        XCTAssertNotNil(error3.errorDescription)
        XCTAssertTrue(error3.errorDescription?.contains("FM") ?? false, "Error should include mode")
    }

    // MARK: - Performance Tests

    func testFrequencyValidationPerformance() {
        let caps = RadioCapabilitiesDatabase.icomIC7300

        measure {
            for _ in 0..<1000 {
                _ = caps.isFrequencyValid(14_200_000)
            }
        }
    }

    func testBandLookupPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = AmateurBand.band(for: 14_200_000)
            }
        }
    }
}
