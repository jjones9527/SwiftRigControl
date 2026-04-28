import Foundation

// MARK: - AF Gain, RF Gain, Squelch, Preamp, Attenuator, AGC, DSP, Power State, Memory

/// Level controls, DSP settings, power state, and memory operations for Elecraft CAT radios.
///
/// ## K2 vs K3/K4 Differences
/// The K2 does not echo SET commands — only QUERY commands produce a response.
/// All set methods here honour the `isK2` flag and add the required 50ms inter-command
/// delay for the K2 instead of reading an echo.
///
/// ## Command Reference (Elecraft CAT)
/// - `AGnnn` — Set AF gain (000–255); `AG` — Get
/// - `RGnnn` — Set RF gain (000–255); `RG` — Get
/// - `SQnnn` — Set squelch (000–255); `SQ` — Get
/// - `PAn` — Set preamp (0=off, 1=on); `PA` — Get
/// - `RAnn` — Set attenuator (00=off, 01=6/10dB, 02=12/20dB); `RA` — Get
/// - `GTnnn` — Set AGC (000=fast, 001=slow on K2; 000=fast,001=mid,002=slow on K3/K4)
/// - `NB0`/`NB1` — Noise blanker off/on; `NB` — Get
/// - `NR0`/`NR1` — Noise reduction off/on; `NR` — Get
/// - `BW` — IF bandwidth (K3/K4 only, 4-digit Hz value)
/// - `PS1`/`PS0` — Power on/standby; `PS` — Get
/// - `MCnnn` — Recall memory channel; `MW` — Write memory
extension ElecraftProtocol {

    // MARK: - AF Gain

