import Foundation
import Testing
@testable import RigControl

/// Drift-catching tests for the per-vendor `allRadios` catalogs.
///
/// Each vendor test hard-codes the model-string set the human
/// maintainer has verified belongs in that catalog. When someone
/// adds a new radio to a vendor namespace, these tests fail until
/// they *also* add the model to the vendor's `allRadios` array
/// **and** to the corresponding `expectedModels` set below.
///
/// This is the point: CI enforces that you cannot ship a new radio
/// without registering it in the catalog downstream consumers use.
///
/// If a test fails after you added a new radio, add its exact
/// `model` string to `expectedModels` and its factory call to the
/// vendor's `allRadios` array in
/// `Sources/RigControl/Core/RadioDefinition+Catalog.swift`.
@Suite struct RadioCatalogDriftTests {

    // MARK: - Per-vendor drift

    @Test func icomCatalogMatchesExpectedModels() {
        let expected: Set<String> = [
            "IC-2730", "IC-703", "IC-705", "IC-706", "IC-706MKII",
            "IC-706MKIIG", "IC-7000", "IC-7100", "IC-718", "IC-7200",
            "IC-7300", "IC-7300MK2", "IC-735", "IC-7400", "IC-7410",
            "IC-746", "IC-746PRO", "IC-751", "IC-756", "IC-756PRO",
            "IC-756PROII", "IC-756PROIII", "IC-7600", "IC-7610",
            "IC-7700", "IC-7760", "IC-7800", "IC-7850", "IC-7851",
            "IC-820H", "IC-905", "IC-9100", "IC-910H", "IC-92D",
            "IC-970", "IC-9700", "IC-R30", "IC-R75", "IC-R8600",
            "IC-R9500", "ID-31", "ID-4100", "ID-51", "ID-5100", "ID-52",
        ]
        let actual = Set(RadioDefinition.Icom.allRadios.map(\.model))
        #expect(actual == expected)
    }

    @Test func yaesuCatalogMatchesExpectedModels() {
        let expected: Set<String> = [
            "FT-100", "FT-1000MP", "FT-2000", "FT-450", "FT-450D",
            "FT-710", "FT-817", "FT-818", "FT-847", "FT-857", "FT-857D",
            "FT-891", "FT-897", "FT-897D", "FT-920", "FT-950", "FT-991",
            "FT-991A", "FTDX-10", "FTDX-101D", "FTDX-101MP", "FTDX-1200",
            "FTDX-3000", "FTDX-5000", "FTDX-9000",
        ]
        let actual = Set(RadioDefinition.Yaesu.allRadios.map(\.model))
        #expect(actual == expected)
    }

    @Test func kenwoodCatalogMatchesExpectedModels() {
        let expected: Set<String> = [
            "TH-D72", "TH-D72A", "TH-D74", "TH-D75", "TS-2000",
            "TS-480HX", "TS-480SAT", "TS-570D", "TS-570S", "TS-590S",
            "TS-590SG", "TS-850S", "TS-870S", "TS-890S", "TS-990S",
        ]
        let actual = Set(RadioDefinition.Kenwood.allRadios.map(\.model))
        #expect(actual == expected)
    }

    @Test func elecraftCatalogMatchesExpectedModels() {
        let expected: Set<String> = ["K2", "K3", "K3S", "K4", "KX2", "KX3"]
        let actual = Set(RadioDefinition.Elecraft.allRadios.map(\.model))
        #expect(actual == expected)
    }

    @Test func xieguCatalogMatchesExpectedModels() {
        let expected: Set<String> = ["G90", "X6100", "X6200"]
        let actual = Set(RadioDefinition.Xiegu.allRadios.map(\.model))
        #expect(actual == expected)
    }

    @Test func flexCatalogMatchesExpectedModels() {
        let expected: Set<String> = ["6000-series", "PowerSDR", "Thetis"]
        let actual = Set(RadioDefinition.Flex.allRadios.map(\.model))
        #expect(actual == expected)
    }

    @Test func tenTecCatalogMatchesExpectedModels() {
        let expected: Set<String> = [
            "Eagle",
            "Jupiter (TT-538)",
            "Orion (TT-565)",
            "Orion II (TT-599)",
            "Pegasus (TT-550)",
        ]
        let actual = Set(RadioDefinition.TenTec.allRadios.map(\.model))
        #expect(actual == expected)
    }

    @Test func lab599CatalogMatchesExpectedModels() {
        let expected: Set<String> = ["TX-500"]
        let actual = Set(RadioDefinition.Lab599.allRadios.map(\.model))
        #expect(actual == expected)
    }

    // MARK: - Sort order

    @Test func perVendorCatalogsAreAlphabeticallySortedByModel() {
        for radios in [
            RadioDefinition.Icom.allRadios,
            RadioDefinition.Yaesu.allRadios,
            RadioDefinition.Kenwood.allRadios,
            RadioDefinition.Elecraft.allRadios,
            RadioDefinition.Xiegu.allRadios,
            RadioDefinition.Flex.allRadios,
            RadioDefinition.TenTec.allRadios,
        ] {
            let sorted = radios.sorted { $0.model < $1.model }
            #expect(radios.map(\.model) == sorted.map(\.model))
        }
    }

    // MARK: - Aggregate

