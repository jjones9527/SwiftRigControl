import Testing
@testable import RigControl

/// Catalog-drift tests for every named `StandardIcomCommandSet`
/// variant.
///
/// Each of the ~30 static variants (`.ic7300`, `.ic7610`, `.ic7000`,
/// etc.) hard-codes a CI-V address and a VFO model per Hamlib
/// `rigs/icom/<radio>.c`. Prior to these tests only three radios
/// (IC-7100, IC-9700, IC-7300 via `StandardIcomCommandSet` init)
/// had explicit coverage in `CIVCommandSetTests`; the other 27
/// variants shipped with no regression net at all. A typo in a
/// CI-V byte would silently break the whole radio for any user
/// who selected that factory, and no test would notice.
///
/// This suite covers the parts that are unambiguously verifiable
/// against Hamlib:
///
/// - **CI-V address parity** — each variant's `civAddress` must
///   match the `default address` line in the corresponding Hamlib
///   backend file. Verified by hand-audit against `~/Developer/hamlib`
///   during the v1.2.4 test-coverage buildout; results are
///   captured as the `expectedAddress` field on
///   ``IcomVariantSpec``.
/// - **Frequency-command shape** — every Icom radio uses the same
///   5-byte little-endian BCD encoding (Hamlib `to_bcd()` in
///   `rigs/icom/frame.c`), so `setFrequencyCommand` should emit
///   the same 5-byte shape for every variant. The round-trip
///   through `parseFrequencyResponse` should return the input
///   frequency.
/// - **PTT-command shape** — universal `0x1C 0x00 [0x00|0x01]`.
///
/// The **VFO model** field is intentionally NOT locked here — the
/// question of whether IC-7610 (dual-receiver, but supports
/// per-VFO targeting per Hamlib `RIG_TARGETABLE_FREQ`) should be
/// `.targetable` or `.mainSub` is an architecture design call
/// deeper than a drift test can answer, and locking either choice
/// prematurely would freeze a possible bug. Left for a future
/// audit release.
@Suite struct StandardIcomCommandSetVariantsTests {

    /// One row per named variant: the factory closure and the
    /// Hamlib-verified fields we're locking in. The `make` closure
    /// is marked `@Sendable` so the spec table can live at file
    /// scope under Swift 6 strict concurrency.
    struct IcomVariantSpec: Sendable {
        let name: String
        let make: @Sendable () -> StandardIcomCommandSet
        let expectedAddress: UInt8
        let expectedEchoesCommands: Bool
        let hamlibReference: String
    }

