import Foundation

// MARK: - AF Gain, RF Gain, Squelch, Preamp, Attenuator, Power State

/// Public API for receive-chain level controls and power state via `RigController`.
///
/// All methods respect the `connected` guard and use `stateCache` for efficient
/// repeated reads. Write operations invalidate the relevant cache entry.
extension RigController {

    // MARK: - AF Gain

    /// Sets the AF (audio) output gain.
    ///
    /// Controls the speaker/headphone volume. Mapped to a 0–255 scale regardless
    /// of the radio's internal representation.
    ///
    /// - Parameter level: Gain level from 0 (mute) to 255 (maximum)
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if the radio does not support AF gain control
    public func setAFGain(_ level: Int) async throws {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsAFGain).self, named: "AF gain control")
        try await p.setAFGain(level)
        await stateCache.invalidate("af_gain")
        emit(.levelChanged(kind: .afGain, value: level))
    }

    /// Gets the current AF gain.
    ///
    /// - Parameter cached: Use cached value if available and < 500 ms old (default: `true`)
    /// - Returns: Gain level from 0 to 255
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if not supported
    public func afGain(cached: Bool = true) async throws -> Int {
        guard connected else { throw RigError.notConnected }
        if cached, let value: Int = await stateCache.getIfValid("af_gain") {
            return value
        }
        if !cached { await stateCache.invalidate("af_gain") }
        let p = try requireTrait((any SupportsAFGain).self, named: "AF gain control")
        let value = try await p.getAFGain()
        await stateCache.store(value, forKey: "af_gain")
        return value
    }

    // MARK: - RF Gain

    /// Sets the RF (receiver) gain.
    ///
    /// Reducing RF gain helps prevent front-end overloading from strong nearby stations.
    ///
    /// - Parameter level: Gain level from 0 (minimum) to 255 (maximum / full sensitivity)
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if not supported
    public func setRFGain(_ level: Int) async throws {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsRFGain).self, named: "RF gain control")
        try await p.setRFGain(level)
        await stateCache.invalidate("rf_gain")
        emit(.levelChanged(kind: .rfGain, value: level))
    }

    /// Gets the current RF gain.
    ///
    /// - Parameter cached: Use cached value if available and < 500 ms old (default: `true`)
    /// - Returns: Gain level from 0 to 255
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if not supported
    public func rfGain(cached: Bool = true) async throws -> Int {
        guard connected else { throw RigError.notConnected }
        if cached, let value: Int = await stateCache.getIfValid("rf_gain") {
            return value
        }
        if !cached { await stateCache.invalidate("rf_gain") }
        let p = try requireTrait((any SupportsRFGain).self, named: "RF gain control")
        let value = try await p.getRFGain()
        await stateCache.store(value, forKey: "rf_gain")
        return value
    }

    // MARK: - Squelch

    /// Sets the squelch level.
    ///
    /// On FM/VHF/UHF radios this is the carrier squelch threshold.
    /// On HF radios it may be a noise or S-meter squelch.
    ///
    /// - Parameter level: Squelch level from 0 (always open) to 255 (maximum / tightest)
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if not supported
    public func setSquelch(_ level: Int) async throws {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsSquelch).self, named: "Squelch control")
        try await p.setSquelch(level)
        await stateCache.invalidate("squelch")
        emit(.levelChanged(kind: .squelch, value: level))
    }

    /// Gets the current squelch level.
    ///
    /// - Parameter cached: Use cached value if available and < 500 ms old (default: `true`)
    /// - Returns: Squelch level from 0 to 255
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if not supported
    public func squelch(cached: Bool = true) async throws -> Int {
        guard connected else { throw RigError.notConnected }
        if cached, let value: Int = await stateCache.getIfValid("squelch") {
            return value
        }
        if !cached { await stateCache.invalidate("squelch") }
        let p = try requireTrait((any SupportsSquelch).self, named: "Squelch control")
        let value = try await p.getSquelch()
        await stateCache.store(value, forKey: "squelch")
        return value
    }

    // MARK: - Preamp

    /// Sets the preamplifier stage.
    ///
    /// - Parameter level: 0 = off, 1 = Preamp 1 (~+10 dB), 2 = Preamp 2 (~+20 dB)
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if not supported
    ///   - `RigError.invalidParameter` if the level is out of range for this radio
    public func setPreamp(_ level: Int) async throws {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsPreamp).self, named: "Preamp control")
        try await p.setPreamp(level)
        await stateCache.invalidate("preamp")
        emit(.levelChanged(kind: .preamp, value: level))
    }

    /// Gets the current preamplifier stage.
    ///
    /// - Parameter cached: Use cached value if available and < 500 ms old (default: `true`)
    /// - Returns: 0 = off, 1 = Preamp 1, 2 = Preamp 2
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if not supported
    public func preamp(cached: Bool = true) async throws -> Int {
        guard connected else { throw RigError.notConnected }
        if cached, let value: Int = await stateCache.getIfValid("preamp") {
            return value
        }
        if !cached { await stateCache.invalidate("preamp") }
        let p = try requireTrait((any SupportsPreamp).self, named: "Preamp control")
        let value = try await p.getPreamp()
        await stateCache.store(value, forKey: "preamp")
        return value
    }

    // MARK: - Attenuator

    /// Sets the front-end attenuator.
    ///
    /// Reduces the RF gain ahead of the first mixer. Available steps are model-dependent
    /// (typically 0, 6, 12, or 18 dB on Icom radios; 0 or 20 dB on some others).
    ///
    /// - Parameter dB: Attenuation in dB — 0 (off) or a model-specific positive value
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if not supported
    ///   - `RigError.invalidParameter` if the dB value is not available on this radio
    public func setAttenuator(_ dB: Int) async throws {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsAttenuator).self, named: "Attenuator control")
        try await p.setAttenuator(dB)
        await stateCache.invalidate("attenuator")
        emit(.levelChanged(kind: .attenuator, value: dB))
    }

    /// Gets the current attenuator level in dB (0 = off).
    ///
    /// - Parameter cached: Use cached value if available and < 500 ms old (default: `true`)
    /// - Returns: Attenuation in dB
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if not supported
    public func attenuator(cached: Bool = true) async throws -> Int {
        guard connected else { throw RigError.notConnected }
        if cached, let value: Int = await stateCache.getIfValid("attenuator") {
            return value
        }
        if !cached { await stateCache.invalidate("attenuator") }
        let p = try requireTrait((any SupportsAttenuator).self, named: "Attenuator control")
        let value = try await p.getAttenuator()
        await stateCache.store(value, forKey: "attenuator")
        return value
    }

    // MARK: - Power State

    /// Powers the radio on (`true`) or puts it in standby (`false`).
    ///
    /// Support varies by radio and interface. Most Icom radios accept power-off
    /// via CI-V; power-on typically requires a dedicated RS-232 or CI-V wakeup.
    ///
    /// - Parameter on: `true` to power on, `false` for standby / power-off
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if the radio does not support remote power control
    public func setPowerState(_ on: Bool) async throws {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsRemotePowerState).self, named: "Remote power control")
        try await p.setPowerState(on)
        emit(.powerStateChanged(on: on))
    }

    /// Returns `true` if the radio is powered on and responding.
    ///
    /// Probes the radio with a lightweight command. A timeout means the radio is
    /// off or in standby.
    ///
    /// - Throws:
    ///   - `RigError.notConnected` if not connected to the serial/network interface
    ///   - `RigError.unsupportedOperation` if not supported
    public func getPowerState() async throws -> Bool {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsRemotePowerState).self, named: "Remote power state query")
        return try await p.getPowerState()
    }
}
