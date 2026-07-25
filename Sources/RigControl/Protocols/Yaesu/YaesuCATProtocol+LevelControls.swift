import Foundation

// MARK: - AF Gain, RF Gain, Squelch, Preamp, Attenuator, AGC, DSP, Power State, Memory

/// Level controls, DSP settings, power state, and memory operations for Yaesu CAT radios.
///
/// ## Command Reference (Yaesu CAT)
/// - `AG0nnn` — Set AF gain (000–255)
/// - `AG0` — Get AF gain
/// - `RGnnn` — Set RF gain (000–255)
/// - `RG` — Get RF gain
/// - `SQ0nnn` — Set squelch (000–255)
/// - `SQ0` — Get squelch
/// - `PA0n` — Set preamp (0=off, 1=on, 2=IPO/bypass depending on model)
/// - `PA0` — Get preamp state
/// - `RAnn` — Set attenuator (00=off, 01=6dB, 02=12dB, 03=18dB)
/// - `RA` — Get attenuator
/// - `GTnnn` — Set AGC speed (000=fast, 001=mid, 002=slow, 003=off)
/// - `GT` — Get AGC speed
/// - `NBn` — Set noise blanker (0=off, 1=on)
/// - `NB` — Get noise blanker state
/// - `NRn` — Set noise reduction (0=off, 1=NR1, 2=NR2)
/// - `NR` — Get noise reduction state
/// - `SHnnn` — Set IF width/DSP high cut (filter selection)
/// - `SLnnn` — Set IF width/DSP low cut (filter selection)
/// - `SH` / `SL` — Get filter settings
/// - `PS` — Get/set power state (PS1 = on)
/// - `MCnnn` — Recall memory channel
/// - `MT` / `MW` — Memory transfer/write
extension YaesuCATProtocol {

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

