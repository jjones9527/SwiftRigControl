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

    public func setCompressorLevel(_ level: Int) async throws {
        try await setLevel(prefix: "PL", level: level, width: 3)
    }
    public func getCompressorLevel() async throws -> Int {
        try await getLevel(prefix: "PL", width: 3)
    }

    public func setMonitorGain(_ level: Int) async throws {
        try await setLevel(prefix: "ML", level: level, width: 3)
    }
    public func getMonitorGain() async throws -> Int {
        try await getLevel(prefix: "ML", width: 3)
    }

    public func setVOXGain(_ level: Int) async throws {
        try await setLevel(prefix: "VG", level: level, width: 3)
    }
    public func getVOXGain() async throws -> Int {
        try await getLevel(prefix: "VG", width: 3)
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
        try await sendCommand(cmd)
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

    private func setLevel(prefix: String, level: Int, width: Int) async throws {
        let clamped = min(max(level, 0), 100)
        let formatted = String(format: "%0\(width)d", clamped)
        try await sendCommand("\(prefix)\(formatted)")
    }

    private func getLevel(prefix: String, width: Int) async throws -> Int {
        try await sendCommand(prefix)
        let response = try await receiveResponse()
        guard response.hasPrefix(prefix),
              let val = Int(response.dropFirst(prefix.count).prefix(width)) else {
            throw RigError.invalidResponse
        }
        return min(max(val, 0), 100)
    }
}
