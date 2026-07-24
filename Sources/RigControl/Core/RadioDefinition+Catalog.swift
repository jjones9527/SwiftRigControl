import Foundation

// MARK: - Vendor catalogs
//
// Each vendor namespace exposes an `allRadios` array containing every
// `RadioDefinition` shipped for that manufacturer at v1.1.1+. Downstream
// consumers (picker UIs, model matchers, config validators) can iterate
// these arrays instead of hand-maintaining parallel lists, which
// eliminates the drift class where a new radio ships here but is invisible
// to the app until someone edits its adapter.
//
// New radios added to a vendor namespace must also be added to the
// matching `allRadios` array. The `AllRadiosDriftTests` suite fails CI
// when the two lists disagree.
//
// Icom entries are built with the factory's default CI-V address. Apps
// that let operators override the address (e.g. multiple radios of the
// same model on one bus) can call `withCivAddress(_:)` on the picker's
// selection at connect time — see `RadioDefinition.withCivAddress(_:)`.

extension RadioDefinition.Icom {

    /// Every Icom radio SwiftRigControl supports, alphabetically by
    /// model.
    ///
    /// Each entry is built with the factory's default CI-V address.
    /// Apps that store per-profile CI-V overrides should call
    /// `withCivAddress(_:)` on the selected definition at connect time
    /// so the returned definition's `RadioDefinition.civAddress` and
    /// underlying protocol both use the operator's address.
    public static let allRadios: [RadioDefinition] = [
        ic2730(),
        ic703(),
        ic705(),
        ic706(),
        ic706MKII(),
        ic706MKIIG(),
        ic7000(),
        ic7100(),
        ic718(),
        ic7200(),
        ic7300(),
        ic7300MK2(),
        ic735(),
        ic7400(),
        ic7410(),
        ic746(),
        ic746PRO(),
        ic751(),
        ic756(),
        ic756PRO(),
        ic756PROII(),
        ic756PROIII(),
        ic7600(),
        ic7610(),
        ic7700(),
        ic7760(),
        ic7800(),
        ic7850(),
        ic7851(),
        ic820H(),
        ic905(),
        ic9100(),
        ic910H(),
        ic92D(),
        ic970(),
        ic9700(),
        icR30(),
        icR75(),
        icR8600(),
        icR9500(),
        id31(),
        id4100(),
        id51(),
        id5100(),
        id52(),
    ].sorted { $0.model < $1.model }
}

extension RadioDefinition.Yaesu {

    /// Every Yaesu radio SwiftRigControl supports, alphabetically by
    /// model.
    public static let allRadios: [RadioDefinition] = [
        ft100,
        ft1000MP,
        ft2000,
        ft450,
        ft450D,
        ft710,
        ft817,
        ft818,
        ft847,
        ft857,
        ft857D,
        ft891,
        ft897,
        ft897D,
        ft920,
        ft950,
        ft991,
        ft991A,
        ftdx10,
        ftdx1200,
        ftdx101D,
        ftdx101MP,
        ftdx3000,
        ftdx5000,
        ftdx9000,
    ].sorted { $0.model < $1.model }
}

extension RadioDefinition.Kenwood {

    /// Every Kenwood radio SwiftRigControl supports, alphabetically by
    /// model.
    public static let allRadios: [RadioDefinition] = [
        thd72,
        thd72A,
        thd74,
        thd75,
        ts2000,
        ts480HX,
        ts480SAT,
        ts570D,
        ts570S,
        ts590S,
        ts590SG,
        ts850S,
        ts870S,
        ts890S,
        ts990S,
    ].sorted { $0.model < $1.model }
}

extension RadioDefinition.Elecraft {

    /// Every Elecraft radio SwiftRigControl supports, alphabetically by
    /// model.
    public static let allRadios: [RadioDefinition] = [
        k2,
        k3,
        k3S,
        k4,
        kx2,
        kx3,
    ].sorted { $0.model < $1.model }
}

extension RadioDefinition.Xiegu {

    /// Every Xiegu radio SwiftRigControl supports, alphabetically by
    /// model.
    public static let allRadios: [RadioDefinition] = [
        g90,
        x6100,
        x6200,
    ].sorted { $0.model < $1.model }
}

extension RadioDefinition.Flex {

    /// Every FlexRadio-family definition SwiftRigControl supports,
    /// alphabetically by model.
    ///
    /// The Flex 8000-series aliases the 6000-series CAT-over-TCP
    /// command set — downstream consumers can label an 8000 in their
    /// UI and connect using `flex6000` here.
    public static let allRadios: [RadioDefinition] = [
        flex6000,
        powerSDR,
        thetis,
    ].sorted { $0.model < $1.model }
}

extension RadioDefinition.TenTec {

    /// Every Ten-Tec radio SwiftRigControl supports, alphabetically by
    /// model.
    ///
    /// All five entries are ``RadioDefinition/VerificationStatus/definition``
    /// — no Ten-Tec radio has been exercised against real hardware. See
    /// the notes on ``RadioDefinition/TenTec`` for the audit history.
    public static let allRadios: [RadioDefinition] = [
        eagle,
        jupiter,
        orion,
        orionII,
        pegasus,
    ].sorted { $0.model < $1.model }
}

