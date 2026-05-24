import Foundation

// MARK: - Function toggles (v1.1 parity)

extension RigController {

    /// Enables or disables a radio function bit (speech
    /// compressor, VOX, CTCSS, lock, ATU enable, …).
    ///
    /// - Parameters:
    ///   - function: Which function to toggle. See ``RigFunction``
    ///     for the full set.
    ///   - enabled: `true` to turn on, `false` to turn off.
    /// - Throws:
    ///   - ``RigError/notConnected`` if the controller isn't
    ///     connected.
    ///   - ``RigError/unsupportedOperation(_:)`` if the radio
    ///     doesn't claim this function in
    ///     ``RigCapabilities/supportedFunctions``.
    ///   - ``RigError/commandFailed(_:)`` if the radio NAK'd the
    ///     wire command.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Turn on the speech compressor.
    /// try await rig.setFunction(.compressor, enabled: true)
    ///
    /// // Engage front-panel lock so the operator can't fiddle.
    /// try await rig.setFunction(.lock, enabled: true)
    /// ```
    public func setFunction(_ function: RigFunction, enabled: Bool) async throws {
        guard connected else { throw RigError.notConnected }
        guard capabilities.supportedFunctions.contains(function) else {
            throw RigError.unsupportedOperation(
                "Function '\(function.rawValue)' not supported by this radio"
            )
        }
        let p = try requireTrait(
            (any SupportsFunctions).self,
            named: "Function toggles"
        )
        try await p.setFunction(function, enabled: enabled)
    }

    /// Reads the current state of a radio function bit.
    ///
    /// - Parameter function: Which function to query.
    /// - Returns: `true` if enabled, `false` if disabled.
    /// - Throws: ``RigError/notConnected``,
    ///   ``RigError/unsupportedOperation(_:)``,
    ///   ``RigError/commandFailed(_:)`` per ``setFunction(_:enabled:)``.
    public func getFunction(_ function: RigFunction) async throws -> Bool {
        guard connected else { throw RigError.notConnected }
        guard capabilities.supportedFunctions.contains(function) else {
            throw RigError.unsupportedOperation(
                "Function '\(function.rawValue)' not supported by this radio"
            )
        }
        let p = try requireTrait(
            (any SupportsFunctions).self,
            named: "Function toggles"
        )
        return try await p.getFunction(function)
    }
}
