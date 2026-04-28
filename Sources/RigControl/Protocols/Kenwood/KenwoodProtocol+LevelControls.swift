import Foundation

// MARK: - AF Gain, RF Gain, Squelch, Preamp, Attenuator, AGC, DSP, Power State, Memory

/// Level controls, DSP settings, power state, and memory operations for Kenwood CAT radios.
///
/// ## Command Reference (Kenwood CAT)
/// - `AG0nnn` — Set AF gain (000–255); `AG0` — Get AF gain
/// - `RGnnn` — Set RF gain (000–255); `RG` — Get RF gain
/// - `SQ0nnn` — Set squelch (000–255); `SQ0` — Get squelch
/// - `PAn` — Set preamp (0=off, 1=on); `PA` — Get preamp
/// - `RAnn` — Set attenuator (00=off, 01=6dB, 02=12dB, 03=18dB); `RA` — Get
/// - `GTnnn` — Set AGC (000=fast, 001=mid, 002=slow); `GT` — Get AGC
/// - `NBn` — Set noise blanker (0=off, 1=on); `NB` — Get
/// - `NRn` — Set noise reduction (0=off, 1=NR1); `NR` — Get
/// - `SHnnn`/`SLnnn` — Set DSP high/low cut; `SH`/`SL` — Get
/// - `PS1`/`PS0` — Power on/standby; `PS` — Get power state
/// - `MCnnn` — Recall memory channel; `MW` — Write memory
extension KenwoodProtocol {

    // MARK: - AF Gain

