import Foundation

// MARK: - Power Control

extension RigController {

    /// Sets the RF power level.
    ///
    /// The interpretation of `level` depends on the radio. Check
    /// ``RigCapabilities/powerUnits``:
    ///
    /// - ``PowerUnits/percentage`` — `level` is a 0–255 value that
    ///   maps to 0–100% of the radio's rated output. Most radios
    ///   currently in the database fall in this group.
    /// - ``PowerUnits/watts(max:)`` — `level` is integer wattage.
    ///
    /// Either way, valid range is 0 through
    /// ``RigCapabilities/maxPower``. Out-of-range values raise
    /// ``RigError/invalidParameter(_:)``.
    ///
    /// - Parameter level: Power level in the radio's native units.
    /// - Throws:
    ///   - ``RigError/notConnected`` if not connected.
    ///   - ``RigError/unsupportedOperation(_:)`` if the radio does
    ///     not support power control.
    ///   - ``RigError/invalidParameter(_:)`` if `level` is outside
    ///     `0...capabilities.maxPower`.
    ///
    /// - Example:
    /// ```swift
    /// // Always check capabilities.powerUnits to know the unit:
    /// switch rig.capabilities.powerUnits {
    /// case .percentage:        try await rig.setPower(128)  // 50%
    /// case .watts(let max):    try await rig.setPower(max / 2)
    /// }
    /// ```
    public func setPower(_ level: Int) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        guard radio.capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported by \(radio.fullName)")
        }

        guard level >= 0 && level <= radio.capabilities.maxPower else {
            throw RigError.invalidParameter(
                "Power must be between 0 and \(radio.capabilities.maxPower)"
            )
        }

        let p = try requireTrait((any SupportsPower).self, named: "Power control")
        try await p.setPower(level)
        emit(.powerChanged(level))
    }

    /// Deprecated. Use ``setPower(_:)`` with the new `level`
    /// argument label.
    ///
    /// Most callers used unlabeled `rig.setPower(50)` and are
    /// unaffected by the rename. Only callers who wrote
    /// `rig.setPower(watts: 50)` need to update — to
    /// `rig.setPower(50)` or `rig.setPower(level: 50)`. The
    /// parameter was renamed from `watts` to `level` because the
    /// unit depends on the radio (watts for most, percentage for
    /// Icom — see ``setPower(_:)`` doc).
    @available(*, deprecated, renamed: "setPower(_:)",
               message: "The parameter was renamed from 'watts' to 'level'; the unit depends on RigCapabilities.powerUnits (watts vs. percentage). Use setPower(_:) instead.")
    public func setPower(watts: Int) async throws {
        try await setPower(watts)
    }

    /// Gets the current RF power level.
    ///
    /// The returned value is in the radio's native units — see
    /// ``RigCapabilities/powerUnits`` and ``setPower(_:)`` for the
    /// interpretation.
    ///
    /// - Returns: Power level in the radio's native units.
    /// - Throws: ``RigError`` if operation fails.
    public func power() async throws -> Int {
        guard connected else {
            throw RigError.notConnected
        }
        let p = try requireTrait((any SupportsPower).self, named: "Power control")
        return try await p.getPower()
    }
}
