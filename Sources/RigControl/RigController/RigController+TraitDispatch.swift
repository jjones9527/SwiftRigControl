import Foundation

// MARK: - Trait dispatch helper (Phase 5.1)
//
// Every RigController accessor that touches a non-core CATProtocol
// feature has to cast `proto` to the matching trait protocol and
// throw .unsupportedOperation if the cast fails. Without help,
// each call site looks like:
//
//   guard let p = proto as? any SupportsAGC else {
//       throw RigError.unsupportedOperation("AGC ... not supported")
//   }
//
// `requireTrait` centralises that, so call sites read as:
//
//   let p = try requireTrait((any SupportsAGC).self,
//                            named: "AGC (Automatic Gain Control)")
//   try await p.setAGC(speed)
//
// The error message format matches what the old default-throw
// extensions produced verbatim, so app code that catches and
// matches on .unsupportedOperation strings sees no change.

extension RigController {

    /// Casts the underlying ``CATProtocol`` to the requested trait
    /// protocol, or throws ``RigError/unsupportedOperation(_:)``
    /// with a uniform message.
    ///
    /// - Parameters:
    ///   - trait: Trait protocol metatype (e.g.
    ///     `(any SupportsAGC).self`).
    ///   - feature: Human-readable feature name used in the error
    ///     message — must match the string the old default-throw
    ///     extension produced so existing apps that match error
    ///     strings keep working.
    internal func requireTrait<T>(
        _ trait: T.Type,
        named feature: String
    ) throws -> T {
        guard let p = proto as? T else {
            throw RigError.unsupportedOperation("\(feature) not supported")
        }
        return p
    }
}