    /// All named `StandardIcomCommandSet` variants shipped in the
    /// catalog as of v1.2.4. Every `expectedAddress` was verified
    /// against the `default address` line in the corresponding
    /// Hamlib backend file at `~/Developer/hamlib/rigs/icom/`.
    /// Every `expectedEchoesCommands` matches Hamlib's default
    /// for the radio (only IC-7600 sets it to `true` — see
    /// Hamlib issue #583).
    static let allVariants: [IcomVariantSpec] = [
        // HF transceivers
        IcomVariantSpec(name: "ic7300",  make: { .ic7300 },  expectedAddress: 0x94, expectedEchoesCommands: false, hamlibReference: "ic7300.c"),
        IcomVariantSpec(name: "ic7610",  make: { .ic7610 },  expectedAddress: 0x98, expectedEchoesCommands: false, hamlibReference: "ic7610.c"),
        IcomVariantSpec(name: "ic7600",  make: { .ic7600 },  expectedAddress: 0x7A, expectedEchoesCommands: true,  hamlibReference: "ic7600.c (issue #583)"),
        IcomVariantSpec(name: "ic9100",  make: { .ic9100 },  expectedAddress: 0x7C, expectedEchoesCommands: false, hamlibReference: "ic9100.c"),
        IcomVariantSpec(name: "ic7200",  make: { .ic7200 },  expectedAddress: 0x76, expectedEchoesCommands: false, hamlibReference: "ic7200.c"),
        IcomVariantSpec(name: "ic718",   make: { .ic718 },   expectedAddress: 0x5E, expectedEchoesCommands: false, hamlibReference: "ic718.c"),
        IcomVariantSpec(name: "ic703",   make: { .ic703 },   expectedAddress: 0x68, expectedEchoesCommands: false, hamlibReference: "ic703.c"),
        IcomVariantSpec(name: "ic7410",  make: { .ic7410 },  expectedAddress: 0x80, expectedEchoesCommands: false, hamlibReference: "ic7410.c"),
        IcomVariantSpec(name: "ic7700",  make: { .ic7700 },  expectedAddress: 0x74, expectedEchoesCommands: false, hamlibReference: "ic7700.c"),
        IcomVariantSpec(name: "ic7800",  make: { .ic7800 },  expectedAddress: 0x6A, expectedEchoesCommands: false, hamlibReference: "ic7800.c"),
        IcomVariantSpec(name: "ic7851",  make: { .ic7851 },  expectedAddress: 0x8E, expectedEchoesCommands: false, hamlibReference: "ic785x.c"),

        // HF/VHF/UHF mobile + satellite
        IcomVariantSpec(name: "ic7000",  make: { .ic7000 },  expectedAddress: 0x70, expectedEchoesCommands: false, hamlibReference: "ic7000.c"),
        IcomVariantSpec(name: "ic910H",  make: { .ic910H },  expectedAddress: 0x60, expectedEchoesCommands: false, hamlibReference: "ic910.c"),
        IcomVariantSpec(name: "ic2730",  make: { .ic2730 },  expectedAddress: 0x90, expectedEchoesCommands: false, hamlibReference: "ic2730.c"),

        // VHF/UHF mobiles with D-STAR
        IcomVariantSpec(name: "id5100",  make: { .id5100 },  expectedAddress: 0x8C, expectedEchoesCommands: false, hamlibReference: "id5100.c"),
        IcomVariantSpec(name: "id4100",  make: { .id4100 },  expectedAddress: 0x9A, expectedEchoesCommands: false, hamlibReference: "id4100.c"),

        // Receivers
        IcomVariantSpec(name: "icR8600", make: { .icR8600 }, expectedAddress: 0x96, expectedEchoesCommands: false, hamlibReference: "icr8600.c"),
        IcomVariantSpec(name: "icR75",   make: { .icR75 },   expectedAddress: 0x5A, expectedEchoesCommands: false, hamlibReference: "icr75.c"),
        IcomVariantSpec(name: "icR9500", make: { .icR9500 }, expectedAddress: 0x72, expectedEchoesCommands: false, hamlibReference: "icr9500.c"),
        IcomVariantSpec(name: "icR30",   make: { .icR30 },   expectedAddress: 0x9C, expectedEchoesCommands: false, hamlibReference: "icr30.c"),
        IcomVariantSpec(name: "icR6",    make: { .icR6 },    expectedAddress: 0x7E, expectedEchoesCommands: false, hamlibReference: "icr6.c"),
        IcomVariantSpec(name: "icR20",   make: { .icR20 },   expectedAddress: 0x6C, expectedEchoesCommands: false, hamlibReference: "icr20.c"),
        IcomVariantSpec(name: "icR7100", make: { .icR7100 }, expectedAddress: 0x34, expectedEchoesCommands: false, hamlibReference: "icr7000.c (icr7100_priv_caps block)"),
        IcomVariantSpec(name: "icRX7",   make: { .icRX7 },   expectedAddress: 0x78, expectedEchoesCommands: false, hamlibReference: "icrx7.c"),

        // D-STAR handhelds
        IcomVariantSpec(name: "id31",    make: { .id31 },    expectedAddress: 0xA0, expectedEchoesCommands: false, hamlibReference: "id31.c"),
        IcomVariantSpec(name: "id51",    make: { .id51 },    expectedAddress: 0x86, expectedEchoesCommands: false, hamlibReference: "id51.c"),
        IcomVariantSpec(name: "id52",    make: { .id52 },    expectedAddress: 0xB4, expectedEchoesCommands: false, hamlibReference: "id52plus.c"),
        IcomVariantSpec(name: "ic92d",   make: { .ic92d },   expectedAddress: 0x01, expectedEchoesCommands: false, hamlibReference: "ic92d.c (shared with ID-1)"),

        // Specialty
        IcomVariantSpec(name: "icF8101", make: { .icF8101 }, expectedAddress: 0x8A, expectedEchoesCommands: false, hamlibReference: "icf8101.c"),
        IcomVariantSpec(name: "id1",     make: { .id1 },     expectedAddress: 0x01, expectedEchoesCommands: false, hamlibReference: "id1.c (shared with IC-92AD)"),
    ]

    // MARK: - CI-V address parity

