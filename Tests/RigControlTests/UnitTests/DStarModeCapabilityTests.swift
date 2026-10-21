import Testing
@testable import RigControl

/// D-STAR radios advertise native DV without DATA-mode stand-ins.
///
/// Hamlib models D-STAR digital voice as `RIG_MODE_DSTAR`, not as PKT
/// (`id31.c:36`, `id51.c:38`, `id4100.c:40`, `id5100.c:49`, `icr30.c:30-33`,
/// `ic92d.c:32-33`). SwiftRigControl has no DV mode, and none of these
/// radios' protocols can set `.dataFM` / `.dataUSB`, so advertising them
/// only produced errors (and wrong `\dump_state` mode lists).
@Suite struct DStarModeCapabilityTests {

    static let radios: [(String, RigCapabilities)] = [
        ("IC-705", RadioCapabilitiesDatabase.Icom.ic705),
        ("IC-7100", RadioCapabilitiesDatabase.Icom.ic7100),
        ("IC-9100", RadioCapabilitiesDatabase.Icom.ic9100),
        ("IC-9700", RadioCapabilitiesDatabase.Icom.ic9700),
        ("ID-1", RadioCapabilitiesDatabase.Icom.id1),
        ("ID-31", RadioCapabilitiesDatabase.Icom.id31),
        ("ID-51", RadioCapabilitiesDatabase.Icom.id51),
        ("ID-52", RadioCapabilitiesDatabase.Icom.id52),
        ("ID-4100", RadioCapabilitiesDatabase.Icom.id4100),
        ("ID-5100", RadioCapabilitiesDatabase.Icom.id5100),
        ("IC-92AD", RadioCapabilitiesDatabase.Icom.ic92D),
        ("IC-R30", RadioCapabilitiesDatabase.Icom.icR30),
        ("IC-R8600", RadioCapabilitiesDatabase.Icom.icR8600),
        ("TH-D74", RadioCapabilitiesDatabase.Kenwood.thd74),
        ("TH-D75", RadioCapabilitiesDatabase.Kenwood.thd75),
    ]

    @Test func allDStarRadiosAdvertiseNativeMode() {
        for (name, caps) in Self.radios {
            #expect(caps.supportedModes.contains(.dstar), "\(name)")
            #expect(caps.detailedFrequencyRanges.contains { $0.modes.contains(.dstar) }, "\(name)")
        }
    }

    @Test func dstarOnlyRadiosHaveNoDataModeStandIns() {
        let dataModes: Set<Mode> = [.dataUSB, .dataLSB, .dataFM]
        let dstarOnlyRadios = Self.radios.filter {
            !["IC-705", "IC-7100", "IC-9100", "IC-9700"].contains($0.0)
        }
        for (name, caps) in dstarOnlyRadios {
            #expect(Set(caps.supportedModes).isDisjoint(with: dataModes), "\(name)")
            for range in caps.detailedFrequencyRanges {
                #expect(Set(range.modes).isDisjoint(with: dataModes), "\(name) \(range.bandName ?? "")")
            }
        }
    }

    @Test func dstarMobilesHaveNoSSB() {
        // ID-4100 / ID-5100 are FM/AM mobiles (id4100.c:40-41, id5100.c:49-50).
        #expect(!RadioCapabilitiesDatabase.Icom.id4100.supportedModes.contains(.usb))
        #expect(!RadioCapabilitiesDatabase.Icom.id5100.supportedModes.contains(.usb))
    }
}