    /// Sets the RF gain on the main receiver.
    ///
    /// Command: `RG0nnn;` — VFO qualifier `0` for main, `1` for sub.
    /// Per Hamlib `rigs/yaesu/newcat.c` line 4477:
    /// `SNPRINTF(..., "RG%c%03d%c", main_sub_vfo, fpf, cat_term)`.
    ///
    /// Prior to the v1.2.0 audit fix Swift emitted `RG%03d;` without
    /// the VFO qualifier byte — real newcat radios reject the
    /// unqualified form.
    ///
    /// - Parameter level: Gain level 0–255
    /// - Throws: `RigError` if the command fails
    public func setRFGain(_ level: Int) async throws {
        let clamped = min(max(level, 0), 255)
        let command = String(format: "RG0%03d", clamped)
        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    /// Gets the current RF gain on the main receiver.
    ///
    /// Command: `RG0;` — Response: `RG0nnn;` (VFO qualifier + 3
    /// digits). Per Hamlib newcat.c `RG%c%c` query pattern.
    ///
    /// - Returns: Gain level 0–255
    /// - Throws: `RigError` if the command fails
    public func getRFGain() async throws -> Int {
        try await sendCommand("RG0")
        let response = try await receiveResponse()
        // Response: RG0nnn (prefix + VFO byte + 3-digit level).
        guard response.hasPrefix("RG"), response.count >= 6 else {
            throw RigError.invalidResponse
        }
        let start = response.index(response.startIndex, offsetBy: 3)
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

    /// Sets the preamplifier stage.
    ///
    /// Command: `PA0n;` — Yaesu preamp coding:
    /// - 0 = IPO (front-end bypass / off)
    /// - 1 = Preamp 1 (AMP1)
    /// - 2 = Preamp 2 (AMP2, where supported)
    ///
    /// Not all models have AMP2; if the radio rejects level 2 it throws `commandFailed`.
    ///
    /// - Parameter level: 0 = off/IPO, 1 = AMP1, 2 = AMP2
    /// - Throws: `RigError.invalidParameter` for out-of-range values
    public func setPreamp(_ level: Int) async throws {
        guard (0...2).contains(level) else {
            throw RigError.invalidParameter("Preamp level must be 0 (IPO), 1 (AMP1), or 2 (AMP2)")
        }
        let command = "PA0\(level)"
        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    /// Gets the current preamplifier stage.
    ///
    /// Command: `PA0;` — Response: `PA0n;`
    ///
    /// - Returns: 0 = off/IPO, 1 = AMP1, 2 = AMP2
    /// - Throws: `RigError` if the command fails
    public func getPreamp() async throws -> Int {
        try await sendCommand("PA0")
        let response = try await receiveResponse()
        // Response: PA0n
        guard response.hasPrefix("PA0"), response.count >= 4 else {
            throw RigError.invalidResponse
        }
        let idx = response.index(response.startIndex, offsetBy: 3)
        guard let value = Int(String(response[idx])) else { throw RigError.invalidResponse }
        return value
    }

    // MARK: - Attenuator

    /// Sets the front-end attenuator.
    ///
    /// Command: `RAnn;` — Yaesu attenuator step codes:
    /// - 00 = off
    /// - 01 = 6 dB
    /// - 02 = 12 dB
    /// - 03 = 18 dB
    ///
    /// Available steps are model-dependent. Some radios only support 0 and 1.
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
    /// Command: `GTnn;` — Yaesu AGC speed codes per Hamlib
    /// `rigs/yaesu/newcat.c` lines 4142-4158:
    /// - 00 = Off
    /// - 01 = Fast
    /// - 02 = Medium
    /// - 03 = Slow
    /// - 04 = Auto
    ///
    /// Prior to the v1.2.0 audit fix Swift emitted `GT000` through
    /// `GT003` (3-digit codes with a different mapping — Fast=0,
    /// Medium=1, Slow=2, Auto=3). Neither the width nor the mapping
    /// matched Hamlib; real newcat radios would reject the command.
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
        case .auto:   code = 4
        }
        let command = String(format: "GT%02d", code)
        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    /// Gets the current AGC speed.
    ///
    /// Command: `GT;` — Response: `GTnn;` (2-digit code per Hamlib).
    ///
    /// - Returns: The current AGC speed
    /// - Throws: `RigError` if the command fails
    public func getAGC() async throws -> AGCSpeed {
        try await sendCommand("GT")
        let response = try await receiveResponse()
        // Response: GTnn
        guard response.hasPrefix("GT"), response.count >= 4 else {
            throw RigError.invalidResponse
        }
        let start = response.index(response.startIndex, offsetBy: 2)
        let end = response.index(start, offsetBy: 2)
        guard let code = Int(response[start..<end]) else { throw RigError.invalidResponse }
        switch code {
        case 0: return .off
        case 1: return .fast
        case 2: return .medium
        case 3: return .slow
        default: return .auto
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
    /// NR2 availability is model-dependent. Radios without NR2 treat level 2 as NR1.
    ///
    /// - Parameter config: Noise reduction configuration; `enabled(level:)` maps
    ///   level ≤ 5 → NR1, level > 5 → NR2.
    /// - Throws: `RigError` if the command fails
    public func setNoiseReduction(_ config: NoiseReduction) async throws {
        switch config {
        case .off:
            try await sendCommand("NR0")
            _ = try await receiveResponse()
        case .enabled(let level):
            // Map level 0–5 → NR1, 6–10 → NR2
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
        case "1": return .enabled(level: 3)   // NR1 — mid-scale level
        case "2": return .enabled(level: 8)   // NR2 — upper-scale level
        default:  return .off
        }
    }

    // MARK: - IF Filter

    /// Sets the IF filter (DSP passband width).
    ///
    /// Per Hamlib `rigs/yaesu/newcat.c` lines 9205-9218, the exact
    /// `SH` command format varies per radio:
    ///
    /// - FTX-1 / FT-DX10 / FT-710: `SH00%02d;`
    /// - FT-2000 / FT-DX3000: `SH0%02d;`
    /// - FT-DX101D/MP / FT-891: `SH%c%d%02d;` (VFO + narrow flag)
    /// - Others: `SH%c%02d;` (VFO qualifier)
    ///
    /// This implementation emits `SH0%02d;` — the common VFO-0 form
    /// that works on the largest set of modern newcat radios
    /// (FT-2000, FT-DX3000, FT-DX5000, FT-950, FT-991/A, and every
    /// radio that accepts the qualifier). Prior to the v1.2.0 audit
    /// fix Swift emitted `SH%02d;` without the qualifier — real
    /// newcat radios reject the unqualified form.
    ///
    /// **Known limitations, tracked for v1.2.1:**
    /// - FTX-1 / FT-DX10 / FT-710 want `SH00%02d;` (two-zero prefix).
    ///   The single-zero form above works on the FTX-1 per informal
    ///   reports but the correct wire is documented as double-zero.
    ///   A `Quirks.filterCommandStyle` enum will be added in a
    ///   follow-up to route each family to its exact Hamlib format.
    /// - FT-DX101 / FT-891 add a narrow-flag byte that this impl
    ///   doesn't send. Same follow-up.
    ///
    /// Filter slot mapping:
    /// - `.filter1` → high-cut 7 (wide)
    /// - `.filter2` → high-cut 5 (medium)
    /// - `.filter3` → high-cut 2 (narrow)
    ///
    /// - Parameter filter: The desired IF filter slot
    /// - Throws: `RigError` if the command fails
    public func setIFFilter(_ filter: IFFilter) async throws {
        let highCut: Int
        switch filter {
        case .filter1: highCut = 7   // wide
        case .filter2: highCut = 5   // medium
        case .filter3: highCut = 2   // narrow
        }
        let command = String(format: "SH0%02d", highCut)
        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    /// Gets the current IF filter by reading the DSP high-cut setting.
    ///
    /// Command: `SH0;` — Response: `SH0nn;` (VFO qualifier + 2-digit
    /// high-cut code). See ``setIFFilter(_:)`` for the format
    /// variants across radio families.
    ///
    /// - Returns: The closest matching filter slot
    /// - Throws: `RigError` if the command fails
    public func getIFFilter() async throws -> IFFilter {
        try await sendCommand("SH0")
        let response = try await receiveResponse()
        // Response: SH0nn (prefix + VFO byte + 2-digit high-cut).
        guard response.hasPrefix("SH"), response.count >= 5 else {
            throw RigError.invalidResponse
        }
        let start = response.index(response.startIndex, offsetBy: 3)
        let end = response.index(start, offsetBy: 2)
        guard let code = Int(response[start..<end]) else { throw RigError.invalidResponse }
        // Map SH code back to filter slot
        switch code {
        case 0...3: return .filter3   // narrow
        case 4...6: return .filter2   // medium
        default:    return .filter1   // wide
        }
    }

    // MARK: - Power State

    /// Powers the radio on or places it in standby.
    ///
    /// Command: `PS1;` (power on) or `PS0;` (standby / power off).
    ///
    /// Not all radios support remote power-on via CAT — power-on typically requires
    /// physical interaction or a dedicated wake signal on some models.
    ///
    /// - Parameter on: `true` to power on, `false` for standby
    /// - Throws: `RigError` if the command fails
    public func setPowerState(_ on: Bool) async throws {
        let command = on ? "PS1" : "PS0"
        try await sendCommand(command)
        // Radio may not respond after powering off — ignore response errors
        _ = try? await receiveResponse()
    }

    /// Returns `true` if the radio is powered on and responding.
    ///
    /// Queries power status via `PS;`. A successful response means on; a
    /// timeout means off or in standby.
    ///
    /// - Returns: `true` if responding and powered on
    /// - Throws: `RigError.notConnected` if the transport is not open
    public func getPowerState() async throws -> Bool {
        do {
            try await sendCommand("PS")
            let response = try await receiveResponse()
            // Response: PSn (1 = on, 0 = standby)
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
    /// - Parameter channel: Memory channel to store (channel number
    ///   determines the slot; 1–999, model-dependent range).
    /// - Throws: `RigError.invalidParameter` if out of range
    public func setMemoryChannel(_ channel: MemoryChannel) async throws {
        guard channel.number >= 1, channel.number <= 999 else {
            throw RigError.invalidParameter("Memory channel must be 1–999")
        }
        let command = String(format: "MC%03d", channel.number)
        try await sendCommand(command)
        _ = try await receiveResponse()
    }

    /// Reads the currently selected memory channel number.
    ///
    /// Command: `MC;` — Response: `MCnnn;`
    ///
    /// Note: Yaesu CAT does not support reading full memory channel contents over CAT
    /// on most models. This returns the channel number with the current VFO frequency
    /// and mode as the channel data.
    ///
    /// - Parameter number: The channel number to read (used for validation only)
    /// - Returns: `MemoryChannel` with current VFO state at the given channel number
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

        // Read the current frequency and mode to populate the channel record
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
    /// - Returns: Memory channel count from capabilities, or 100 as a safe default
    public func getMemoryChannelCount() async throws -> Int {
        // Yaesu radios typically have 99–500 channels depending on model
        return 100
    }

    /// Clears (overwrites) a memory channel by writing the current VFO state to it.
    ///
    /// Yaesu CAT does not have a dedicated memory-clear command. The standard approach
    /// is to write a blank frequency (0) to the channel — not all models support this.
    ///
    /// - Parameter number: Memory channel number to clear
    /// - Throws: `RigError.unsupportedOperation` as direct clear is not supported over CAT
    public func clearMemoryChannel(_ number: Int) async throws {
        throw RigError.unsupportedOperation("Memory channel clear is not supported via Yaesu CAT protocol")
    }
}
