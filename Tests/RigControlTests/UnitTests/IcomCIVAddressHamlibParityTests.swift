import Foundation
import Testing
@testable import RigControl

/// Locks `IcomRadioModel.defaultCIVAddress` against Hamlib's
/// canonical `icom_addr_list[]` table (`rigs/icom/icom.c:518-595`).
///
/// **Motivation.** Two bugs in the pre-v1.2.15 catalog were the
/// same class:
///
/// - IC-7300 mk2: SwiftRigControl declared `0x94` because the
///   original commit assumed Icom would ship the mk2 with the
///   same default as the mk1.  Icom actually chose `0xB6` so a
///   mk2 and mk1 can share a CI-V bus.  Hamlib `icom.c:585` had
///   `0xB6` correct.
/// - IC-7760: SwiftRigControl declared `0xB0`.  Hamlib `icom.c:588`
///   and `ic7760.c:126` both say `0xB2`.  Off by one nibble in
///   the wrong direction.
///
/// Both failures would silently break enumeration on a factory-
/// default radio (frames addressed to nothing, no response, timeout,
/// user assumes broken cable).  A catalog-drift test surfaces the
/// class in CI before it ships.
///
/// **Scope.** Covers only the models Hamlib lists in
/// `icom_addr_list[]` (that struct is Hamlib's own authoritative
/// lookup table).  Models whose default lives in per-model
/// `priv_caps` (ID-31, ID-51, ID-52, IC-92AD, IC-2730, IC-905,
/// ID-4100, ID-5100, IC-F8101) are cross-checked by reading their
/// respective `<model>.c` files — those tests live below in the
/// `perModelPrivCaps` section and cite the exact file/line.
///
/// **How to extend.** When adding a new Icom radio to
/// SwiftRigControl, grep the Hamlib tree for the model's default
/// address and add a matching test line here.  If the model is
/// listed in `icom_addr_list`, put it in the main table below; if
/// its default lives in `<model>.c` `priv_caps`, add it to
/// `perModelPrivCaps` with the file/line citation.
///
/// Refresh cadence: check against Hamlib whenever
/// `Scripts/hamlib-diff.sh` reports changes touching
/// `rigs/icom/icom.c` in the address-table range or any new
/// `ic*.c` / `id*.c` / `icr*.c` file.  Current watermark:
/// `7bbde194b4c8`.
@Suite struct IcomCIVAddressHamlibParityTests {

    // MARK: - Models listed in Hamlib icom_addr_list[]
    //
    // Format: (model, expected default, Hamlib source citation).
    // The citation is the line number in `rigs/icom/icom.c` at
    // watermark 7bbde194b4c8; check the source when refreshing.

    private static let icomAddrListEntries: [(model: IcomRadioModel, expected: UInt8, citation: String)] = [
        // IC-7300 family
        (.ic7300,      0x94, "icom.c:584"),
        (.ic7300mk2,   0xB6, "icom.c:585"),

        // IC-76xx / IC-77xx / IC-78xx flagship line
        (.ic7600,      0x7A, "icom.c:549"),
        (.ic7610,      0x98, "icom.c:586"),
        (.ic7700,      0x74, "icom.c:587"),
        (.ic7760,      0xB2, "icom.c:588"),
        (.ic7800,      0x6A, "icom.c:553"),
        (.ic7851,      0x8E, "icom.c:554"),  // Hamlib collapses IC-7850/IC-7851 → IC785x = 0x8E
        (.ic7850,      0x8E, "icom.c:554"),

        // IC-7000 / IC-7100 / IC-7200 / IC-7410 / IC-718
        (.ic7000,      0x70, "icom.c:581"),
        (.ic7100,      0x88, "icom.c:582"),
        (.ic7200,      0x76, "icom.c:583"),
        (.ic7410,      0x80, "icom.c:538"),
        (.ic718,       0x5E, "icom.c:578"),

        // IC-746 family
        (.ic746,       0x56, "icom.c:539"),
        (.ic746pro,    0x66, "icom.c:540"),

        // IC-756 family
        (.ic756,       0x50, "icom.c:545"),
        (.ic756pro,    0x5C, "icom.c:546"),
        (.ic756proII,  0x64, "icom.c:547"),
        (.ic756proIII, 0x6E, "icom.c:548"),

        // IC-706 family
        (.ic706,       0x48, "icom.c:521"),
        (.ic706mkii,   0x4E, "icom.c:522"),
        (.ic706mkiig,  0x58, "icom.c:523"),

        // Vintage HF
        (.ic735,       0x04, "icom.c:536"),
        (.ic751,       0x1C, "icom.c:543"),

        // VHF/UHF all-mode
        (.ic275,       0x10, "icom.c:525"),
        (.ic375,       0x12, "icom.c:526"),
        (.ic475,       0x14, "icom.c:528"),
        (.ic820h,      0x42, "icom.c:556"),
        (.ic910h,      0x60, "icom.c:558"),
        (.ic970,       0x2E, "icom.c:561"),
        (.ic9100,      0x7C, "icom.c:559"),
        (.ic9700,      0xA2, "icom.c:560"),
        (.ic703,       0x68, "icom.c:520"),

        // Receivers
        (.icr30,       0x9C, "icom.c:593"),
        (.icr75,       0x5A, "icom.c:569"),
        (.icr20,       0x6C, "icom.c:565"),
        (.icr6,        0x7E, "icom.c:566"),
        (.icr7100,     0x34, "icom.c:573"),
        (.icr8600,     0x96, "icom.c:592"),
        (.icr9500,     0x72, "icom.c:576"),
        (.icrx7,       0x78, "icom.c:570"),

        // D-STAR mobile (ID-1) is at icom.c:580; SwiftRigControl's
        // .id1 case maps to that entry.
        (.id1,         0x01, "icom.c:580"),
    ]