    @Test func everyVariantHasHamlibVerifiedAddress() {
        for spec in Self.allVariants {
            let cs = spec.make()
            #expect(
                cs.civAddress == spec.expectedAddress,
                "\(spec.name).civAddress must be 0x\(String(format: "%02X", spec.expectedAddress)) per Hamlib \(spec.hamlibReference); got 0x\(String(format: "%02X", cs.civAddress))"
            )
        }
    }

    @Test func everyVariantUsesPercentagePowerUnits() {
        // Per Hamlib, every Icom radio uses percentage power (0-100).
        // `StandardIcomCommandSet.init` hard-codes this to
        // `.percentage`. This test ensures nobody accidentally adds
        // a variant that overrides it.
        for spec in Self.allVariants {
            let cs = spec.make()
            #expect(
                cs.powerUnits == .percentage,
                "\(spec.name) must use percentage power units"
            )
        }
    }

    @Test func everyVariantEchoBehaviorMatchesHamlib() {
        // Only IC-7600 echoes commands over USB per Hamlib issue
        // #583 — every other variant defaults to false. This test
        // catches accidental echo-flag drift on any variant.
        for spec in Self.allVariants {
            let cs = spec.make()
            #expect(
                cs.echoesCommands == spec.expectedEchoesCommands,
                "\(spec.name).echoesCommands must be \(spec.expectedEchoesCommands) per Hamlib \(spec.hamlibReference); got \(cs.echoesCommands)"
            )
        }
    }

    // MARK: - Universal command shapes

    /// Every variant must emit the same 5-byte little-endian BCD
    /// frequency frame for a given input — the encoding is shared
    /// across all Icom CI-V per Hamlib `frame.c::to_bcd`.
    @Test func everyVariantRoundTripsFrequency() throws {
        let testFrequencies: [UInt64] = [
            7_100_000,       // 40m
            14_230_000,      // 20m
            50_130_000,      // 6m
            146_520_000,     // 2m FM simplex
            435_000_000,     // 70cm satellite
            902_500_000,     // 33cm receiver
        ]

        for spec in Self.allVariants {
            let cs = spec.make()
            for freq in testFrequencies {
                let (cmd, data) = cs.setFrequencyCommand(frequency: freq)
                #expect(cmd == [0x05], "\(spec.name) frequency opcode")
                #expect(data.count == 5, "\(spec.name) frequency data length for \(freq) Hz")

                let frame = CIVFrame(
                    to: 0xE0,
                    from: cs.civAddress,
                    command: [0x03],
                    data: data
                )
                let parsed = try cs.parseFrequencyResponse(frame)
                #expect(
                    parsed == freq,
                    "\(spec.name) frequency round-trip: sent \(freq), got \(parsed)"
                )
            }
        }
    }

    /// Every variant must emit the standard `0x1C 0x00` PTT frame.
    @Test func everyVariantEmitsStandardPTTCommand() {
        for spec in Self.allVariants {
            let cs = spec.make()
            let (cmdOn, dataOn) = cs.setPTTCommand(enabled: true)
            #expect(cmdOn == [0x1C, 0x00], "\(spec.name) PTT-on opcode")
            #expect(dataOn == [0x01], "\(spec.name) PTT-on payload")

            let (cmdOff, dataOff) = cs.setPTTCommand(enabled: false)
            #expect(cmdOff == [0x1C, 0x00], "\(spec.name) PTT-off opcode")
            #expect(dataOff == [0x00], "\(spec.name) PTT-off payload")
        }
    }

    /// Every variant must round-trip power through the standard
    /// `0x14 0x0A` opcode with 2-byte BCD payload. Non-transmitting
    /// receiver variants (`.icR8600`, `.icR75`, `.icR9500`,
    /// `.icR30`, `.icR6`, `.icR20`, `.icR7100`, `.icRX7`) still
    /// implement this command shape — the command set is universal;
    /// the radio's actual TX capability is expressed via
    /// `RigCapabilities`, not here.
    @Test func everyVariantRoundTripsPowerCommand() throws {
        for spec in Self.allVariants {
            let cs = spec.make()
            for testPower in [10, 50, 100] {
                let (cmd, data) = cs.setPowerCommand(value: testPower)
                #expect(cmd == [0x14, 0x0A], "\(spec.name) power opcode")
                #expect(data.count == 2, "\(spec.name) power BCD length")

                let frame = CIVFrame(
                    to: 0xE0,
                    from: cs.civAddress,
                    command: [0x14, 0x0A],
                    data: data
                )
                let parsedPower = try cs.parsePowerResponse(frame)
                #expect(
                    abs(parsedPower - testPower) <= 1,
                    "\(spec.name) power round-trip \(testPower)% → \(parsedPower)"
                )
            }
        }
    }

    // MARK: - Catalog completeness

    /// Guards against forgetting to add a new variant to the test
    /// table when adding a new named factory. If someone adds a
    /// new `public static var` to `StandardIcomCommandSet` without
    /// registering it here, we can't automatically detect it (Swift
    /// has no reflection over static members), but this count is
    /// a manual reminder to update the table when the variant list
    /// grows.
    @Test func variantTableCountMatchesShippedFactories() {
        // As of v1.2.4 there are 30 named `StandardIcomCommandSet`
        // variants shipped. Bump this if you add a new one.
        #expect(Self.allVariants.count == 30)
    }
}