    /// Sets the AF (audio) output gain.
    ///
    /// Command: `AG0nnn;` where nnn is 000–255.
    ///
    /// - Parameter level: Gain level 0–255
    /// - Throws: `RigError` if the command fails
    public func setAFGain(_ level: Int) async throws {
        let clamped = min(max(level, 0), 255)
        let command = String(format: "AG0%03d", clamped)
        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    /// Gets the current AF gain.
    ///
    /// Command: `AG0;` — Response: `AG0nnn;`
    ///
    /// - Returns: Gain level 0–255
    /// - Throws: `RigError` if the command fails
    public func getAFGain() async throws -> Int {
        try await sendCommand("AG0")
        let response = try await receiveResponse()
        // Response: AG0nnn
        guard response.hasPrefix("AG0"), response.count >= 6 else {
            throw RigError.invalidResponse
        }
        let start = response.index(response.startIndex, offsetBy: 3)
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
        _ = try await receiveResponse()
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
    /// Command: `SQ0nnn;` where nnn is 000–255.
    ///
    /// - Parameter level: Squelch threshold 0 (open) – 255 (closed)
    /// - Throws: `RigError` if the command fails
    public func setSquelch(_ level: Int) async throws {
        let clamped = min(max(level, 0), 255)
        let command = String(format: "SQ0%03d", clamped)
        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    /// Gets the current squelch level.
    ///
    /// Command: `SQ0;` — Response: `SQ0nnn;`
    ///
    /// - Returns: Squelch level 0–255
    /// - Throws: `RigError` if the command fails
    public func getSquelch() async throws -> Int {
        try await sendCommand("SQ0")
        let response = try await receiveResponse()
        // Response: SQ0nnn
        guard response.hasPrefix("SQ0"), response.count >= 6 else {
            throw RigError.invalidResponse
        }
        let start = response.index(response.startIndex, offsetBy: 3)
        let end = response.index(start, offsetBy: 3)
        guard let value = Int(response[start..<end]) else { throw RigError.invalidResponse }
        return value
    }

    // MARK: - Preamp

    /// Sets the preamplifier state.
    ///
    /// Command: `PAn;` — Kenwood preamp coding:
    /// - 0 = off
    /// - 1 = Preamp on
    ///
    /// Kenwood's standard CAT `PA` command is single-stage. Level 2 is treated as
    /// level 1 for radios that only have one preamp stage.
    ///
    /// - Parameter level: 0 = off, 1 or 2 = on
    /// - Throws: `RigError.invalidParameter` for out-of-range values
    public func setPreamp(_ level: Int) async throws {
        guard (0...2).contains(level) else {
            throw RigError.invalidParameter("Preamp level must be 0 (off) or 1/2 (on)")
        }
        // Kenwood PA command: 0=off, 1=on (no multi-stage on most models)
        let code = level > 0 ? 1 : 0
        let command = "PA\(code)"
        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    /// Gets the current preamplifier state.
    ///
    /// Command: `PA;` — Response: `PAn;`
    ///
    /// - Returns: 0 = off, 1 = on
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
    /// Command: `RAnn;` — Kenwood attenuator step codes:
    /// - 00 = off
    /// - 01 = 6 dB
    /// - 02 = 12 dB
    /// - 03 = 18 dB (where supported)
    ///
    /// Available steps vary by model.
    ///
    /// - Parameter dB: Attenuation in dB — 0, 6, 12, or 18
    /// - Throws: `RigError.invalidParameter` for unsupported values
    public func setAttenuator(_ dB: Int) async throws {
        let code: Int
        switch dB {
        case 0:  code = 0
        case 6:  code = 1
        case 12: code = 2
        case 18: code = 3
        default: throw RigError.invalidParameter("Unsupported attenuator level: \(dB) dB (valid: 0, 6, 12, 18)")
        }
        let command = String(format: "RA%02d", code)
        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    /// Gets the current attenuator level in dB.
    ///
    /// Command: `RA;` — Response: `RAnn;`
    ///
    /// - Returns: Attenuation in dB (0, 6, 12, or 18)
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
        case 0: return 0
        case 1: return 6
        case 2: return 12
        case 3: return 18
        default: return 0
        }
    }

    // MARK: - AGC

    /// Sets the AGC speed.
    ///
    /// Command: `GTnnn;` — Kenwood AGC speed codes:
    /// - 000 = Off (manual gain — not available on all models)
    /// - 001 = Fast
    /// - 002 = Mid (medium)
    /// - 003 = Slow
    ///
    /// - Parameter speed: The desired AGC speed
    /// - Throws: `RigError` if the command fails
    public func setAGC(_ speed: AGCSpeed) async throws {
        let code: Int
        switch speed {
        case .off:    code = 0
        case .fast:   code = 1
        case .medium: code = 2
        case .slow:   code = 3
        case .auto:   code = 2  // Map auto → mid as closest equivalent
        }
        let command = String(format: "GT%03d", code)
        try await sendCommand(command)
        _ = try await receiveResponse()
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
        switch code {
        case 0:  return .off
        case 1:  return .fast
        case 2:  return .medium
        default: return .slow
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
        _ = try await receiveResponse()
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
    /// Command: `NRn;` — 0 = off, 1 = NR1, 2 = NR2 (where supported).
    ///
    /// - Parameter config: Noise reduction configuration; `enabled(level:)` maps
    ///   level ≤ 5 → NR1, level > 5 → NR2 on models that support it.
    /// - Throws: `RigError` if the command fails
    public func setNoiseReduction(_ config: NoiseReduction) async throws {
        switch config {
        case .off:
            try await sendCommand("NR0")
            _ = try await receiveResponse()
        case .enabled(let level):
            let code = level > 5 ? 2 : 1
            try await sendCommand("NR\(code)")
            _ = try await receiveResponse()
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
        switch response[idx] {
        case "0": return .off
        case "1": return .enabled(level: 3)   // NR1 — mid-scale
        case "2": return .enabled(level: 8)   // NR2 — upper-scale
        default:  return .off
        }
    }

    // MARK: - IF Filter

    /// Sets the IF filter (DSP passband width).
    ///
    /// Kenwood radios expose filter selection via the `SH` (DSP high-cut) command.
    /// This maps the three standard filter slots to typical Kenwood SH values:
    /// - `.filter1` → SH07 (wide, ~2.7 kHz)
    /// - `.filter2` → SH05 (medium, ~2.4 kHz)
    /// - `.filter3` → SH02 (narrow, ~1.8 kHz)
    ///
    /// - Parameter filter: The desired IF filter slot
    /// - Throws: `RigError` if the command fails
    public func setIFFilter(_ filter: IFFilter) async throws {
        let highCut: Int
        switch filter {
        case .filter1: highCut = 7
        case .filter2: highCut = 5
        case .filter3: highCut = 2
        }
        let command = String(format: "SH%02d", highCut)
        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    /// Gets the current IF filter by reading the DSP high-cut setting.
    ///
    /// Command: `SH;` — Response: `SHnn;`
    ///
    /// - Returns: The closest matching filter slot
    /// - Throws: `RigError` if the command fails
    public func getIFFilter() async throws -> IFFilter {
        try await sendCommand("SH")
        let response = try await receiveResponse()
        // Response: SHnn
        guard response.hasPrefix("SH"), response.count >= 4 else {
            throw RigError.invalidResponse
        }
        let start = response.index(response.startIndex, offsetBy: 2)
        let end = response.index(start, offsetBy: 2)
        guard let code = Int(response[start..<end]) else { throw RigError.invalidResponse }
        switch code {
        case 0...3: return .filter3
        case 4...6: return .filter2
        default:    return .filter1
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
        _ = try? await receiveResponse()
    }

    /// Returns `true` if the radio is powered on and responding.
    ///
    /// Queries power status via `PS;`. A successful `PS1` response means on;
    /// timeout or `PS0` means off or in standby.
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
    /// Command: `MCnnn;` — Recalls channel nnn (001–999, model-dependent range).
    ///
    /// - Parameter channel: The memory channel to recall
    /// - Throws: `RigError.invalidParameter` if out of range
    public func setMemoryChannel(_ channel: MemoryChannel) async throws {
        guard channel.number >= 1, channel.number <= 999 else {
            throw RigError.invalidParameter("Memory channel must be 1–999")
        }
        let command = String(format: "MC%03d", channel.number)
        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    /// Reads the currently recalled memory channel.
    ///
    /// Command: `MC;` — Response: `MCnnn;`
    ///
    /// Kenwood CAT does not expose full channel memory contents over the `MC` command.
    /// This reads the active channel number and queries the current VFO state to populate
    /// the channel record.
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

    /// Returns the number of available memory channels.
    ///
    /// Kenwood radios typically have 100–300 memory channels depending on model.
    ///
    /// - Returns: 100 (conservative default for all supported Kenwood models)
    public func getMemoryChannelCount() async throws -> Int {
        return 100
    }

    /// Clears a memory channel.
    ///
    /// Kenwood CAT does not provide a direct memory-clear command.
    ///
    /// - Throws: `RigError.unsupportedOperation` always
    public func clearMemoryChannel(_ number: Int) async throws {
        throw RigError.unsupportedOperation("Memory channel clear is not supported via Kenwood CAT protocol")
    }
}
