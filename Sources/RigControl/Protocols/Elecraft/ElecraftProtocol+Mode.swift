import Foundation

// Mode selection for Elecraft radios.
//
// Before v1.3.1 every Elecraft used one table: DATA-USB → `MD6`,
// DATA-LSB → `MD9`, RTTY → `MD8`. That was wrong for both families:
//
// - K3 / K3S / K4 / KX2 / KX3 use the Kenwood table (`6` = DATA,
//   `9` = DATA-REV, no `8`) and pick the data sub-mode with `DT`
//   (`k3.c:1217-1251`, `1355-1365`). Without `DT0`, a radio left in
//   FSK D stayed in FSK D when VARA HF asked for DATA-USB, and RTTY
//   sent `MD8`, which the radio rejects.
// - The K2 has its own table, with `6` = PKT-LSB and `9` = PKT-USB
//   (`k2.c:46-58`), so DATA-USB and DATA-LSB were swapped. It has no
//   `DT` command, AM, FM or RTTY.

extension ElecraftProtocol {

    // MARK: - Mode Control

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        if usesK2ModeTable {
            try await sendSetCommand("MD\(try Self.k2ModeCode(for: mode))")
            return
        }

        let (code, dataSubMode) = try Self.k3ModeCommand(for: mode)
        try await sendSetCommand("MD\(code)")
        // `DT` only works once the radio is in a DATA mode, so it goes
        // after `MD` (k3.c:1352-1365).
        if let dataSubMode {
            try await sendSetCommand("DT\(dataSubMode)")
        }
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        let code = try await readSingleDigit(query: "MD")

        if usesK2ModeTable {
            return try Self.k2Mode(forCode: code)
        }
        guard code == 6 || code == 9 else {
            return try Self.k3Mode(forCode: code, dataSubMode: nil)
        }
        // DATA / DATA-REV: the sub-mode decides what the mode is
        // (k3_get_mode, k3.c:1053-1120).
        let dataSubMode = try await readSingleDigit(query: "DT")
        return try Self.k3Mode(forCode: code, dataSubMode: dataSubMode)
    }

    // MARK: - Wire helpers

    /// True for the K2, which has its own mode table and no `DT`.
    var usesK2ModeTable: Bool {
        isK2
    }

    /// Sends `query` and reads the single digit after it (`MD2;` → 2).
    private func readSingleDigit(query: String) async throws -> Int {
        try await sendCommand(query)
        let reply = try await receiveResponse()
        let chars = Array(reply)
        guard reply.hasPrefix(query), chars.count > query.count,
              let value = chars[query.count].wholeNumberValue else {
            throw RigError.invalidResponse
        }
        return value
    }

    // MARK: - K3 / K4 / KX tables

    /// `MD` code and, for DATA modes, the `DT` sub-mode for the
    /// K3-family radios.
    ///
    /// DATA-USB / DATA-LSB are `MD6` / `MD9` with `DT0` (DATA A) and
    /// RTTY is `MD6` with `DT2` (FSK D), as in Hamlib `k3_set_mode`
    /// (`k3.c:1217-1238`). RTTY-R is `MD9` with `DT2` (FSK D reversed).
    /// Hamlib sends `DT1` (AFSK A) for RTTY-R, but its own `k3_get_mode`
    /// reads AFSK A back as PKT-LSB, so the mode wouldn't read back as
    /// RTTY-R. `DT2` reads back as RTTY-R in both.
    static func k3ModeCommand(for mode: Mode) throws -> (code: Int, dataSubMode: Int?) {
        switch mode {
        case .lsb: return (1, nil)
        case .usb: return (2, nil)
        case .cw: return (3, nil)
        case .fm: return (4, nil)
        case .am: return (5, nil)
        case .cwR: return (7, nil)
        case .dataUSB: return (6, 0)
        case .dataLSB: return (9, 0)
        case .rtty: return (6, 2)
        case .rttyR: return (9, 2)
        default:
            throw RigError.unsupportedOperation("Mode \(mode) not supported by Elecraft protocol")
        }
    }

    /// Decodes a K3-family `MD` code, plus the `DT` sub-mode for codes
    /// 6 and 9.
    ///
    /// Follows `k3_get_mode` (`k3.c:1053-1120`): AFSK A (`DT1`) is
    /// PKT-LSB, PSK D (`DT3`) is PKT-USB, FSK D (`DT2`) is RTTY. One
    /// difference: `MD9` + `DT0` (DATA A reversed) reads back as
    /// `.dataLSB`. Hamlib reports PKT-USB there, although its own
    /// `k3_set_mode` sends that combination for PKT-LSB.
    static func k3Mode(forCode code: Int, dataSubMode: Int?) throws -> Mode {
        switch (code, dataSubMode) {
        case (1, _): return .lsb
        case (2, _): return .usb
        case (3, _): return .cw
        case (4, _): return .fm
        case (5, _): return .am
        case (7, _): return .cwR
        case (6, 0?), (6, 3?), (9, 3?): return .dataUSB
        case (9, 0?), (6, 1?), (9, 1?): return .dataLSB
        case (6, 2?): return .rtty
        case (9, 2?): return .rttyR
        default:
            throw RigError.invalidResponse
        }
    }

    // MARK: - K2 table

    /// `MD` code for the K2, per `k2_mode_table` (`k2.c:46-58`).
    static func k2ModeCode(for mode: Mode) throws -> Int {
        switch mode {
        case .lsb: return 1
        case .usb: return 2
        case .cw: return 3
        case .dataLSB: return 6
        case .cwR: return 7
        case .dataUSB: return 9
        default:
            throw RigError.unsupportedOperation("Mode \(mode) not supported by the Elecraft K2")
        }
    }

    /// Inverse of ``k2ModeCode(for:)``.
    static func k2Mode(forCode code: Int) throws -> Mode {
        switch code {
        case 1: return .lsb
        case 2: return .usb
        case 3: return .cw
        case 6: return .dataLSB
        case 7: return .cwR
        case 9: return .dataUSB
        default:
            throw RigError.invalidResponse
        }
    }
}
