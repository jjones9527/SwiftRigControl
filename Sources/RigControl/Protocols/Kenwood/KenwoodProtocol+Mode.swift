import Foundation

// Mode selection for Kenwood-protocol radios.
//
// Pre-v1.2.18 every radio sent `MD<n>;` with DATA-LSB / DATA-USB as
// `MD12;` / `MD13;`. No Kenwood accepts a two-digit `MD`: Hamlib never
// sends one (it encodes kmode > 9 as a hex letter, and only on radios
// whose own mode command takes it). DATA handling now follows the
// per-radio `KenwoodModeCommandStyle`.

extension KenwoodProtocol {

    // MARK: - Mode Control

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        switch modeStyle {
        case .standard, .flexDigital:
            let code = try Self.modeCode(for: mode, style: modeStyle)
            try await sendSetCommand("MD\(Self.modeCharacter(code))")

        case .dataSubMode:
            let (base, isData) = Self.splitDataMode(mode)
            let code = try Self.modeCode(for: base, style: .standard)
            try await sendSetCommand("MD\(Self.modeCharacter(code))")
            // DA only applies to SSB / FM / AM. Hamlib sends it after MD
            // (kenwood.c:2670-2727); sending DA0 on a voice mode clears a
            // DATA sub-mode left over from an earlier DATA selection.
            if [.lsb, .usb, .fm, .am].contains(base) {
                try await sendSetCommand(isData ? "DA1" : "DA0")
            }

        case .operatingMode:
            // OM writes affect the operating band (kenwood.c:2631-2653);
            // like the MD path, the `vfo` argument is not used to switch
            // bands first.
            let code = try Self.modeCode(for: mode, style: modeStyle)
            try await sendSetCommand("OM0\(Self.modeCharacter(code))")

        case .setFrequencyAndMode:
            let code = try Self.modeCode(for: mode, style: modeStyle)
            let query = Self.sfQuery(for: vfo)
            try await sendCommand(query)
            let record = try await receiveResponse()
            guard record.hasPrefix(query), record.count > Self.sfModeOffset else {
                throw RigError.invalidResponse
            }
            var chars = Array(record)
            chars[Self.sfModeOffset] = Self.modeCharacter(code)
            try await sendSetCommand(String(chars))

        case .powerSDR:
            let code = try Self.modeCode(for: mode, style: modeStyle)
            try await sendSetCommand(String(format: "ZZMD%02d", code))
        }
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        switch modeStyle {
        case .standard, .flexDigital:
            let code = try await readModeCode(query: "MD", offset: 2)
            return try Self.mode(forCode: code, style: modeStyle)

        case .dataSubMode:
            let code = try await readModeCode(query: "MD", offset: 2)
            let base = try Self.mode(forCode: code, style: .standard)
            try await sendCommand("DA")
            let reply = try await receiveResponse()
            guard reply.hasPrefix("DA"), reply.count >= 3 else {
                throw RigError.invalidResponse
            }
            guard Array(reply)[2] == "1" else { return base }
            switch base {
            case .usb: return .dataUSB
            case .lsb: return .dataLSB
            case .fm: return .dataFM
            default: return base
            }

        case .operatingMode:
            let code = try await readModeCode(query: "OM0", offset: 3)
            return try Self.mode(forCode: code, style: modeStyle)

        case .setFrequencyAndMode:
            let code = try await readModeCode(query: Self.sfQuery(for: vfo),
                                              offset: Self.sfModeOffset)
            return try Self.mode(forCode: code, style: modeStyle)

        case .powerSDR:
            try await sendCommand("ZZMD")
            let reply = try await receiveResponse()
            guard reply.hasPrefix("ZZMD"), reply.count >= 6,
                  let code = Int(reply.dropFirst(4).prefix(2)) else {
                throw RigError.invalidResponse
            }
            return try Self.mode(forCode: code, style: modeStyle)
        }
    }

    // MARK: - Wire helpers

    /// Offset of the mode character in a TS-890S `SF` record
    /// (`SF<v>` + 11-digit frequency), per Hamlib `kenwood.c:2621`.
    static let sfModeOffset = 14

    /// `SF0` for VFO A / main, `SF1` for VFO B / sub.
    static func sfQuery(for vfo: VFO) -> String {
        switch vfo {
        case .a, .main: return "SF0"
        case .b, .sub: return "SF1"
        }
    }

    /// Sends `query`, then decodes the single mode character at
    /// `offset` in the reply (a digit, or a letter for codes ≥ 10).
    private func readModeCode(query: String, offset: Int) async throws -> Int {
        try await sendCommand(query)
        let reply = try await receiveResponse()
        let chars = Array(reply)
        guard reply.hasPrefix(query), chars.count > offset,
              let code = Self.modeCode(fromCharacter: chars[offset]) else {
            throw RigError.invalidResponse
        }
        return code
    }

    /// Encodes a Kenwood mode code as Hamlib does: `0`-`9`, then
    /// `A` for 10, `B` for 11, … (`kenwood.c:2589-2596`).
    static func modeCharacter(_ code: Int) -> Character {
        if code <= 9 {
            return Character(String(code))
        }
        return Character(UnicodeScalar(UInt8(ascii: "A") + UInt8(code - 10)))
    }

    /// Inverse of ``modeCharacter(_:)``.
    static func modeCode(fromCharacter char: Character) -> Int? {
        if let digit = char.wholeNumberValue, char.isASCII {
            return digit
        }
        guard let ascii = char.asciiValue, ascii >= UInt8(ascii: "A"),
              ascii <= UInt8(ascii: "Z") else {
            return nil
        }
        return Int(ascii - UInt8(ascii: "A")) + 10
    }

    /// Splits a DATA mode into its voice base mode for the `MD` + `DA`
    /// style.
    static func splitDataMode(_ mode: Mode) -> (base: Mode, isData: Bool) {
        switch mode {
        case .dataUSB: return (.usb, true)
        case .dataLSB: return (.lsb, true)
        case .dataFM: return (.fm, true)
        default: return (mode, false)
        }
    }

    // MARK: - Mode tables

    /// Mode → code for a given style. DATA modes on ``KenwoodModeCommandStyle/standard``
    /// throw `RigError.unsupportedOperation`.
    static func modeCode(for mode: Mode, style: KenwoodModeCommandStyle) throws -> Int {
        guard let code = modeTable(for: style).first(where: { $0.mode == mode })?.code else {
            throw RigError.unsupportedOperation(
                "Mode \(mode.rawValue) not supported by this Kenwood-protocol radio"
            )
        }
        return code
    }

    /// Code → mode for a given style.
    static func mode(forCode code: Int, style: KenwoodModeCommandStyle) throws -> Mode {
        if let mode = modeTable(for: style).first(where: { $0.code == code })?.mode {
            return mode
        }
        // TS-990S DATA-2 / DATA-3 profiles read back as plain DATA
        // (ts990s.c:110-118: G/H/I and K/L/M).
        if style == .operatingMode {
            switch code {
            case 16, 20: return .dataLSB
            case 17, 21: return .dataUSB
            case 18, 22: return .dataFM
            default: break
            }
        }
        throw RigError.invalidResponse
    }

    /// The code table for each style. The first entry for a mode is the
    /// one used when setting it.
    static func modeTable(for style: KenwoodModeCommandStyle) -> [(mode: Mode, code: Int)] {
        // Shared Kenwood table, kenwood.c:142-168 (8 = TUNE, no Mode).
        let shared: [(mode: Mode, code: Int)] = [
            (.lsb, 1), (.usb, 2), (.cw, 3), (.fm, 4), (.am, 5),
            (.rtty, 6), (.cwR, 7), (.rttyR, 9),
        ]
        switch style {
        case .standard, .dataSubMode:
            return shared
        case .operatingMode, .setFrequencyAndMode:
            // C = LSB-D1, D = USB-D1, E = FM-D1: ts990s.c:106-108 and the
            // shared table's PKTLSB / PKTUSB / PKTFM at 12-14.
            let data: [(mode: Mode, code: Int)] = [
                (.dataLSB, 12), (.dataUSB, 13), (.dataFM, 14),
            ]
            return shared + data
        case .flexDigital:
            // flex6xxx.c:58-70 — 6 = DIGL, 9 = DIGU, no RTTY / CW-R.
            return [(.lsb, 1), (.usb, 2), (.cw, 3), (.fm, 4), (.am, 5),
                    (.dataLSB, 6), (.dataUSB, 9)]
        case .powerSDR:
            // powersdr_mode_table, flex6xxx.c:72-86 (2 = DSB, 10 = SAM
            // have no Mode equivalent).
            return [(.lsb, 0), (.usb, 1), (.cwR, 3), (.cw, 4), (.fm, 5),
                    (.am, 6), (.dataUSB, 7), (.dataLSB, 9)]
        }
    }
}