extension RadioDefinition.Lab599 {

    /// Every Lab599 radio SwiftRigControl supports.
    public static let allRadios: [RadioDefinition] = [
        tx500,
    ]
}

// MARK: - v1.2.0 vendor namespaces (empty until follow-up PRs land)
//
// Each new vendor exposes an `allRadios` returning `[]` until the
// vendor's protocol adapter, capabilities database, and model
// factories land in a follow-up PR. The empty arrays let the
// top-level `allSupportedRadios` and `allRadios(for:)` include the
// new vendors without a special case, and give the drift test a
// consistent shape.

extension RadioDefinition.Guohetec {

    /// Every Guohetec radio SwiftRigControl supports, alphabetically
    /// by model.
    ///
    /// Empty in v1.2.0-plumbing — populated in the Guohetec
    /// adapter PR (Q900, PMR-171).
    public static let allRadios: [RadioDefinition] = []
}

extension RadioDefinition.Anytone {

    /// Every Anytone radio SwiftRigControl supports, alphabetically
    /// by model.
    ///
    /// Empty in v1.2.0-plumbing — populated in the Anytone adapter
    /// PR (AT-D578UVIII).
    public static let allRadios: [RadioDefinition] = []
}

extension RadioDefinition.Elad {

    /// Every Elad radio SwiftRigControl supports, alphabetically by
    /// model.
    ///
    /// Empty in v1.2.0-plumbing — populated in the Elad adapter PR
    /// (FDM-DUO).
    public static let allRadios: [RadioDefinition] = []
}

extension RadioDefinition.CommRadio {

    /// Every CommRadio radio SwiftRigControl supports, alphabetically
    /// by model.
    ///
    /// Empty in v1.2.0-plumbing — populated in the CommRadio adapter
    /// PR (CTX-10).
    public static let allRadios: [RadioDefinition] = []
}

extension RadioDefinition.Alinco {

    /// Every Alinco radio SwiftRigControl supports, alphabetically
    /// by model.
    ///
    /// Empty in v1.2.0-plumbing — populated in the Alinco adapter
    /// PR (DX-77, DX-SR8).
    public static let allRadios: [RadioDefinition] = []
}

extension RadioDefinition.AOR {

    /// Every AOR radio SwiftRigControl supports, alphabetically by
    /// model.
    ///
    /// Empty in v1.2.0-plumbing — populated in the AOR adapter PR
    /// (AR-8600, AR-7030+).
    public static let allRadios: [RadioDefinition] = []
}

// MARK: - Top-level aggregate

extension RadioDefinition {

    /// Every radio SwiftRigControl supports across every vendor, in the
    /// order returned by the per-vendor `allRadios` arrays (each
    /// vendor's radios contiguously, vendors in the order Icom → Yaesu
    /// → Kenwood → Elecraft → Xiegu → Flex → Ten-Tec → Lab599 →
    /// Guohetec → Anytone → Elad → CommRadio → Alinco → AOR).
    ///
    /// Callers that need a specific ordering (e.g. UI grouping by
    /// manufacturer) should sort or partition on the returned array's
    /// ``RadioDefinition/manufacturer`` field.
    ///
    /// The generic in-memory ``RadioDefinition/dummy(name:capabilities:)``
    /// is intentionally excluded — it is a factory that takes user-supplied
    /// display name and capabilities and would not have a canonical entry
    /// here.
    public static let allSupportedRadios: [RadioDefinition] = {
        Icom.allRadios
        + Yaesu.allRadios
        + Kenwood.allRadios
        + Elecraft.allRadios
        + Xiegu.allRadios
        + Flex.allRadios
        + TenTec.allRadios
        + Lab599.allRadios
        + Guohetec.allRadios
        + Anytone.allRadios
        + Elad.allRadios
        + CommRadio.allRadios
        + Alinco.allRadios
        + AOR.allRadios
    }()

    /// Every radio SwiftRigControl supports for a specific manufacturer.
    ///
    /// Returns an empty array for ``RadioDefinition/Manufacturer/dummy``
    /// — the dummy radio is a user-parameterised factory and does not
    /// have a canonical catalog entry.
    ///
    /// - Parameter manufacturer: The vendor to enumerate.
    /// - Returns: All shipped `RadioDefinition`s for that vendor,
    ///   alphabetically by model.
    public static func allRadios(for manufacturer: Manufacturer) -> [RadioDefinition] {
        switch manufacturer {
        case .icom:      return Icom.allRadios
        case .yaesu:     return Yaesu.allRadios
        case .kenwood:   return Kenwood.allRadios
        case .elecraft:  return Elecraft.allRadios
        case .xiegu:     return Xiegu.allRadios
        case .flex:      return Flex.allRadios
        case .tentec:    return TenTec.allRadios
        case .lab599:    return Lab599.allRadios
        case .guohetec:  return Guohetec.allRadios
        case .anytone:   return Anytone.allRadios
        case .elad:      return Elad.allRadios
        case .commradio: return CommRadio.allRadios
        case .alinco:    return Alinco.allRadios
        case .aor:       return AOR.allRadios
        case .dummy:     return []
        }
    }
}
