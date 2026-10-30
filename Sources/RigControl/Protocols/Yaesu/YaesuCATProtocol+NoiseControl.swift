import Foundation

// MARK: - Noise blanker and noise reduction
//
// Newcat puts the receiver digit first in both commands, as Hamlib's
// newcat_set_func / newcat_get_func do for every model (newcat.c:6258-6330,
// 6646-6680):
//
//   NB0n;   set noise blanker, n = 0 off / 1 on        NB0;  read -> NB0n;
//   NR0n;   set noise reduction, n = 0 off / 1 on      NR0;  read -> NR0n;
//   RL0nn;  noise-reduction level, 1-15 (1-11 FT-450)  RL0;  read -> RL0nn;
//
// Through v1.3.1 the blanker sent `NB0;` / `NB1;` and NR sent `NR0;`,
// `NR1;`, `NR2;`. `NB0;` and `NR0;` are reads, so "off" never turned
// anything off, and the "on" forms aren't valid set commands.
//
// Split out of YaesuCATProtocol+LevelControls.swift, which was over the
// 500-line cap.

extension YaesuCATProtocol {

    // MARK: - Noise Blanker

    /// Sets the noise blanker on or off.
    ///
    /// Command: `NB00;` (off) or `NB01;` (on). The blanker level is not
    /// set; Hamlib does that separately with `NL` (RIG_LEVEL_NB).
    ///
    /// - Parameter config: Noise blanker configuration
    /// - Throws: `RigError` if the command fails
    public func setNoiseBlanker(_ config: NoiseBlanker) async throws {
        switch config {
        case .off:
            try await sendSetCommand("NB00")
        case .enabled:
            try await sendSetCommand("NB01")
        }
    }

    /// Gets the noise blanker state.
    ///
    /// Command: `NB0;` — Response: `NB0n;`.
    ///
    /// - Returns: `.off`, or `.enabled(level: nil)` (the level isn't read)
    /// - Throws: `RigError` if the command fails
    public func getNoiseBlanker() async throws -> NoiseBlanker {
        try await sendCommand("NB0")
        let response = try await receiveResponse()
        return try Self.parseOnOff(response, prefix: "NB0") ? .enabled(level: nil) : .off
    }

    // MARK: - Noise Reduction

    /// Sets noise reduction.
    ///
    /// `.off` sends `NR00;`. `.enabled(level:)` sends `NR01;` then
    /// `RL0nn;`, with the 0–255 API level scaled to the radio's
    /// 1–``YaesuCATProtocol/Quirks/noiseReductionLevelMax`` (Hamlib
    /// `newcat_set_level` RIG_LEVEL_NR, `newcat.c:4549-4590`).
    ///
    /// - Parameter config: Noise reduction configuration
    /// - Throws: `RigError` if the command fails
    public func setNoiseReduction(_ config: NoiseReduction) async throws {
        switch config {
        case .off:
            try await sendSetCommand("NR00")
        case .enabled(let level):
            try await sendSetCommand("NR01")
            let wire = max(1, Self.scale(level, from: 255, to: quirks.noiseReductionLevelMax))
            try await sendSetCommand(String(format: "RL0%02d", wire))
        }
    }

    /// Gets noise reduction.
    ///
    /// Sends `NR0;` and, when NR is on, `RL0;` for the level, scaled back
    /// to 0–255.
    ///
    /// - Returns: `.off`, or `.enabled(level:)` with the 0–255 level
    /// - Throws: `RigError` if the command fails
    public func getNoiseReduction() async throws -> NoiseReduction {
        try await sendCommand("NR0")
        let state = try await receiveResponse()
        guard try Self.parseOnOff(state, prefix: "NR0") else { return .off }

        try await sendCommand("RL0")
        let reply = try await receiveResponse()
        guard reply.hasPrefix("RL0"), let wire = Int(reply.dropFirst(3)) else {
            throw RigError.invalidResponse
        }
        return .enabled(level: Self.scale(wire, from: quirks.noiseReductionLevelMax, to: 255))
    }

    /// Parses `<prefix>n` (read without the `;`): `0` is off, `1` or `2`
    /// (NB2 on radios that have it) is on.
    static func parseOnOff(_ response: String, prefix: String) throws -> Bool {
        guard response.hasPrefix(prefix), response.count == prefix.count + 1 else {
            throw RigError.invalidResponse
        }
        switch response.last {
        case "0": return false
        case "1", "2": return true
        default: throw RigError.invalidResponse
        }
    }
}
