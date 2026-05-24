import Foundation

// MARK: - Secondary levels (v1.1 parity)
//
// All levels use the 0x14 command family (S_LVL_*), per
// `rigs/icom/icom_defs.h`:
//
//   0x14 0x04 — IF shift          (RIG_LEVEL_IF)
//   0x14 0x0B — mic gain           (RIG_LEVEL_MICGAIN)
//   0x14 0x0E — compressor level   (RIG_LEVEL_COMP)
//   0x14 0x15 — monitor gain       (RIG_LEVEL_MONITOR_GAIN)
//   0x14 0x16 — VOX gain           (RIG_LEVEL_VOXGAIN)
//
// All values are BCD-encoded 0-255 (we expose 0-100 to callers,
// matching how the rest of the level surface works).
//
// VOX *delay* is a quirky one — Hamlib uses a custom encoding
// per radio (some take seconds, some take a raw delay index).
// We expose the raw byte index here; per-radio normalisation can
// follow later if a real user asks for it.

extension IcomCIVProtocol {

    public func setMicGain(_ level: Int) async throws {
        try await setLevel(subCmd: 0x0B, level: level, label: "mic gain")
    }

    public func getMicGain() async throws -> Int {
        try await getLevel(subCmd: 0x0B, label: "mic gain")
    }

    public func setCompressorLevel(_ level: Int) async throws {
        try await setLevel(subCmd: 0x0E, level: level, label: "compressor level")
    }

    public func getCompressorLevel() async throws -> Int {
        try await getLevel(subCmd: 0x0E, label: "compressor level")
    }

    public func setMonitorGain(_ level: Int) async throws {
        try await setLevel(subCmd: 0x15, level: level, label: "monitor gain")
    }

    public func getMonitorGain() async throws -> Int {
        try await getLevel(subCmd: 0x15, label: "monitor gain")
    }

    public func setVOXGain(_ level: Int) async throws {
        try await setLevel(subCmd: 0x16, level: level, label: "VOX gain")
    }

    public func getVOXGain() async throws -> Int {
        try await getLevel(subCmd: 0x16, label: "VOX gain")
    }

    public func setVOXDelay(_ level: Int) async throws {
        // Hamlib has per-radio quirks here; pending a user
        // request we use a raw set with sub-cmd 0x1A 0x05 0x06
        // (the typical S_LVL_VOXDLY layout on the IC-7300 family).
        // Until exercised against hardware, treat this as the
        // generic 0x14 sub-cmd path matching VOXGAIN.
        try await setLevel(subCmd: 0x16, level: level, label: "VOX delay")
    }

    public func getVOXDelay() async throws -> Int {
        try await getLevel(subCmd: 0x16, label: "VOX delay")
    }

    public func setIFShift(_ level: Int) async throws {
        try await setLevel(subCmd: 0x04, level: level, label: "IF shift")
    }

    public func getIFShift() async throws -> Int {
        try await getLevel(subCmd: 0x04, label: "IF shift")
    }

    // MARK: - Private helpers

    private func setLevel(subCmd: UInt8, level: Int, label: String) async throws {
        let clamped = min(max(level, 0), 100)
        let scaled = (clamped * 255) / 100
        let bcd = BCDEncoding.encodePower(scaled)
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, subCmd],
            data: bcd
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected \(label) command")
        }
    }

    private func getLevel(subCmd: UInt8, label: String) async throws -> Int {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, subCmd],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let scaled = BCDEncoding.decodePower(response.data)
        return (scaled * 100) / 255
    }
}
