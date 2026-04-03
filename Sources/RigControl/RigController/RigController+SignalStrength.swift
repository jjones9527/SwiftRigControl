import Foundation

// MARK: - Signal Strength

extension RigController {

    /// Reads the current signal strength from the radio's S-meter.
    ///
    /// S-meter readings provide real-time signal strength information:
    /// - S0 to S9 represent standard signal levels
    /// - Above S9, readings are expressed as "S9 plus decibels" (e.g., S9+20)
    ///
    /// - Parameters:
    ///   - cached: Whether to use cached value if available (defaults to true)
    /// - Returns: Current signal strength
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if radio doesn't support S-meter reading
    ///
    /// # Caching
    /// Signal strength readings are cached for 500ms by default to allow for
    /// rapid UI updates without overloading the serial port. Set `cached` to false
    /// for the most recent reading.
    ///
    /// # Example
    /// ```swift
    /// let signal = try await rig.signalStrength()
    /// print("Signal: \(signal.description)")  // "S7" or "S9+20"
    ///
    /// if signal.isStrongSignal {
    ///     print("Strong signal detected!")
    /// }
    /// ```
    public func signalStrength(cached: Bool = true) async throws -> SignalStrength {
        guard connected else {
            throw RigError.notConnected
        }

        if cached,
           let value: SignalStrength = await stateCache.getIfValid("signal_strength", maxAge: 0.5) {
            return value
        }
        if !cached {
            await stateCache.invalidate("signal_strength")
        }
        let value = try await proto.getSignalStrength()
        await stateCache.store(value, forKey: "signal_strength")
        return value
    }
}
