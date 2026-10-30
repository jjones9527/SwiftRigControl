import Foundation

// MARK: - Attenuator, AGC, noise blanker, noise reduction
//
// Each follows the radio's ``KenwoodLevelProfile``, which was taken from
// the bytes Hamlib sends for the same model. Through v1.3.1 one table
// served every Kenwood: `GT%03d` 0-3 for AGC (the TS-590 wants `GT%02d`
// 0/5/10/20, the TS-890S `GC`), and `RA01`-`RA03` as 6/12/18 dB (on the
// TS-590 / TS-2000 / TS-480 `RA01` is their only step, 12 dB).
//
// Split out of KenwoodProtocol+LevelControls.swift.

extension KenwoodProtocol {

    // MARK: - Attenuator

    /// Sets the front-end attenuator.
    ///
    /// Command: `RAnn;` (`RAn;` on the TS-890S), where n is the 1-based
    /// position of `dB` in ``KenwoodLevelProfile/attenuatorSteps``; 0 is
    /// off. Matches Hamlib `kenwood_set_level` RIG_LEVEL_ATT
    /// (`kenwood.c:3560-3590`).
    ///
    /// - Parameter dB: Attenuation in dB: 0, or one of the radio's steps
    /// - Throws: `RigError.invalidParameter` for a value the radio lacks
    public func setAttenuator(_ dB: Int) async throws {
        let code: Int
        if dB == 0 {
            code = 0
        } else if let index = levelProfile.attenuatorSteps.firstIndex(of: dB) {
            code = index + 1
        } else {
            let valid = ([0] + levelProfile.attenuatorSteps).map(String.init).joined(separator: ", ")
            throw RigError.invalidParameter("Unsupported attenuator level: \(dB) dB (valid: \(valid))")
        }
        try await sendSetCommand(String(format: "RA%0\(levelProfile.attenuatorDigits)d", code))
    }

    /// Gets the current attenuator level in dB.
    ///
    /// Command: `RA;` — Response: `RAnn;` (radios may append a second
    /// field, which is ignored).
    ///
    /// - Returns: Attenuation in dB, 0 when off
    /// - Throws: `RigError` if the command fails
    public func getAttenuator() async throws -> Int {
        try await sendCommand("RA")
        let response = try await receiveResponse()
        let digits = levelProfile.attenuatorDigits
        guard response.hasPrefix("RA"),
              let code = Int(response.dropFirst(2).prefix(digits)) else {
            throw RigError.invalidResponse
        }
        guard code > 0 else { return 0 }
        guard code <= levelProfile.attenuatorSteps.count else { throw RigError.invalidResponse }
        return levelProfile.attenuatorSteps[code - 1]
    }

    // MARK: - AGC

    /// Sets the AGC speed using the radio's ``KenwoodLevelProfile/agc``.
    ///
    /// - TS-590S/SG: `GT00` / `GT05` / `GT10` / `GT20` (`ts590.c`)
    /// - TS-2000: `GT000` / `GT005` / `GT010` / `GT020`
    /// - TS-480: `GT000` / `GT001` (fast) / `GT002` (slow)
    /// - TS-890S: `GC0` off, `GC1` slow, `GC2` medium, `GC3` fast (`ts890s.c`)
    ///
    /// - Parameter speed: The desired AGC speed
    /// - Throws: `RigError.unsupportedOperation` for a speed the radio
    ///   lacks (`.auto` everywhere, `.medium` on the TS-480)
    public func setAGC(_ speed: AGCSpeed) async throws {
        switch levelProfile.agc {
        case .gt(let width, let codes):
            guard let code = codes[speed] else { throw Self.agcUnsupported(speed) }
            try await sendSetCommand(String(format: "GT%0\(width)d", code))
        case .gc(let codes):
            guard let code = codes[speed] else { throw Self.agcUnsupported(speed) }
            try await sendSetCommand("GC\(code)")
        }
    }

