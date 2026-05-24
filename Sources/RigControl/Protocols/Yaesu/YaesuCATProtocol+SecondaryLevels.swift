import Foundation

// MARK: - Secondary levels (v1.1 parity)
//
// Yaesu newcat command map (newcat.c:set_level / get_level):
//
//   "MG" + 3-digit  — mic gain (0-100)
//   "PL" + 3-digit  — speech processor / compressor level
//   "ML0" + 3-digit — monitor level (CW sidetone)
//   "VG" + 3-digit  — VOX gain
//   "VD" + 4-digit  — VOX delay (ms)
//   "IS" + 5-digit  — IF shift offset (signed Hz, ±1200 typical)
//
// Most newcat radios use these prefixes uniformly. Some FT-DX
// models prefix with "0"/"1" for main/sub VFO (we always target
// the main).

extension YaesuCATProtocol {

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
        try await setLevel(prefix: "ML0", level: level, width: 3)
    }
    public func getMonitorGain() async throws -> Int {
        try await getLevel(prefix: "ML0", width: 3)
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
        // IS takes ±5-digit signed Hz. Map 0-100 to ±1200 Hz
        // (typical FT-991 / FT-710 IF-shift range).
        let centred = (level - 50) * 24
        let sign = centred < 0 ? "-" : "+"
        let cmd = "IS0\(sign)\(String(format: "%04d", abs(centred)))"
        try await sendCommand(cmd)
    }
    public func getIFShift() async throws -> Int {
        try await sendCommand("IS0")
        let response = try await receiveResponse()
        // Response: IS0[+/-]NNNN;
        let payload = response.dropFirst(3).prefix { $0 != ";" }
        guard let val = Int(payload) else {
            throw RigError.invalidResponse
        }
        return min(max(50 + val / 24, 0), 100)
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