    @Test func allSupportedRadiosEqualsSumOfVendorCatalogs() {
        let expectedCount =
            RadioDefinition.Icom.allRadios.count
            + RadioDefinition.Yaesu.allRadios.count
            + RadioDefinition.Kenwood.allRadios.count
            + RadioDefinition.Elecraft.allRadios.count
            + RadioDefinition.Xiegu.allRadios.count
            + RadioDefinition.Flex.allRadios.count
            + RadioDefinition.TenTec.allRadios.count
            + RadioDefinition.Lab599.allRadios.count
        #expect(RadioDefinition.allSupportedRadios.count == expectedCount)
    }

    @Test func allRadiosForManufacturerMatchesVendorNamespace() {
        #expect(
            RadioDefinition.allRadios(for: .icom).map(\.model)
                == RadioDefinition.Icom.allRadios.map(\.model)
        )
        #expect(
            RadioDefinition.allRadios(for: .yaesu).map(\.model)
                == RadioDefinition.Yaesu.allRadios.map(\.model)
        )
        #expect(
            RadioDefinition.allRadios(for: .kenwood).map(\.model)
                == RadioDefinition.Kenwood.allRadios.map(\.model)
        )
        #expect(
            RadioDefinition.allRadios(for: .elecraft).map(\.model)
                == RadioDefinition.Elecraft.allRadios.map(\.model)
        )
        #expect(
            RadioDefinition.allRadios(for: .xiegu).map(\.model)
                == RadioDefinition.Xiegu.allRadios.map(\.model)
        )
        #expect(
            RadioDefinition.allRadios(for: .flex).map(\.model)
                == RadioDefinition.Flex.allRadios.map(\.model)
        )
        #expect(
            RadioDefinition.allRadios(for: .tentec).map(\.model)
                == RadioDefinition.TenTec.allRadios.map(\.model)
        )
        #expect(
            RadioDefinition.allRadios(for: .lab599).map(\.model)
                == RadioDefinition.Lab599.allRadios.map(\.model)
        )
        #expect(RadioDefinition.allRadios(for: .dummy).isEmpty)
    }

    // MARK: - Manufacturer tagging

    @Test func everyIcomEntryHasIcomManufacturer() {
        for radio in RadioDefinition.Icom.allRadios {
            #expect(radio.manufacturer == .icom)
        }
    }

    @Test func everyYaesuEntryHasYaesuManufacturer() {
        for radio in RadioDefinition.Yaesu.allRadios {
            #expect(radio.manufacturer == .yaesu)
        }
    }

    @Test func everyKenwoodEntryHasKenwoodManufacturer() {
        for radio in RadioDefinition.Kenwood.allRadios {
            #expect(radio.manufacturer == .kenwood)
        }
    }

    @Test func everyElecraftEntryHasElecraftManufacturer() {
        for radio in RadioDefinition.Elecraft.allRadios {
            #expect(radio.manufacturer == .elecraft)
        }
    }

    @Test func everyTenTecEntryHasTenTecManufacturer() {
        for radio in RadioDefinition.TenTec.allRadios {
            #expect(radio.manufacturer == .tentec)
        }
    }

    // MARK: - withCivAddress

    @Test func icomWithCivAddressOverridesStoredField() {
        let overridden = RadioDefinition.Icom.ic7300().withCivAddress(0x95)
        #expect(overridden.civAddress == 0x95)
        #expect(overridden.model == "IC-7300")
        #expect(overridden.manufacturer == .icom)
    }

    @Test func icomWithCivAddressNilRestoresFactoryDefault() {
        let defaultCiv = RadioDefinition.Icom.ic7300().civAddress
        let restored = RadioDefinition.Icom.ic7300()
            .withCivAddress(0x42)
            .withCivAddress(nil)
        #expect(restored.civAddress == defaultCiv)
    }

    @Test func nonIcomWithCivAddressIsNoOp() {
        // Non-Icom radios have no rebuilder — withCivAddress returns
        // self and the civAddress field stays nil.
        let k3 = RadioDefinition.Elecraft.k3
        let after = k3.withCivAddress(0x99)
        #expect(after.civAddress == k3.civAddress)
        #expect(after.civAddress == nil)
        #expect(after.model == k3.model)
    }

    @Test func icomWithCivAddressProducesProtocolBoundToNewAddress() async throws {
        // The whole point of a rebuilder (vs. a struct copy) is that
        // the returned definition's protocol also honours the new
        // CIV. Build a controller against the overridden definition
        // and confirm it connects — the protocol wouldn't survive
        // wire-level probing if we handed it the stale address.
        let overridden = RadioDefinition.Icom.ic7300().withCivAddress(0x95)
        let rig = try RigController(radio: overridden, connection: .mock)
        try await rig.connect()
        #expect(await rig.radioName == "Icom IC-7300")
    }

    @Test func everyIcomFactoryHasRebuilder() {
        // Every entry in Icom.allRadios must respond to
        // withCivAddress by returning a definition with the new
        // address, not a no-op copy.
        for radio in RadioDefinition.Icom.allRadios {
            let overridden = radio.withCivAddress(0xEE)
            #expect(
                overridden.civAddress == 0xEE,
                "Icom \(radio.model) is missing civAddressRebuilder"
            )
        }
    }
}