    /// Gets the current AGC speed.
    ///
    /// `GT` replies are mapped to the nearest listed speed at or above the
    /// value, as Hamlib `ts590_get_level` does (0 off, ≤5 fast, ≤10
    /// medium, above that slow).
    ///
    /// - Returns: The current AGC speed
    /// - Throws: `RigError` if the command fails
    public func getAGC() async throws -> AGCSpeed {
        switch levelProfile.agc {
        case .gt(_, let codes):
            try await sendCommand("GT")
            let response = try await receiveResponse()
            guard response.hasPrefix("GT"), let value = Int(response.dropFirst(2)) else {
                throw RigError.invalidResponse
            }
            let ordered = codes.sorted { $0.value < $1.value }
            return ordered.first { value <= $0.value }?.key ?? ordered.last?.key ?? .slow
        case .gc(let codes):
            try await sendCommand("GC")
            let response = try await receiveResponse()
            guard response.hasPrefix("GC"), let value = Int(response.dropFirst(2)),
                  let speed = codes.first(where: { $0.value == value })?.key else {
                throw RigError.invalidResponse
            }
            return speed
        }
    }

    private static func agcUnsupported(_ speed: AGCSpeed) -> RigError {
        .unsupportedOperation("AGC \(speed) is not available on this radio")
    }

    // MARK: - Noise Blanker

    /// Sets the noise blanker on or off.
    ///
    /// Command: `NB0;` / `NB1;`, or `NB10;` / `NB11;` on the TS-890S
    /// (``KenwoodLevelProfile/noiseBlankerPrefix``).
    ///
    /// - Parameter config: Noise blanker configuration
    /// - Throws: `RigError` if the command fails
    public func setNoiseBlanker(_ config: NoiseBlanker) async throws {
        let prefix = levelProfile.noiseBlankerPrefix
        switch config {
        case .off:
            try await sendSetCommand("\(prefix)0")
        case .enabled:
            try await sendSetCommand("\(prefix)1")
        }
    }

    /// Gets the noise blanker state.
    ///
    /// - Returns: `.off`, or `.enabled(level: nil)` (the level isn't read)
    /// - Throws: `RigError` if the command fails
    public func getNoiseBlanker() async throws -> NoiseBlanker {
        let prefix = levelProfile.noiseBlankerPrefix
        try await sendCommand(prefix)
        let response = try await receiveResponse()
        guard response.hasPrefix(prefix), let state = response.dropFirst(prefix.count).first else {
            throw RigError.invalidResponse
        }
        return state == "0" ? .off : .enabled(level: nil)
    }

    // MARK: - Noise Reduction

    /// Sets noise reduction.
    ///
    /// `.off` sends `NR0;`. `.enabled(level:)` sends `NR1;` and, on radios
    /// with a level (``KenwoodLevelProfile/noiseReductionLevelMax``), the
    /// 0–255 level scaled to `RLnn;` (TS-590 / TS-2000 / TS-480: 0–9,
    /// Hamlib `ts590.c` RIG_LEVEL_NR). Through v1.3.1 a level above 5
    /// selected `NR2`, which is a different NR mode, not a stronger level.
    ///
    /// - Parameter config: Noise reduction configuration
    /// - Throws: `RigError` if the command fails
    public func setNoiseReduction(_ config: NoiseReduction) async throws {
        switch config {
        case .off:
            try await sendSetCommand("NR0")
        case .enabled(let level):
            try await sendSetCommand("NR1")
            if let maximum = levelProfile.noiseReductionLevelMax {
                let clamped = min(max(level, 0), 255)
                try await sendSetCommand(String(format: "RL%02d", (clamped * maximum + 127) / 255))
            }
        }
    }

    /// Gets noise reduction.
    ///
    /// Sends `NR;` and, when NR is on and the radio has a level, `RL;`.
    ///
    /// - Returns: `.off`, or `.enabled(level:)` on the 0–255 scale
    ///   (mid-scale when the radio has no level)
    /// - Throws: `RigError` if the command fails
    public func getNoiseReduction() async throws -> NoiseReduction {
        try await sendCommand("NR")
        let response = try await receiveResponse()
        guard response.hasPrefix("NR"), let state = response.dropFirst(2).first else {
            throw RigError.invalidResponse
        }
        guard state != "0" else { return .off }
        guard let maximum = levelProfile.noiseReductionLevelMax, maximum > 0 else {
            return .enabled(level: 128)
        }
        try await sendCommand("RL")
        let reply = try await receiveResponse()
        guard reply.hasPrefix("RL"), let wire = Int(reply.dropFirst(2)) else {
            throw RigError.invalidResponse
        }
        return .enabled(level: (min(max(wire, 0), maximum) * 255 + maximum / 2) / maximum)
    }
}