    @Test(arguments: icomAddrListEntries)
    func defaultCIVAddressMatchesHamlibAddrList(
        _ entry: (model: IcomRadioModel, expected: UInt8, citation: String)
    ) {
        let actual = entry.model.defaultCIVAddress
        #expect(
            actual == entry.expected,
            """
            \(entry.model.rawValue) default CI-V address drift.
            SwiftRigControl says 0x\(String(actual, radix: 16, uppercase: true)).
            Hamlib \(entry.citation) says 0x\(String(entry.expected, radix: 16, uppercase: true)).
            On a factory-default radio the wrong address addresses nothing —
            frames go out and no response ever comes back.  Update
            IcomRadioModel.defaultCIVAddress to match Hamlib.
            """
        )
    }

    // MARK: - Models whose default address lives in per-model priv_caps
    //
    // These aren't in icom_addr_list[] but Hamlib's per-model .c
    // file declares the default in the model's icom_priv_caps
    // struct.  Same authority level as icom_addr_list — Hamlib
    // resolves from priv_caps when set, else from icom_addr_list.

    private static let perModelPrivCaps: [(model: IcomRadioModel, expected: UInt8, citation: String)] = [
        // Modern D-STAR handhelds — priv_caps defaults, verified by
        // reading the respective .c file at watermark 7bbde194b4c8.
        (.id31, 0xA0, "id31.c priv_caps"),
        (.id51, 0x86, "id51.c priv_caps"),
        (.id52, 0xB4, "id52plus.c priv_caps"),
        (.ic92d, 0x01, "ic92d.c priv_caps"),

        // Mobile FM D-STAR
        (.id5100, 0x8C, "id5100.c priv_caps"),
        (.id4100, 0x9A, "id4100.c priv_caps"),
        (.ic2730, 0x90, "ic2730.c priv_caps"),

        // VHF/UHF/SHF flagship
        (.ic905, 0xAC, "ic905.c priv_caps"),

        // Commercial HF
        (.icf8101, 0x8A, "icf8101.c priv_caps"),

        // Xiegu CI-V-compatible clones — Hamlib treats these as
        // Icom-family with a shared default 0xA4 (same as IC-705).
        (.xieguG90, 0xA4, "x108g.c / x6100.c — Xiegu family shares 0xA4"),
        (.xieguX6100, 0xA4, "x6100.c priv_caps"),
        (.xieguX6200, 0xA4, "x6100.c priv_caps (X6200 shares X6100 default)"),

        // IC-705 portable — priv_caps override
        (.ic705, 0xA4, "ic705.c priv_caps"),

        // IC-7400 (a.k.a. IC-746 in some markets) — priv_caps default
        (.ic7400, 0x66, "ic7400.c / ic746pro.c priv_caps (identical)"),
    ]

    @Test(arguments: perModelPrivCaps)
    func defaultCIVAddressMatchesHamlibPrivCaps(
        _ entry: (model: IcomRadioModel, expected: UInt8, citation: String)
    ) {
        let actual = entry.model.defaultCIVAddress
        #expect(
            actual == entry.expected,
            """
            \(entry.model.rawValue) default CI-V address drift.
            SwiftRigControl says 0x\(String(actual, radix: 16, uppercase: true)).
            Hamlib \(entry.citation) says 0x\(String(entry.expected, radix: 16, uppercase: true)).
            """
        )
    }

    // MARK: - Every enum case is covered by exactly one authority

    /// Ensures we don't add a new Icom model to `IcomRadioModel`
    /// without also adding it to one of the parity tables above.
    /// Catches the "silently added a model with an unaudited
    /// address" regression.
    @Test func everyIcomModelCaseIsAuditedAgainstHamlib() {
        let auditedInAddrList = Set(Self.icomAddrListEntries.map(\.model))
        let auditedInPrivCaps = Set(Self.perModelPrivCaps.map(\.model))
        let audited = auditedInAddrList.union(auditedInPrivCaps)
        let allCases = Set(IcomRadioModel.allCases)
        let missing = allCases.subtracting(audited)
        #expect(
            missing.isEmpty,
            """
            The following IcomRadioModel cases have no Hamlib parity
            audit entry: \(missing.map(\.rawValue).sorted()).
            Add each to either icomAddrListEntries (if the model
            appears in Hamlib's icom_addr_list[]) or perModelPrivCaps
            (if the default lives in per-model rig_caps.priv).
            """
        )
    }
}
