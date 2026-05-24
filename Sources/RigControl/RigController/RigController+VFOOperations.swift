import Foundation

// MARK: - Compound VFO operations (v1.1 parity)

extension RigController {

    /// Performs a compound VFO operation (A↔B swap, copy, memory
    /// write/recall, ATU tune, …).
    ///
    /// Compound operations are vendor-specific on the wire but
    /// uniform at the API surface — a single call triggers what
    /// would otherwise be a multi-step set of get/set operations.
    /// The classic example is `.exchange`: every modern radio has
    /// a one-button "A↔B" front-panel key, and this is the
    /// programmatic equivalent.
    ///
    /// - Parameter op: Which operation to perform. See
    ///   ``VFOOperation`` for the full set.
    /// - Throws:
    ///   - ``RigError/notConnected`` if the controller isn't
    ///     connected.
    ///   - ``RigError/unsupportedOperation(_:)`` if the radio
    ///     doesn't support the requested op (check
    ///     ``RigCapabilities/supportedVFOOperations`` to gate
    ///     UI before calling).
    ///   - ``RigError/commandFailed(_:)`` if the radio rejected
    ///     the wire command (common for `.tune` when no ATU is
    ///     installed, or `.memoryClear` against an already-empty
    ///     channel on some radios).
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Swap A↔B (most common compound op).
    /// try await rig.performVFOOperation(.exchange)
    ///
    /// // Copy active VFO to the other one.
    /// try await rig.performVFOOperation(.copyVFO)
    ///
    /// // Trigger ATU tune (radios with built-in tuner).
    /// try await rig.performVFOOperation(.tune)
    /// ```
    public func performVFOOperation(_ op: VFOOperation) async throws {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait(
            (any SupportsVFOOperations).self,
            named: "VFO operations"
        )
        guard capabilities.supportedVFOOperations.contains(op) else {
            throw RigError.unsupportedOperation(
                "VFO operation '\(op.rawValue)' not supported by this radio"
            )
        }
        try await p.performVFOOperation(op)
    }
}
