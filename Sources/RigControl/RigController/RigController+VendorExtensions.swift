import Foundation

// MARK: - Vendor extensions (Phase 5.2)
//
// Apps that need vendor-specific behavior beyond the standard
// RigController surface get a typed handle via
// `rig.vendorExtensions`. The discriminated enum below returns the
// concrete protocol actor for the radio's vendor without a
// stringly-typed `as?` cast.
//
//   if case .icom(let icom) = await rig.vendorExtensions {
//       try await icom.setAttenuatorIC9700(.dB12)
//   }
//
// Compare to the old escape-hatch pattern:
//
//   if let icomProto = await rig.protocol as? IcomCIVProtocol {  // <- gone
//       ...
//   }
//
// The old `rig.protocol` accessor has been renamed to
// `rig.rawProtocol` and documented as an explicit escape hatch
// for cases the vendor-extension enum doesn't cover (hardware
// validators that reach into per-model API surface, custom
// simulators, etc.).
//
// Why a discriminated enum and not just a typed `asIcom: IcomCIVProtocol?`:
// the enum gives `switch` exhaustiveness — when we add a new
// vendor protocol the compiler tells every existing call site to
// handle the new case (or explicitly opt out via `default:`).
// That's the kind of forward-compatibility guard that's hard to
// retrofit later.

/// Typed handle to a radio's vendor-specific protocol actor.
///
/// Returned by ``RigController/vendorExtensions``. Pattern-match
/// to get the typed actor for whichever vendor the radio belongs
/// to. The protocol surface inside each case is the entire
/// concrete CATProtocol conformer — every vendor-specific method
/// the actor exposes is accessible without further casting.
public enum VendorExtensions: Sendable {
    /// Icom CI-V radios. The associated value is the same actor
    /// `RigController` uses internally; you can call any
    /// `IcomCIVProtocol` method on it directly.
    case icom(IcomCIVProtocol)

    /// Elecraft K-series radios.
    case elecraft(ElecraftProtocol)

    /// Yaesu radios.
    case yaesu(YaesuCATProtocol)

    /// Kenwood radios (excluding TH-D72).
    case kenwood(KenwoodProtocol)

    /// Kenwood TH-D72 / TH-D72A handheld.
    case thd72(THD72Protocol)

    /// Ten-Tec Orion-family transceivers.
    case tentecOrion(TenTecOrionProtocol)

    /// Ten-Tec legacy (Jupiter / Pegasus) transceivers.
    case tentecLegacy(TenTecLegacyProtocol)

    /// The in-memory dummy radio (no real hardware).
    case dummy(DummyCATProtocol)

    /// A vendor SwiftRigControl doesn't recognise. Use
    /// ``RigController/rawProtocol`` for direct access.
    case unknown(any CATProtocol)
}

extension RigController {

    /// Typed access to the underlying protocol actor for vendor-
    /// specific operations.
    ///
    /// Pattern-match on the returned ``VendorExtensions`` enum to
    /// reach methods that aren't part of the standard
    /// `RigController` API surface:
    ///
    /// ```swift
    /// switch await rig.vendorExtensions {
    /// case .icom(let icom):
    ///     try await icom.setAttenuatorIC9700(.dB12)
    /// case .elecraft(let k):
    ///     try await k.getTXStatus()
    /// default:
    ///     break  // not applicable to this radio
    /// }
    /// ```
    ///
    /// For absolutely-bare access to the protocol (custom
    /// simulators, debugging, hardware validators), see
    /// ``rawProtocol``.
    public var vendorExtensions: VendorExtensions {
        if let p = proto as? IcomCIVProtocol      { return .icom(p) }
        if let p = proto as? ElecraftProtocol     { return .elecraft(p) }
        if let p = proto as? YaesuCATProtocol     { return .yaesu(p) }
        if let p = proto as? THD72Protocol        { return .thd72(p) }
        if let p = proto as? KenwoodProtocol      { return .kenwood(p) }
        if let p = proto as? TenTecOrionProtocol  { return .tentecOrion(p) }
        if let p = proto as? TenTecLegacyProtocol { return .tentecLegacy(p) }
        if let p = proto as? DummyCATProtocol     { return .dummy(p) }
        return .unknown(proto)
    }
}
