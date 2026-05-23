import Foundation

// MARK: - CW keyer (Phase 4.2)
//
// Implements the CATProtocol CW accessors on Icom CI-V. All wire
// commands cross-referenced against Hamlib's rigs/icom/icom_defs.h
// and rigs/icom/icom.c.
//
//   C_CTL_LVL  0x14   — generic level set/read
//     S_LVL_CWPITCH  0x09   CW pitch (300–900 Hz)
//     S_LVL_KEYSPD   0x0C   CW keyer speed (6–48 WPM)
//     S_LVL_BKINDL   0x0F   Break-in delay (we use the function variant)
//   C_CTL_FUNC 0x16   — function toggle set/read
//     S_FUNC_BKIN    0x47   Break-in mode (0x00=off, 0x01=semi, 0x02=full)
//   C_SND_CW   0x17   — send a CW text message (payload = ASCII, max 30)
//     payload 0xFF                — abort/stop
//
// Speed encoding uses Hamlib's `cw_lookup[43][2]` table — the radio
// expects a 0..250 byte value that the table maps to 6..48 WPM in
// non-linear steps. Pitch uses a linear formula:
//   icom_byte = round((Hz - 300) * 255 / 600)

extension IcomCIVProtocol {

    // MARK: - CW speed

    public func setCWSpeed(_ speed: CWSpeed) async throws {
        guard capabilities.supportsCWKeyer else {
            throw RigError.unsupportedOperation("CW keyer not supported by this radio")
        }
        let byte = Self.encodeCWSpeed(wpm: speed.wpm)
        let bcd = BCDEncoding.encodePower(Int(byte))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0C],
            data: bcd
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected CW speed \(speed.wpm) WPM")
        }
    }

    public func getCWSpeed() async throws -> CWSpeed {
        guard capabilities.supportsCWKeyer else {
            throw RigError.unsupportedOperation("CW keyer not supported by this radio")
        }
        let frame = CIVFrame(to: civAddress, command: [0x14, 0x0C])
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2,
              response.command[0] == 0x14, response.command[1] == 0x0C,
              response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let raw = BCDEncoding.decodePower(response.data)
        return CWSpeed(wpm: Self.decodeCWSpeed(byte: raw))
    }

    // MARK: - CW pitch

    public func setCWPitch(_ pitch: CWPitch) async throws {
        guard capabilities.supportsCWKeyer else {
            throw RigError.unsupportedOperation("CW keyer not supported by this radio")
        }
        let byte = Self.encodeCWPitch(hz: pitch.hz)
        let bcd = BCDEncoding.encodePower(Int(byte))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x09],
            data: bcd
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected CW pitch \(pitch.hz) Hz")
        }
    }

    public func getCWPitch() async throws -> CWPitch {
        guard capabilities.supportsCWKeyer else {
            throw RigError.unsupportedOperation("CW keyer not supported by this radio")
        }
        let frame = CIVFrame(to: civAddress, command: [0x14, 0x09])
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2,
              response.command[0] == 0x14, response.command[1] == 0x09,
              response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let raw = BCDEncoding.decodePower(response.data)
        return CWPitch(hz: Self.decodeCWPitch(byte: raw))
    }

    // MARK: - Break-in mode

    public func setBreakIn(_ mode: BreakInMode) async throws {
        guard capabilities.supportsCWKeyer else {
            throw RigError.unsupportedOperation("Break-in not supported by this radio")
        }
        let payload: UInt8
        switch mode {
        case .off:  payload = 0x00
        case .semi: payload = 0x01
        case .full: payload = 0x02
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x47],
            data: [payload]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected break-in mode \(mode)")
        }
    }

    public func getBreakIn() async throws -> BreakInMode {
        guard capabilities.supportsCWKeyer else {
            throw RigError.unsupportedOperation("Break-in not supported by this radio")
        }
        let frame = CIVFrame(to: civAddress, command: [0x16, 0x47])
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2,
              response.command[0] == 0x16, response.command[1] == 0x47,
              response.data.count >= 1 else {
            throw RigError.invalidResponse
        }
        switch response.data[0] {
        case 0x00: return .off
        case 0x01: return .semi
        case 0x02: return .full
        default:   throw RigError.invalidResponse
        }
    }

    // MARK: - Send / stop CW

    public func sendCW(_ text: String) async throws {
        guard capabilities.supportsSendCW else {
            throw RigError.unsupportedOperation("CW text send not supported by this radio")
        }
        // Icom's CI-V send-CW command (0x17) caps the message at 30
        // ASCII bytes. Hamlib's icom_send_morse truncates silently;
        // we do the same so callers don't have to special-case.
        // Non-ASCII characters are stripped — the radio wouldn't
        // know what to do with them anyway.
        let asciiBytes = text.unicodeScalars
            .compactMap { $0.isASCII ? UInt8($0.value) : nil }
            .prefix(30)
        let frame = CIVFrame(
            to: civAddress,
            command: [0x17],
            data: Array(asciiBytes)
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected CW send")
        }
    }

    public func stopCW() async throws {
        guard capabilities.supportsSendCW else {
            throw RigError.unsupportedOperation("CW text send not supported by this radio")
        }
        // Per Hamlib icom_stop_morse: send 0x17 with a single 0xFF
        // payload byte. The radio treats this as "abort current CW
        // message" and ACKs even if nothing is currently sending.
        let frame = CIVFrame(
            to: civAddress,
            command: [0x17],
            data: [0xFF]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected CW stop")
        }
    }

    // MARK: - Encoding helpers
    //
    // Exposed `internal` so tests can verify exact byte sequences.

    /// CW speed lookup from Hamlib `cw_lookup[43][2]` in
    /// `rigs/icom/icom.c`. Format: `(icom_byte, wpm)` pairs.
    internal static let cwSpeedTable: [(byte: UInt8, wpm: Int)] = [
        (0, 6),    (7, 7),    (12, 8),   (19, 9),   (25, 10),
        (31, 11),  (37, 12),  (43, 13),  (49, 14),  (55, 15),
        (61, 16),  (67, 17),  (73, 18),  (79, 19),  (84, 20),
        (91, 21),  (97, 22),  (103, 23), (108, 24), (114, 25),
        (121, 26), (128, 27), (134, 28), (140, 29), (144, 30),
        (151, 31), (156, 32), (164, 33), (169, 34), (175, 35),
        (182, 36), (188, 37), (192, 38), (199, 39), (203, 40),
        (211, 41), (215, 42), (224, 43), (229, 44), (234, 45),
        (239, 46), (244, 47), (250, 48),
    ]

    /// WPM → Icom byte. Clamps to the 6…48 range and rounds up to
    /// the nearest supported step (matches Hamlib's behavior).
    internal static func encodeCWSpeed(wpm: Int) -> UInt8 {
        let clamped = max(6, min(wpm, 48))
        // Walk the table; pick the smallest entry whose wpm ≥ target.
        for entry in cwSpeedTable {
            if entry.wpm >= clamped { return entry.byte }
        }
        return cwSpeedTable.last!.byte
    }

    /// Icom byte → WPM. Picks the nearest table entry; values that
    /// don't appear in the table (radio firmware quirks) round to
    /// the closest supported WPM.
    internal static func decodeCWSpeed(byte: Int) -> Int {
        guard !cwSpeedTable.isEmpty else { return 20 }
        var best = cwSpeedTable[0]
        var bestDistance = abs(Int(best.byte) - byte)
        for entry in cwSpeedTable.dropFirst() {
            let d = abs(Int(entry.byte) - byte)
            if d < bestDistance {
                best = entry
                bestDistance = d
            }
        }
        return best.wpm
    }

    /// Hz → Icom byte. Formula from Hamlib `rigs/icom/icom.c`:
    /// `round((Hz - 300) * 255 / 600)`, clamped to 0…255.
    internal static func encodeCWPitch(hz: Int) -> UInt8 {
        let clamped = max(300, min(hz, 900))
        let raw = Int((Double(clamped - 300) * 255.0 / 600.0).rounded())
        return UInt8(max(0, min(raw, 255)))
    }

    /// Icom byte → Hz. Inverse of `encodeCWPitch`, rounded to
    /// the nearest integer Hz.
    internal static func decodeCWPitch(byte: Int) -> Int {
        let hz = Int((Double(byte) * 600.0 / 255.0).rounded()) + 300
        return max(300, min(hz, 900))
    }
}
