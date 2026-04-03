import Foundation

// MARK: - RIT/XIT Control

extension RigController {

    /// Sets the RIT (Receiver Incremental Tuning) state.
    ///
    /// RIT allows fine-tuning of the receiver frequency independently from the displayed
    /// VFO frequency. This is useful for:
    /// - Zero-beating CW signals
    /// - Compensating for slight frequency offsets
    /// - Contest and DX operation
    ///
    /// Most radios support offsets between -9999 Hz and +9999 Hz.
    ///
    /// - Parameter state: The desired RIT state (enabled/disabled and offset)
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support RIT
    ///
    /// # Example
    /// ```swift
    /// // Enable RIT with +500 Hz offset
    /// try await rig.setRIT(RITXITState(enabled: true, offset: 500))
    ///
    /// // Disable RIT
    /// try await rig.setRIT(.disabled)
    ///
    /// // Adjust offset while keeping RIT enabled
    /// try await rig.setRIT(RITXITState(enabled: true, offset: -200))
    /// ```
    public func setRIT(_ state: RITXITState) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        guard capabilities.supportsRIT else {
            throw RigError.unsupportedOperation("RIT not supported by \(radioName)")
        }

        try await proto.setRIT(state)
        // Invalidate cached RIT state
        await stateCache.invalidate("rit_state")
    }

    /// Gets the current RIT state.
    ///
    /// Queries both RIT ON/OFF status and frequency offset from the radio.
    ///
    /// - Parameter cached: Use cached value if available (default: true)
    /// - Returns: Current RIT state including enabled status and offset
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support RIT
    ///
    /// # Caching
    /// RIT state is cached for 500ms to reduce serial queries. Set `cached` to false
    /// for the most current state.
    ///
    /// # Example
    /// ```swift
    /// let ritState = try await rig.getRIT()
    /// print("RIT: \(ritState.description)")  // "ON (+500 Hz)" or "OFF"
    ///
    /// if ritState.enabled {
    ///     print("RIT offset: \(ritState.offset) Hz")
    /// }
    /// ```
    public func getRIT(cached: Bool = true) async throws -> RITXITState {
        guard connected else {
            throw RigError.notConnected
        }

        guard capabilities.supportsRIT else {
            throw RigError.unsupportedOperation("RIT not supported by \(radioName)")
        }

        if cached,
           let value: RITXITState = await stateCache.getIfValid("rit_state", maxAge: 0.5) {
            return value
        }
        if !cached {
            await stateCache.invalidate("rit_state")
        }
        let value = try await proto.getRIT()
        await stateCache.store(value, forKey: "rit_state")
        return value
    }

    /// Sets the XIT (Transmitter Incremental Tuning) state.
    ///
    /// XIT allows fine-tuning of the transmitter frequency independently from the displayed
    /// VFO frequency. This is useful for:
    /// - Split operation in contests
    /// - Working stations on slightly different frequencies
    /// - Compensating for transmit frequency offsets
    ///
    /// Most radios support offsets between -9999 Hz and +9999 Hz.
    ///
    /// **Note:** Not all radios support separate XIT control. Some radios (like IC-7100)
    /// only support RIT, which affects both RX and TX when transmitting.
    ///
    /// - Parameter state: The desired XIT state (enabled/disabled and offset)
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support XIT
    ///
    /// # Example
    /// ```swift
    /// // Enable XIT with -1000 Hz offset for split operation
    /// try await rig.setXIT(RITXITState(enabled: true, offset: -1000))
    ///
    /// // Disable XIT
    /// try await rig.setXIT(.disabled)
    /// ```
    public func setXIT(_ state: RITXITState) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        guard capabilities.supportsXIT else {
            throw RigError.unsupportedOperation("XIT not supported by \(radioName)")
        }

        try await proto.setXIT(state)
        // Invalidate cached XIT state
        await stateCache.invalidate("xit_state")
    }

    /// Gets the current XIT state.
    ///
    /// Queries both XIT ON/OFF status and frequency offset from the radio.
    ///
    /// **Note:** Not all radios support separate XIT control. This will throw
    /// `unsupportedOperation` for radios that don't support XIT.
    ///
    /// - Parameter cached: Use cached value if available (default: true)
    /// - Returns: Current XIT state including enabled status and offset
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support XIT
    ///
    /// # Caching
    /// XIT state is cached for 500ms to reduce serial queries. Set `cached` to false
    /// for the most current state.
    ///
    /// # Example
    /// ```swift
    /// let xitState = try await rig.getXIT()
    /// print("XIT: \(xitState.description)")  // "ON (-1000 Hz)" or "OFF"
    /// ```
    public func getXIT(cached: Bool = true) async throws -> RITXITState {
        guard connected else {
            throw RigError.notConnected
        }

        guard capabilities.supportsXIT else {
            throw RigError.unsupportedOperation("XIT not supported by \(radioName)")
        }

        if cached,
           let value: RITXITState = await stateCache.getIfValid("xit_state", maxAge: 0.5) {
            return value
        }
        if !cached {
            await stateCache.invalidate("xit_state")
        }
        let value = try await proto.getXIT()
        await stateCache.store(value, forKey: "xit_state")
        return value
    }
}
