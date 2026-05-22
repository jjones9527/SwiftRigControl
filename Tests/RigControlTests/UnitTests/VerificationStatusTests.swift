import Testing
@testable import RigControl

/// Unit tests for `RadioDefinition.VerificationStatus`.
///
/// The four radios listed under "Hardware-Verified" in README.md and
/// ROADMAP.md must report `.hardware`. Every other radio definition
/// defaults to `.definition`. These tests guard against accidental
/// promotion (claiming a radio is verified when it isn't) and against
/// accidental demotion (forgetting to mark a newly-validated radio).
@Suite struct VerificationStatusTests {

    @Test func icomIC7100IsHardwareVerified() {
        #expect(RadioDefinition.icomIC7100().verificationStatus == .hardware)
    }

    @Test func icomIC7600IsHardwareVerified() {
        #expect(RadioDefinition.icomIC7600().verificationStatus == .hardware)
    }

    @Test func icomIC9700IsHardwareVerified() {
        #expect(RadioDefinition.icomIC9700().verificationStatus == .hardware)
    }

    @Test func elecraftK2IsHardwareVerified() {
        #expect(RadioDefinition.elecraftK2.verificationStatus == .hardware)
    }

    @Test func customCIVAddressPreservesHardwareStatus() {
        // Setting a custom CI-V address must not silently downgrade
        // the verification status — the factory should pass it through.
        let custom = RadioDefinition.icomIC7600(civAddress: 0x7B)
        #expect(custom.verificationStatus == .hardware)
    }

    @Test func definitionOnlyRadiosReportDefinition() {
        // IC-7300 is widely deployed and likely works, but we don't
        // own one — so it must report as definition-only until we do.
        #expect(RadioDefinition.icomIC7300().verificationStatus == .definition)
    }

    @Test func defaultVerificationStatusIsDefinition() {
        // Newly-added radios that omit the parameter should default
        // to definition. This prevents accidental over-claiming.
        let synthetic = RadioDefinition(
            manufacturer: .icom,
            model: "Synthetic",
            defaultBaudRate: 19200,
            capabilities: RadioCapabilitiesDatabase.icomIC7600,
            protocolFactory: { transport in
                IcomCIVProtocol(
                    transport: transport,
                    radioModel: .ic7600,
                    commandSet: StandardIcomCommandSet.ic7600,
                    capabilities: RadioCapabilitiesDatabase.icomIC7600
                )
            }
        )
        #expect(synthetic.verificationStatus == .definition)
    }

    @Test func displayNameIsHumanReadable() {
        #expect(RadioDefinition.VerificationStatus.hardware.displayName == "Hardware verified")
        #expect(RadioDefinition.VerificationStatus.definition.displayName == "Definition only")
    }
}
