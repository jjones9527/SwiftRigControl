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
    /// The API level is 0–255 on every radio; it is scaled to the
    /// radio's wire range (``YaesuCATProtocol/Quirks/rfGainMax``, 0–30
    /// on the FT-891) the way Hamlib scales by its `level_gran` step.
    ///
    /// - Parameter level: Gain level 0–255
    /// - Throws: `RigError` if the command fails
    public func setRFGain(_ level: Int) async throws {
        let wire = Self.scale(level, from: 255, to: quirks.rfGainMax)
        let command = String(format: "RG0%03d", wire)
        try await sendSetCommand(command)
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
        return Self.scale(value, from: quirks.rfGainMax, to: 255)
    }

    // MARK: - Squelch

    /// Sets the squelch level.
    ///
    /// Command: `SQ0nnn;`. The API level is 0–255; the wire level is
    /// 0–``YaesuCATProtocol/Quirks/squelchMax`` (100 on the FT-991/991A,
    /// FT-891, FT-710, FTDX-10, FTDX-101D/MP), as Hamlib
    /// `newcat_set_level` RIG_LEVEL_SQL scales by the model's step.
    ///
    /// - Parameter level: Squelch threshold 0 (open) – 255 (closed)
    /// - Throws: `RigError` if the command fails
    public func setSquelch(_ level: Int) async throws {
        let wire = Self.scale(level, from: 255, to: quirks.squelchMax)
        let command = String(format: "SQ0%03d", wire)
        try await sendSetCommand(command)
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
        return Self.scale(value, from: quirks.squelchMax, to: 255)
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
        try await sendSetCommand(command)
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
    /// Command: `RA0n;`, where n is the 1-based position of `dB` in this
    /// radio's ``YaesuCATProtocol/Quirks/attenuatorSteps``; `RA00;` is
    /// off. Hamlib does the same with the model's `.attenuator` caps list
    /// (`newcat_set_level` RIG_LEVEL_ATT, `newcat.c:4492-4533`): 12 dB is
    /// `RA02` on an FT-710 (6/12/18) but `RA01` on an FT-991A.
    ///
    /// - Parameter dB: Attenuation in dB: 0, or one of the radio's steps
    /// - Throws: `RigError.invalidParameter` for a value the radio lacks
    public func setAttenuator(_ dB: Int) async throws {
        let code: Int
        if dB == 0 {
            code = 0
        } else if let index = quirks.attenuatorSteps.firstIndex(of: dB) {
            code = index + 1
        } else {
            let valid = ([0] + quirks.attenuatorSteps).map(String.init).joined(separator: ", ")
            throw RigError.invalidParameter("Unsupported attenuator level: \(dB) dB (valid: \(valid))")
        }
        try await sendSetCommand("RA0\(code)")
    }

    /// Gets the current attenuator level in dB.
    ///
    /// Command: `RA0;` — Response: `RA0n;`. Through v1.3.1 this sent
    /// `RA;`, which newcat radios reject; Hamlib always sends `RA0;`
    /// (`newcat_get_level`, `newcat.c:5189-5203`).
    ///
    /// - Returns: Attenuation in dB, 0 when off
    /// - Throws: `RigError` if the command fails
    public func getAttenuator() async throws -> Int {
        try await sendCommand("RA0")
        let response = try await receiveResponse()
        let chars = Array(response)
        guard response.hasPrefix("RA"), chars.count >= 4,
              let code = chars[3].wholeNumberValue else {
            throw RigError.invalidResponse
        }
        guard code > 0 else { return 0 }
        guard code <= quirks.attenuatorSteps.count else { throw RigError.invalidResponse }
        return quirks.attenuatorSteps[code - 1]
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
        try await sendSetCommand(command)
    }

    /// Gets the current AGC speed.
    ///
    /// Command: `GT0;` — Response: `GT0n;`. Through v1.3.1 this sent
    /// `GT;`, which newcat radios reject; Hamlib sends `GT%c` with the
    /// receiver digit (`newcat_get_level`, `newcat.c:5061-5075`).
    ///
    /// - Returns: The current AGC speed
    /// - Throws: `RigError` if the command fails
    public func getAGC() async throws -> AGCSpeed {
        try await sendCommand("GT0")
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

    // MARK: - Power State

    /// Powers the radio on or places it in standby.
    ///
    /// Command: `PS1;` (power on) or `PS0;` (standby / power off).
    ///
    /// Power-on sends `PS1;` twice 1.2 s apart (the first only wakes the
    /// radio) and then polls `FA;` for up to about 10 s, so it returns once
    /// the radio is answering. Not all radios support remote power-on via CAT.
    ///
    /// - Parameter on: `true` to power on, `false` for standby
    /// - Throws: `RigError.timeout` if the radio doesn't answer after
    ///   power-on; other `RigError`s if the write fails
    public func setPowerState(_ on: Bool) async throws {
        // Hamlib `newcat_set_powerstat` (newcat.c:3719-3800). Pre-v1.2.19
        // this wrote PS once and waited out a reply that never comes.
        guard on else {
            // Power off: write PS0; and read nothing (newcat.c:3763-3767).
            try await sendCommand("PS0")
            return
        }

        // Power on: the first PS1; only wakes the CAT processor, so send it
        // again after 1.2 s, then poll FA until the radio answers.
        // Divergence: Hamlib also closes and reopens the port on
        // everything but the FT-991 because some radios reset their USB
        // serial port while powering up; reopening is left to the caller.
        try await sendCommand("PS1")
        try await Task.sleep(nanoseconds: Self.powerOnWakeDelay)
        try await sendCommand("PS1")
        for _ in 0..<Self.powerOnPollAttempts {
            try await Task.sleep(nanoseconds: Self.powerOnPollInterval)
            try await transport.flush()
            if (try? await getFrequency(vfo: .a)) != nil {
                return
            }
        }
        throw RigError.timeout
    }

    /// Delay between the wake-up `PS1;` and the real one (Hamlib 1.2 s).
    static let powerOnWakeDelay: UInt64 = 1_200_000_000
    /// Wait between `FA;` polls after power-on (Hamlib 1 s).
    static let powerOnPollInterval: UInt64 = 1_000_000_000
    /// `FA;` polls before giving up, about 10 s with timeouts (Hamlib 8).
    static let powerOnPollAttempts = 8

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
        try await sendSetCommand(command)
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

    /// Rescales a level between two full-scale ranges with rounding,
    /// clamping the input to `0...from`. Mirrors Hamlib's `val / step + 0.5`.
    static func scale(_ value: Int, from: Int, to: Int) -> Int {
        guard from > 0, to > 0 else { return 0 }
        let clamped = min(max(value, 0), from)
        return (clamped * to + from / 2) / from
    }
}