    /// Sets the AF (audio) output gain.
    ///
    /// Command: `AGnnn;` where nnn is 000–255.
    ///
    /// Note: On the K2 the AF gain range is 000–060; values are clamped automatically.
    ///
    /// - Parameter level: Gain level 0–255
    /// - Throws: `RigError` if the command fails
    public func setAFGain(_ level: Int) async throws {
        let clamped = min(max(level, 0), 255)
        let command = String(format: "AG%03d", clamped)
        try await sendCommand(command)
        if !isK2 {
            _ = try await receiveResponse()
        } else {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    /// Gets the current AF gain.
    ///
    /// Command: `AG;` — Response: `AGnnn;`
    ///
    /// - Returns: Gain level 0–255
    /// - Throws: `RigError` if the command fails
    public func getAFGain() async throws -> Int {
        try await sendCommand("AG")
        let response = try await receiveResponse()
        // Response: AGnnn
        guard response.hasPrefix("AG"), response.count >= 5 else {
            throw RigError.invalidResponse
        }
        let start = response.index(response.startIndex, offsetBy: 2)
        let end = response.index(start, offsetBy: 3)
        guard let value = Int(response[start..<end]) else { throw RigError.invalidResponse }
        return value
    }

    // MARK: - RF Gain

    /// Sets the RF gain.
    ///
    /// Command: `RGnnn;` where nnn is 000–255.
    ///
    /// - Parameter level: Gain level 0–255
    /// - Throws: `RigError` if the command fails
    public func setRFGain(_ level: Int) async throws {
        let clamped = min(max(level, 0), 255)
        let command = String(format: "RG%03d", clamped)
        try await sendCommand(command)
        if !isK2 {
            _ = try await receiveResponse()
        } else {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    /// Gets the current RF gain.
    ///
    /// Command: `RG;` — Response: `RGnnn;`
    ///
    /// - Returns: Gain level 0–255
    /// - Throws: `RigError` if the command fails
    public func getRFGain() async throws -> Int {
        try await sendCommand("RG")
        let response = try await receiveResponse()
        // Response: RGnnn
        guard response.hasPrefix("RG"), response.count >= 5 else {
            throw RigError.invalidResponse
        }
        let start = response.index(response.startIndex, offsetBy: 2)
        let end = response.index(start, offsetBy: 3)
        guard let value = Int(response[start..<end]) else { throw RigError.invalidResponse }
        return value
    }

    // MARK: - Squelch

    /// Sets the squelch level.
    ///
    /// Command: `SQnnn;` where nnn is 000–255.
    ///
    /// Note: On the K2 squelch has a narrower effective range (000–029 typically).
    ///
    /// - Parameter level: Squelch threshold 0 (open) – 255 (closed)
    /// - Throws: `RigError` if the command fails
    public func setSquelch(_ level: Int) async throws {
        let clamped = min(max(level, 0), 255)
        let command = String(format: "SQ%03d", clamped)
        try await sendCommand(command)
        if !isK2 {
            _ = try await receiveResponse()
        } else {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    /// Gets the current squelch level.
    ///
    /// Command: `SQ;` — Response: `SQnnn;`
    ///
    /// - Returns: Squelch level 0–255
    /// - Throws: `RigError` if the command fails
    public func getSquelch() async throws -> Int {
        try await sendCommand("SQ")
        let response = try await receiveResponse()
        // Response: SQnnn
        guard response.hasPrefix("SQ"), response.count >= 5 else {
            throw RigError.invalidResponse
        }
        let start = response.index(response.startIndex, offsetBy: 2)
        let end = response.index(start, offsetBy: 3)
        guard let value = Int(response[start..<end]) else { throw RigError.invalidResponse }
        return value
    }

    // MARK: - Preamp

    /// Sets the preamplifier state.
    ///
    /// Command: `PAn;` — 0 = off, 1 = preamp on.
    ///
    /// The K2 has a single preamp stage. The K3/K4 have two stages; level 2 activates
    /// the second stage where supported.
    ///
    /// - Parameter level: 0 = off, 1 = Preamp 1, 2 = Preamp 2 (K3/K4 only)
    /// - Throws: `RigError.invalidParameter` for out-of-range values
    public func setPreamp(_ level: Int) async throws {
        guard (0...2).contains(level) else {
            throw RigError.invalidParameter("Preamp level must be 0 (off), 1 (Preamp 1), or 2 (Preamp 2)")
        }
        let command = "PA\(level)"
        try await sendCommand(command)
        if !isK2 {
            _ = try await receiveResponse()
        } else {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    /// Gets the current preamplifier state.
    ///
    /// Command: `PA;` — Response: `PAn;`
    ///
    /// - Returns: 0 = off, 1 = Preamp 1, 2 = Preamp 2
    /// - Throws: `RigError` if the command fails
    public func getPreamp() async throws -> Int {
        try await sendCommand("PA")
        let response = try await receiveResponse()
        // Response: PAn
        guard response.hasPrefix("PA"), response.count >= 3 else {
            throw RigError.invalidResponse
        }
        let idx = response.index(response.startIndex, offsetBy: 2)
        guard let value = Int(String(response[idx])) else { throw RigError.invalidResponse }
        return value
    }

    // MARK: - Attenuator

    /// Sets the front-end attenuator.
    ///
    /// Command: `RAnn;` — Elecraft attenuator step codes:
    /// - 00 = off
    /// - 01 = 10 dB (K2) or 6 dB (K3/K4)
    /// - 02 = 20 dB (K2) — K3/K4 may not support this step
    ///
    /// This method accepts values in dB and maps them to the closest available step.
    /// Pass 0 to disable, 6 for the first attenuation step, 10 or 12 for the second
    /// (the mapping is applied based on `isK2`).
    ///
    /// - Parameter dB: Attenuation in dB — 0, 6, 10, 12, or 20
    /// - Throws: `RigError.invalidParameter` for unsupported values
    public func setAttenuator(_ dB: Int) async throws {
        let code: Int
        switch dB {
        case 0:
            code = 0
        case 1...10:
            code = 1   // K3/K4: 6dB step; K2: 10dB step
        case 11...20:
            code = isK2 ? 2 : 1   // K2: 20dB step; K3/K4 has only one step
        default:
            throw RigError.invalidParameter("Unsupported attenuator level: \(dB) dB")
        }
        let command = String(format: "RA%02d", code)
        try await sendCommand(command)
        if !isK2 {
            _ = try await receiveResponse()
        } else {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    /// Gets the current attenuator level.
    ///
    /// Command: `RA;` — Response: `RAnn;`
    ///
    /// Returns the closest standard dB value: 0, 6/10, or 12/20 depending on model.
    ///
    /// - Returns: Attenuation in dB (0, 6, or 10)
    /// - Throws: `RigError` if the command fails
    public func getAttenuator() async throws -> Int {
        try await sendCommand("RA")
        let response = try await receiveResponse()
        // Response: RAnn
        guard response.hasPrefix("RA"), response.count >= 4 else {
            throw RigError.invalidResponse
        }
        let start = response.index(response.startIndex, offsetBy: 2)
        let end = response.index(start, offsetBy: 2)
        guard let code = Int(response[start..<end]) else { throw RigError.invalidResponse }
        switch code {
        case 0:  return 0
        case 1:  return isK2 ? 10 : 6
        default: return isK2 ? 20 : 6
        }
    }

    // MARK: - AGC

    /// Sets the AGC speed.
    ///
    /// Command: `GTnnn;`
    ///
    /// K2 AGC codes:
    /// - 000 = Fast
    /// - 001 = Slow
    ///
    /// K3/K4 AGC codes:
    /// - 000 = Fast
    /// - 001 = Mid
    /// - 002 = Slow
    ///
    /// - Parameter speed: The desired AGC speed
    /// - Throws: `RigError` if the command fails
    public func setAGC(_ speed: AGCSpeed) async throws {
        let code: Int
        if isK2 {
            switch speed {
            case .fast, .auto:          code = 0
            case .medium, .slow, .off:  code = 1
            }
        } else {
            switch speed {
            case .fast:           code = 0
            case .medium, .auto:  code = 1
            case .slow, .off:     code = 2
            }
        }
        let command = String(format: "GT%03d", code)
        try await sendCommand(command)
        if !isK2 {
            _ = try await receiveResponse()
        } else {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    /// Gets the current AGC speed.
    ///
    /// Command: `GT;` — Response: `GTnnn;`
    ///
    /// - Returns: The current AGC speed
    /// - Throws: `RigError` if the command fails
    public func getAGC() async throws -> AGCSpeed {
        try await sendCommand("GT")
        let response = try await receiveResponse()
        // Response: GTnnn
        guard response.hasPrefix("GT"), response.count >= 5 else {
            throw RigError.invalidResponse
        }
        let start = response.index(response.startIndex, offsetBy: 2)
        let end = response.index(start, offsetBy: 3)
        guard let code = Int(response[start..<end]) else { throw RigError.invalidResponse }
        if isK2 {
            return code == 0 ? .fast : .slow
        } else {
            switch code {
            case 0:  return .fast
            case 1:  return .medium
            default: return .slow
            }
        }
    }

    // MARK: - Noise Blanker

    /// Sets the noise blanker state.
    ///
    /// Command: `NBn;` — 0 = off, 1 = on.
    ///
    /// - Parameter config: Noise blanker configuration
    /// - Throws: `RigError` if the command fails
    public func setNoiseBlanker(_ config: NoiseBlanker) async throws {
        switch config {
        case .off:
            try await sendCommand("NB0")
        case .enabled:
            try await sendCommand("NB1")
        }
        if !isK2 {
            _ = try await receiveResponse()
        } else {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    /// Gets the current noise blanker state.
    ///
    /// Command: `NB;` — Response: `NBn;`
    ///
    /// - Returns: Current noise blanker configuration
    /// - Throws: `RigError` if the command fails
    public func getNoiseBlanker() async throws -> NoiseBlanker {
        try await sendCommand("NB")
        let response = try await receiveResponse()
        // Response: NBn
        guard response.hasPrefix("NB"), response.count >= 3 else {
            throw RigError.invalidResponse
        }
        let idx = response.index(response.startIndex, offsetBy: 2)
        return response[idx] == "1" ? .enabled(level: 5) : .off
    }

    // MARK: - Noise Reduction

    /// Sets the noise reduction state.
    ///
    /// Command: `NRn;` — 0 = off, 1 = on.
    ///
    /// The K2 and K3/K4 support a single NR stage. Level values are treated as on/off.
    ///
    /// - Parameter config: Noise reduction configuration
    /// - Throws: `RigError` if the command fails
    public func setNoiseReduction(_ config: NoiseReduction) async throws {
        switch config {
        case .off:
            try await sendCommand("NR0")
        case .enabled:
            try await sendCommand("NR1")
        }
        if !isK2 {
            _ = try await receiveResponse()
        } else {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    /// Gets the current noise reduction state.
    ///
    /// Command: `NR;` — Response: `NRn;`
    ///
    /// - Returns: Current noise reduction configuration
    /// - Throws: `RigError` if the command fails
    public func getNoiseReduction() async throws -> NoiseReduction {
        try await sendCommand("NR")
        let response = try await receiveResponse()
        // Response: NRn
        guard response.hasPrefix("NR"), response.count >= 3 else {
            throw RigError.invalidResponse
        }
        let idx = response.index(response.startIndex, offsetBy: 2)
        return response[idx] == "1" ? .enabled(level: 5) : .off
    }

    // MARK: - IF Filter

    /// Sets the IF bandwidth (DSP filter).
    ///
    /// The K3/K4 support the `BW` command for IF bandwidth in 10 Hz steps (e.g. `BW0270` = 2700 Hz).
    /// The K2 uses the `FW` command. For simplicity this implementation uses three fixed
    /// filter slots mapped to common CW/SSB bandwidths:
    /// - `.filter1` → 2700 Hz (SSB wide)
    /// - `.filter2` → 2100 Hz (SSB medium)
    /// - `.filter3` → 500 Hz (CW/narrow)
    ///
    /// - Parameter filter: The desired filter slot
    /// - Throws: `RigError` if the command fails
    public func setIFFilter(_ filter: IFFilter) async throws {
        let bwHz: Int
        switch filter {
        case .filter1: bwHz = 2700
        case .filter2: bwHz = 2100
        case .filter3: bwHz = 500
        }
        if isK2 {
            // K2 uses FW (filter width) command: FWnnnn in Hz
            let command = String(format: "FW%04d", bwHz)
            try await sendCommand(command)
            try await Task.sleep(nanoseconds: k2CommandDelay)
        } else {
            // K3/K4 use BW command: BWnnnn in 10 Hz units
            let units = bwHz / 10
            let command = String(format: "BW%04d", units)
            try await sendCommand(command)
            _ = try await receiveResponse()
        }
    }

    /// Gets the current IF filter slot by reading the IF bandwidth.
    ///
    /// K3/K4: `BW;` — Response: `BWnnnn;` (10 Hz units)
    /// K2:    `FW;` — Response: `FWnnnn;` (Hz units)
    ///
    /// - Returns: The closest matching filter slot
    /// - Throws: `RigError` if the command fails
    public func getIFFilter() async throws -> IFFilter {
        let bwHz: Int
        if isK2 {
            try await sendCommand("FW")
            let response = try await receiveResponse()
            guard response.hasPrefix("FW"), response.count >= 6 else {
                throw RigError.invalidResponse
            }
            let start = response.index(response.startIndex, offsetBy: 2)
            let end = response.index(start, offsetBy: 4)
            guard let value = Int(response[start..<end]) else { throw RigError.invalidResponse }
            bwHz = value
        } else {
            try await sendCommand("BW")
            let response = try await receiveResponse()
            // Response: BWnnnn (10 Hz units)
            guard response.hasPrefix("BW"), response.count >= 6 else {
                throw RigError.invalidResponse
            }
            let start = response.index(response.startIndex, offsetBy: 2)
            let end = response.index(start, offsetBy: 4)
            guard let units = Int(response[start..<end]) else { throw RigError.invalidResponse }
            bwHz = units * 10
        }
        switch bwHz {
        case 0...999:    return .filter3   // narrow / CW
        case 1000...2399: return .filter2  // medium / SSB
        default:          return .filter1  // wide / SSB
        }
    }

    // MARK: - Power State

    /// Powers the radio on or places it in standby.
    ///
    /// Command: `PS1;` (power on) or `PS0;` (standby).
    ///
    /// - Parameter on: `true` to power on, `false` for standby
    /// - Throws: `RigError` if the command fails
    public func setPowerState(_ on: Bool) async throws {
        let command = on ? "PS1" : "PS0"
        try await sendCommand(command)
        // Radio may not respond after powering off
        if isK2 {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        } else {
            _ = try? await receiveResponse()
        }
    }

    /// Returns `true` if the radio is powered on and responding.
    ///
    /// Queries `PS;` — `PS1` means on, `PS0` or timeout means off.
    ///
    /// - Returns: `true` if responding and powered on
    public func getPowerState() async throws -> Bool {
        do {
            try await sendCommand("PS")
            let response = try await receiveResponse()
            guard response.hasPrefix("PS"), response.count >= 3 else { return false }
            let idx = response.index(response.startIndex, offsetBy: 2)
            return response[idx] == "1"
        } catch {
            return false
        }
    }

    // MARK: - Memory Channels

    /// Recalls a memory channel to the active VFO.
    ///
    /// Command: `MCnnn;` — Recalls channel nnn.
    ///
    /// - Parameter channel: The memory channel to recall
    /// - Throws: `RigError.invalidParameter` if out of range
    public func setMemoryChannel(_ channel: MemoryChannel) async throws {
        guard channel.number >= 1, channel.number <= 999 else {
            throw RigError.invalidParameter("Memory channel must be 1–999")
        }
        let command = String(format: "MC%03d", channel.number)
        try await sendCommand(command)
        if !isK2 {
            _ = try await receiveResponse()
        } else {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    /// Reads the currently selected memory channel number and populates it with
    /// the current VFO state.
    ///
    /// - Parameter number: Channel number (for range validation)
    /// - Returns: `MemoryChannel` populated with current VFO state
    /// - Throws: `RigError` if the command fails
    public func getMemoryChannel(_ number: Int) async throws -> MemoryChannel {
        try await sendCommand("MC")
        let response = try await receiveResponse()
        // Response: MCnnn
        guard response.hasPrefix("MC"), response.count >= 5 else {
            throw RigError.invalidResponse
        }
        let start = response.index(response.startIndex, offsetBy: 2)
        let end = response.index(start, offsetBy: 3)
        guard let channelNumber = Int(response[start..<end]) else { throw RigError.invalidResponse }

        let frequency = try await getFrequency(vfo: .a)
        let mode = try await getMode(vfo: .a)

        return MemoryChannel(
            number: channelNumber,
            frequency: frequency,
            mode: mode,
            name: nil
        )
    }

    /// Returns the number of available memory channels for this radio.
    ///
    /// K2 = 10 channels, K3/K3S = 100, K4 = 100, KX2/KX3 = 100.
    ///
    /// - Returns: Memory channel count
    public func getMemoryChannelCount() async throws -> Int {
        return isK2 ? 10 : 100
    }

    /// Clears a memory channel.
    ///
    /// Elecraft CAT does not provide a dedicated memory-clear command over serial.
    ///
    /// - Throws: `RigError.unsupportedOperation` always
    public func clearMemoryChannel(_ number: Int) async throws {
        throw RigError.unsupportedOperation("Memory channel clear is not supported via Elecraft CAT protocol")
    }
}
