import Foundation

// MARK: - Secondary levels (v1.1 parity)
//
// Kenwood text command map (kenwood.c:set_level / get_level):
//
//   "MG" + 3-digit  — mic gain (0-100, sent as MGnnn)
//   "PL" + 3-digit  — speech processor level (0-100)
//   "ML" + 3-digit  — monitor gain (CW sidetone)
//   "VG" + 3-digit  — VOX gain (0-9 on TS-2000, 0-100 modern)
//   "VD" + 4-digit  — VOX delay (msec; modern radios)
//   "IS" + 5-digit  — IF shift (typically signed offset Hz)
//
// Older Kenwoods (TS-870, TS-570) use 2-digit gain payloads;
// modern HF rigs (TS-590S/SG, TS-890S, TS-990S) use 3-digit.
// We emit 3-digit. If a TS-870-class user reports a NAK,
// switching on capability is the right next step — not silent
// padding adjustment.

extension KenwoodProtocol {

    public func setMicGain(_ level: Int) async throws {
        try await setLevel(prefix: "MG", level: level, width: 3)
    }
    public func getMicGain() async throws -> Int {
        try await getLevel(prefix: "MG", width: 3)
    }

    /// Speech-processor level. Hamlib sends `PLnnnmmm` (input and output
    /// level) on the TS-590 / TS-2000 / TS-480 / TS-990S / TX-500;
    /// through v1.3.1 this sent a single `PLnnn`.
    public func setCompressorLevel(_ level: Int) async throws {
        let maximum = levelProfile.compressorMax
        let wire = String(format: "%03d", Self.scaleLevel(level, to: maximum))
        try await sendSetCommand("PL" + wire + (levelProfile.compressorHasTwoValues ? wire : ""))
    }
    public func getCompressorLevel() async throws -> Int {
        try await getLevel(prefix: "PL", width: 3, wireMax: levelProfile.compressorMax)
    }

    /// Monitor gain, 0–100 scaled to ``KenwoodLevelProfile/monitorGainMax``
    /// (`ML` 0–20 on the TS-590SG, 0–9 on the TS-590S / TS-2000 / TS-480).
    public func setMonitorGain(_ level: Int) async throws {
        try await setLevel(prefix: "ML", level: level, width: 3, wireMax: levelProfile.monitorGainMax)
    }
    public func getMonitorGain() async throws -> Int {
        try await getLevel(prefix: "ML", width: 3, wireMax: levelProfile.monitorGainMax)
    }

    /// VOX gain, 0–100 scaled to ``KenwoodLevelProfile/voxGainMax``
    /// (`VG` 0–9, Hamlib `kenwood.c` RIG_LEVEL_VOXGAIN).
    public func setVOXGain(_ level: Int) async throws {
        try await setLevel(prefix: "VG", level: level, width: 3, wireMax: levelProfile.voxGainMax)
    }
    public func getVOXGain() async throws -> Int {
        try await getLevel(prefix: "VG", width: 3, wireMax: levelProfile.voxGainMax)
    }

    public func setVOXDelay(_ level: Int) async throws {
        try await setLevel(prefix: "VD", level: level, width: 4)
    }
    public func getVOXDelay() async throws -> Int {
        try await getLevel(prefix: "VD", width: 4)
    }

    public func setIFShift(_ level: Int) async throws {
        // IS takes a 5-digit signed offset. We expose a 0-100
        // normalised level for symmetry with the other knobs;
        // 50 = centre (no shift), 0 = -1000 Hz, 100 = +1000 Hz.
        let centred = (level - 50) * 20
        let sign = centred < 0 ? "-" : "+"
        let cmd = "IS\(sign)\(String(format: "%04d", abs(centred)))"
        try await sendSetCommand(cmd)
    }
    public func getIFShift() async throws -> Int {
        try await sendCommand("IS")
        let response = try await receiveResponse()
        guard response.hasPrefix("IS"),
              let val = Int(response.dropFirst(2)) else {
            throw RigError.invalidResponse
        }
        return min(max(50 + val / 20, 0), 100)
    }

    private func setLevel(prefix: String, level: Int, width: Int, wireMax: Int = 100) async throws {
        let formatted = String(format: "%0\(width)d", Self.scaleLevel(level, to: wireMax))
        try await sendSetCommand("\(prefix)\(formatted)")
    }

    /// Maps a 0–100 level onto 0...`wireMax`, truncating like Hamlib's
    /// `(int)(val.f * max)`.
    static func scaleLevel(_ level: Int, to wireMax: Int) -> Int {
        min(max(level, 0), 100) * wireMax / 100
    }

    private func getLevel(prefix: String, width: Int, wireMax: Int = 100) async throws -> Int {
        try await sendCommand(prefix)
        let response = try await receiveResponse()
        guard response.hasPrefix(prefix), wireMax > 0,
              let val = Int(response.dropFirst(prefix.count).prefix(width)) else {
            throw RigError.invalidResponse
        }
        return (min(max(val, 0), wireMax) * 100 + wireMax / 2) / wireMax
    }
}
