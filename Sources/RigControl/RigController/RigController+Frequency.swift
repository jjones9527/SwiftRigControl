import Foundation

// MARK: - Frequency Control

extension RigController {

    /// Sets the operating frequency of the specified VFO.
    ///
    /// - Parameters:
    ///   - hz: The desired frequency in Hertz (e.g., 14230000 for 14.230 MHz)
    ///   - vfo: The VFO to set (defaults to VFO A)
    ///
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.commandFailed` if radio rejects the frequency
    ///   - `RigError.timeout` if radio doesn't respond
    ///
    /// - Example:
    /// ```swift
    /// try await rig.setFrequency(14_230_000, vfo: .a)  // 20m SSTV calling frequency
    /// ```
    public func setFrequency(_ hz: UInt64, vfo: VFO = .a) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.setFrequency(hz, vfo: vfo)
        // Invalidate cached frequency for this VFO
        await stateCache.invalidate("freq_\(vfo)")
    }

    /// Gets the current operating frequency of the specified VFO.
    ///
    /// - Parameters:
    ///   - vfo: The VFO to query (defaults to VFO A)
    ///   - cached: Whether to use cached value if available (defaults to true)
    /// - Returns: The current frequency in Hertz
    /// - Throws: `RigError` if operation fails
    ///
    /// # Caching
    /// When `cached` is true, the controller returns a cached frequency if available
    /// and less than 500ms old. This significantly improves performance for frequent
    /// queries (10-20x faster). Set `cached` to false to force a fresh query.
    ///
    /// - Example:
    /// ```swift
    /// // Fast cached read
    /// let freq = try await rig.frequency(cached: true)
    ///
    /// // Force fresh query
    /// let freshFreq = try await rig.frequency(cached: false)
    /// ```
    public func frequency(vfo: VFO = .a, cached: Bool = true) async throws -> UInt64 {
        guard connected else {
            throw RigError.notConnected
        }

        if cached,
           let value: UInt64 = await stateCache.getIfValid("freq_\(vfo)", maxAge: 0.5) {
            return value
        }
        if !cached {
            await stateCache.invalidate("freq_\(vfo)")
        }
        let value = try await proto.getFrequency(vfo: vfo)
        await stateCache.store(value, forKey: "freq_\(vfo)")
        return value
    }
}
