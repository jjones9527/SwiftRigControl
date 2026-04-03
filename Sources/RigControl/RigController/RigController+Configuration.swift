import Foundation

// MARK: - Batch Configuration

extension RigController {

    /// Configure multiple radio parameters in one call.
    ///
    /// This is a convenience method for setting up the radio with multiple parameters
    /// in a single operation. All parameters are optional, and only specified parameters
    /// will be changed.
    ///
    /// - Parameters:
    ///   - frequency: Frequency in Hz (optional)
    ///   - mode: Operating mode (optional)
    ///   - vfo: Target VFO (default: .a)
    ///   - power: Transmit power in watts (optional)
    /// - Throws: `RigError` if any operation fails
    ///
    /// # Example
    /// ```swift
    /// // Set up for FT8 on 20m
    /// try await rig.configure(
    ///     frequency: 14_074_000,
    ///     mode: .dataUSB,
    ///     power: 50
    /// )
    ///
    /// // Quick band change
    /// try await rig.configure(frequency: 7_074_000)
    ///
    /// // Mode change only
    /// try await rig.configure(mode: .cw)
    /// ```
    public func configure(
        frequency: UInt64? = nil,
        mode: Mode? = nil,
        vfo: VFO = .a,
        power: Int? = nil
    ) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        // Apply in optimal order (frequency, mode, power)
        // This ensures mode filter settings are applied after frequency
        if let frequency = frequency {
            try await setFrequency(frequency, vfo: vfo)
        }

        if let mode = mode {
            try await setMode(mode, vfo: vfo)
        }

        if let power = power {
            try await setPower(power)
        }
    }
}
