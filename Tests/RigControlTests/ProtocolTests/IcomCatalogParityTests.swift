import Testing
@testable import RigControl

/// Catalog invariants that keep Icom capability claims aligned with the
/// command set actually installed by each radio factory.
@Suite struct IcomCatalogParityTests {
    private let dataModes: Set<Mode> = [.dataUSB, .dataLSB, .dataFM]

    @Test func everyAdvertisedModeIsEncodable() async throws {
        for radio in RadioDefinition.Icom.allRadios {
            let proto = try #require(
                radio.createProtocol(transport: MockTransport()) as? IcomCIVProtocol,
                "\(radio.model) must create an IcomCIVProtocol"
            )
            for mode in radio.capabilities.supportedModes {
                _ = try await proto.modeToIcomCode(mode)
            }
        }
    }

    @Test func detailedRangesDoNotAdvertiseUndeclaredModes() {
        for radio in RadioDefinition.Icom.allRadios {
            let advertised = Set(radio.capabilities.supportedModes)
            for range in radio.capabilities.detailedFrequencyRanges {
                #expect(
                    Set(range.modes).isSubset(of: advertised),
                    "\(radio.model) range \(range.bandName ?? "unnamed") contains an undeclared mode"
                )
            }
        }
    }

    @Test func dataModesRequireADataCapableCommandSet() async throws {
        for radio in RadioDefinition.Icom.allRadios {
            let advertisedDataModes = Set(radio.capabilities.supportedModes).intersection(dataModes)
            guard !advertisedDataModes.isEmpty else { continue }
            let proto = try #require(
                radio.createProtocol(transport: MockTransport()) as? IcomCIVProtocol
            )
            let rawCommandSet = await proto.commandSet
            let commandSet = try #require(rawCommandSet as? any IcomRadioCommandSet)
            #expect(
                commandSet.supportsDataMode || commandSet is ICF8101CommandSet,
                "\(radio.model) advertises \(advertisedDataModes) but its command set rejects DATA mode"
            )
        }
    }
}
