import Foundation

// MARK: - Power Control

extension RigController {

    /// Sets the RF power level.
    ///
    /// - Parameter watts: Power level in watts (0 to radio's maximum power)
    /// - Throws:
    ///   - `RigError.unsupportedOperation` if radio doesn't support power control
    ///   - `RigError.invalidParameter` if watts exceeds radio's maximum
    ///
    /// - Example:
    /// ```swift
    /// try await rig.setPower(50)  // Set to 50 watts
    /// ```
    public func setPower(_ watts: Int) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        guard radio.capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported by \(radio.fullName)")
        }

        guard watts >= 0 && watts <= radio.capabilities.maxPower else {
            throw RigError.invalidParameter(
                "Power must be between 0 and \(radio.capabilities.maxPower) watts"
            )
        }

        try await proto.setPower(watts)
    }

    /// Gets the current RF power level.
    ///
    /// - Returns: Power level in watts
    /// - Throws: `RigError` if operation fails
    public func power() async throws -> Int {
        guard connected else {
            throw RigError.notConnected
        }
        return try await proto.getPower()
    }
}
