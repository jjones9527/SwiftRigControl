import Foundation

// MARK: - DSP Controls

extension RigController {

    /// Sets the AGC (Automatic Gain Control) speed.
    ///
    /// AGC controls how quickly the receiver responds to changes in signal strength.
    /// Different speeds are optimal for different operating modes:
    /// - **Fast**: Best for CW and digital modes where rapid signal changes occur
    /// - **Medium**: Good general-purpose setting for SSB and mixed modes
    /// - **Slow**: Preferred for weak signal SSB work and DXing
    /// - **Off**: Disables AGC for manual gain control (advanced users only)
    ///
    /// - Parameter speed: The desired AGC speed
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if AGC control not supported
    ///   - `RigError.invalidParameter` if speed not supported by this radio
    ///
    /// # Example
    /// ```swift
    /// // Fast AGC for CW operation
    /// try await rig.setAGC(.fast)
    ///
    /// // Slow AGC for weak signal SSB DXing
    /// try await rig.setAGC(.slow)
    ///
    /// // Medium AGC for general SSB
    /// try await rig.setAGC(.medium)
    /// ```
    ///
    /// # Radio Support
    /// AGC control is supported on most modern Icom radios:
    /// - IC-9700, IC-7610, IC-7300, IC-7600, IC-7100, IC-705
    /// - IC-7851, IC-7800, IC-7700
    ///
    /// Note: IC-7600/7300/7610/7851 do not support AGC OFF.
    public func setAGC(_ speed: AGCSpeed) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.setAGC(speed)
        // Invalidate cached AGC setting
        await stateCache.invalidate("agc_speed")
    }

    /// Gets the current AGC speed.
    ///
    /// - Parameter cached: Whether to use cached value if available (defaults to true)
    /// - Returns: Current AGC speed setting
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if AGC control not supported
    ///
    /// # Caching
    /// When `cached` is true, the controller returns a cached AGC setting if available
    /// and less than 500ms old. Set `cached` to false to force a fresh query.
    ///
    /// # Example
    /// ```swift
    /// // Get current AGC setting
    /// let agc = try await rig.agc()
    /// print("Current AGC: \(agc.description)")  // "Fast AGC"
    ///
    /// // Force fresh query
    /// let freshAGC = try await rig.agc(cached: false)
    /// ```
    public func agc(cached: Bool = true) async throws -> AGCSpeed {
        guard connected else {
            throw RigError.notConnected
        }

        if cached,
           let value: AGCSpeed = await stateCache.getIfValid("agc_speed", maxAge: 0.5) {
            return value
        }
        if !cached {
            await stateCache.invalidate("agc_speed")
        }
        let value = try await proto.getAGC()
        await stateCache.store(value, forKey: "agc_speed")
        return value
    }

    /// Sets the noise blanker configuration.
    ///
    /// Noise blanker removes impulse noise such as power line noise, ignition noise,
    /// and static crashes. Different radios support different NB capabilities:
    /// - Some radios have simple on/off control
    /// - Others have adjustable NB level (0-255)
    ///
    /// - Parameter config: The desired noise blanker configuration
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if NB not supported
    ///   - `RigError.invalidParameter` if level out of range for this radio
    ///
    /// # Example
    /// ```swift
    /// // Enable NB with level 5
    /// try await rig.setNoiseBlanker(.enabled(level: 5))
    ///
    /// // Disable NB
    /// try await rig.setNoiseBlanker(.off)
    ///
    /// // Enable NB (radios without level control)
    /// try await rig.setNoiseBlanker(.enabled())
    /// ```
    public func setNoiseBlanker(_ config: NoiseBlanker) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.setNoiseBlanker(config)
        await stateCache.invalidate("noise_blanker")
    }

    /// Gets the current noise blanker configuration.
    ///
    /// Returns the current NB state including level if the radio supports it.
    ///
    /// - Parameter cached: Whether to use cached value (default true)
    /// - Returns: Current noise blanker configuration
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if NB not supported
    ///
    /// # Example
    /// ```swift
    /// let nb = try await rig.noiseBlanker()
    /// if nb.isEnabled {
    ///     print("NB enabled, level: \(nb.level ?? 0)")
    /// }
    /// ```
    public func noiseBlanker(cached: Bool = true) async throws -> NoiseBlanker {
        guard connected else {
            throw RigError.notConnected
        }

        if cached,
           let value: NoiseBlanker = await stateCache.getIfValid("noise_blanker", maxAge: 0.5) {
            return value
        }
        if !cached {
            await stateCache.invalidate("noise_blanker")
        }
        let value = try await proto.getNoiseBlanker()
        await stateCache.store(value, forKey: "noise_blanker")
        return value
    }

    /// Sets the noise reduction configuration.
    ///
    /// Noise reduction uses DSP filtering to reduce continuous background noise
    /// while preserving the desired signal. Higher levels provide better noise
    /// reduction but may affect audio fidelity.
    ///
    /// - Parameter config: The desired noise reduction configuration
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if NR not supported
    ///   - `RigError.invalidParameter` if level out of range for this radio
    ///
    /// # Example
    /// ```swift
    /// // Enable NR with level 8
    /// try await rig.setNoiseReduction(.enabled(level: 8))
    ///
    /// // Disable NR
    /// try await rig.setNoiseReduction(.off)
    ///
    /// // Maximum NR for weak signal work
    /// try await rig.setNoiseReduction(.enabled(level: 15))
    /// ```
    public func setNoiseReduction(_ config: NoiseReduction) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.setNoiseReduction(config)
        await stateCache.invalidate("noise_reduction")
    }

    /// Gets the current noise reduction configuration.
    ///
    /// Returns the current NR state including level.
    ///
    /// - Parameter cached: Whether to use cached value (default true)
    /// - Returns: Current noise reduction configuration
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if NR not supported
    ///
    /// # Example
    /// ```swift
    /// let nr = try await rig.noiseReduction()
    /// if nr.isEnabled {
    ///     print("NR enabled, level: \(nr.level ?? 0)")
    /// }
    /// ```
    public func noiseReduction(cached: Bool = true) async throws -> NoiseReduction {
        guard connected else {
            throw RigError.notConnected
        }

        if cached,
           let value: NoiseReduction = await stateCache.getIfValid("noise_reduction", maxAge: 0.5) {
            return value
        }
        if !cached {
            await stateCache.invalidate("noise_reduction")
        }
        let value = try await proto.getNoiseReduction()
        await stateCache.store(value, forKey: "noise_reduction")
        return value
    }

    /// Sets the IF (Intermediate Frequency) filter selection.
    ///
    /// Selects which of the radio's preset IF filters to use (FIL1/FIL2/FIL3).
    /// Each mode has independent filter settings stored in the radio.
    /// Narrower filters reduce adjacent channel interference.
    ///
    /// - Parameter filter: The filter to select
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if IF filter control not supported
    ///
    /// # Example
    /// ```swift
    /// // Select narrow filter for CW weak signal work
    /// try await rig.setIFFilter(.filter3)
    ///
    /// // Select default filter
    /// try await rig.setIFFilter(.filter1)
    /// ```
    public func setIFFilter(_ filter: IFFilter) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.setIFFilter(filter)
        await stateCache.invalidate("if_filter")
    }

    /// Gets the current IF filter selection.
    ///
    /// Returns which preset filter is currently active (FIL1/FIL2/FIL3).
    ///
    /// - Parameter cached: Whether to use cached value (default true)
    /// - Returns: Current IF filter selection
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if IF filter control not supported
    ///
    /// # Example
    /// ```swift
    /// let filter = try await rig.ifFilter()
    /// print("Current filter: \(filter.description)")  // "FIL2 (Medium)"
    /// ```
    public func ifFilter(cached: Bool = true) async throws -> IFFilter {
        guard connected else {
            throw RigError.notConnected
        }

        if cached,
           let value: IFFilter = await stateCache.getIfValid("if_filter", maxAge: 0.5) {
            return value
        }
        if !cached {
            await stateCache.invalidate("if_filter")
        }
        let value = try await proto.getIFFilter()
        await stateCache.store(value, forKey: "if_filter")
        return value
    }
}
