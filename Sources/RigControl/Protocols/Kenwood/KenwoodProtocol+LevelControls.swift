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
        try await sendSetCommand(command)
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
    /// Command: `RGnnn;`, the 0–255 level scaled to
    /// ``KenwoodLevelProfile/rfGainMax`` (0–100 on the TS-480, Hamlib
    /// `ts480.c`).
    ///
    /// - Parameter level: Gain level 0–255
    /// - Throws: `RigError` if the command fails
    public func setRFGain(_ level: Int) async throws {
        let clamped = min(max(level, 0), 255)
        let maximum = levelProfile.rfGainMax
        let command = String(format: "RG%03d", (clamped * maximum + 127) / 255)
        try await sendSetCommand(command)
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
        let maximum = levelProfile.rfGainMax
        return (min(max(value, 0), maximum) * 255 + maximum / 2) / maximum
    }

    // MARK: - Squelch

    /// Sets the squelch level.
    ///
    /// Command: `SQ0nnn;`, or `SQnnn;` on the TS-890S
    /// (``KenwoodLevelProfile/squelchHasReceiverDigit``, Hamlib
    /// `ts890s.c:92-93`).
    ///
    /// - Parameter level: Squelch threshold 0 (open) – 255 (closed)
    /// - Throws: `RigError` if the command fails
    public func setSquelch(_ level: Int) async throws {
        let clamped = min(max(level, 0), 255)
        let prefix = levelProfile.squelchHasReceiverDigit ? "SQ0" : "SQ"
        try await sendSetCommand(prefix + String(format: "%03d", clamped))
    }

    /// Gets the current squelch level.
    ///
    /// Command: `SQ0;` — Response: `SQ0nnn;`
    ///
    /// - Returns: Squelch level 0–255
    /// - Throws: `RigError` if the command fails
    public func getSquelch() async throws -> Int {
        let prefix = levelProfile.squelchHasReceiverDigit ? "SQ0" : "SQ"
        try await sendCommand(prefix)
        let response = try await receiveResponse()
        guard response.hasPrefix(prefix),
              let value = Int(response.dropFirst(prefix.count).prefix(3)) else {
            throw RigError.invalidResponse
        }
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
        try await sendSetCommand(command)
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
        try await sendSetCommand(command)
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
        try await sendSetCommand(command)
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
