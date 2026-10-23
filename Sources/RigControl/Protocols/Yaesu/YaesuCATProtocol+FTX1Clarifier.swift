import Foundation

// MARK: - FTX-1 Clarifier
//
// The FTX-1 drives RIT/XIT through the `CF` command family instead of the
// newcat `RC/RU/RD/RT/XT` commands (Hamlib `rigs/yaesu/ftx1/ftx1_clarifier.c`):
//
//   CF P1 0 0 P4 P5 000;   P4 = RX clarifier on/off, P5 = TX clarifier on/off
//   CF P1 0 1 ±NNNN;       shared RX/TX clarifier offset, 0–9999 Hz
//
// P1 selects the side: `0` = Main, `1` = Sub. Each side has its own RX/TX
// enable pair and offset. Hamlib keeps one cached enable pair for both sides
// (the per-VFO cache bug fixed upstream in `112304a`); we query the target
// side's current pair before every write, so the other clarifier's state is
// always preserved from the radio, never from a stale cache.
//
// Split out of YaesuCATProtocol+RITControl.swift when the VFO-qualified
// overloads were added.

extension YaesuCATProtocol {

    // MARK: - VFO-qualified RIT/XIT

    /// Sets the RIT state on a specific VFO side.
    ///
    /// On the FTX-1 this addresses the Main (`.a` / `.main`) or Sub
    /// (`.b` / `.sub`) clarifier independently, using `CF0…` or `CF1…`
    /// per Hamlib `ftx1_set_rx_clar`. The TX clarifier enable on the same
    /// side is preserved.
    ///
    /// On every other Yaesu radio only `.a` / `.main` is accepted, and it
    /// behaves exactly like ``setRIT(_:)``.
    ///
    /// This is a vendor extension and bypasses `RigController`'s RIT
    /// cache; call `rig.getRIT(cached: false)` afterwards if you also read
    /// RIT through the controller.
    ///
    /// ```swift
    /// if case .yaesu(let yaesu) = await rig.vendorExtensions {
    ///     try await yaesu.setRIT(RITXITState(enabled: true, offset: 300), vfo: .sub)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - state: The desired RIT state (offset -9999 to +9999 Hz).
    ///   - vfo: The side to address.
    /// - Throws: `RigError.unsupportedOperation` if this radio can't
    ///   address `vfo`, `RigError.invalidParameter` for an out-of-range
    ///   offset, or a transport/protocol error.
    public func setRIT(_ state: RITXITState, vfo: VFO) async throws {
        if quirks.usesFTX1ClarifierCommands {
            try await setFTX1Clarifier(state, transmit: false, side: Self.ftx1ClarifierSide(for: vfo))
            return
        }
        try requireMainClarifier(vfo, feature: "RIT")
        try await setRIT(state)
    }

    /// Gets the RIT state of a specific VFO side.
    ///
    /// See ``setRIT(_:vfo:)`` for how `vfo` maps to the radio.
    ///
    /// - Parameter vfo: The side to read.
    /// - Returns: The RIT state; `.disabled` when the RX clarifier is off.
    /// - Throws: `RigError.unsupportedOperation` if this radio can't
    ///   address `vfo`, or a transport/protocol error.
    public func getRIT(vfo: VFO) async throws -> RITXITState {
        if quirks.usesFTX1ClarifierCommands {
            return try await getFTX1Clarifier(transmit: false, side: Self.ftx1ClarifierSide(for: vfo))
        }
        try requireMainClarifier(vfo, feature: "RIT")
        return try await getRIT()
    }

    /// Sets the XIT state on a specific VFO side.
    ///
    /// On the FTX-1 the XIT offset is the same per-side clarifier offset
    /// RIT uses, so setting XIT on a side also changes that side's RIT
    /// offset. The RX clarifier enable on the same side is preserved.
    /// See ``setRIT(_:vfo:)`` for VFO mapping and caching notes.
    ///
    /// - Parameters:
    ///   - state: The desired XIT state (offset -9999 to +9999 Hz).
    ///   - vfo: The side to address.
    /// - Throws: `RigError.unsupportedOperation` if this radio can't
    ///   address `vfo`, `RigError.invalidParameter` for an out-of-range
    ///   offset, or a transport/protocol error.
    public func setXIT(_ state: RITXITState, vfo: VFO) async throws {
        if quirks.usesFTX1ClarifierCommands {
            try await setFTX1Clarifier(state, transmit: true, side: Self.ftx1ClarifierSide(for: vfo))
            return
        }
        try requireMainClarifier(vfo, feature: "XIT")
        try await setXIT(state)
    }

    /// Gets the XIT state of a specific VFO side.
    ///
    /// See ``setRIT(_:vfo:)`` for how `vfo` maps to the radio.
    ///
    /// - Parameter vfo: The side to read.
    /// - Returns: The XIT state; `.disabled` when the TX clarifier is off.
    /// - Throws: `RigError.unsupportedOperation` if this radio can't
    ///   address `vfo`, or a transport/protocol error.
    public func getXIT(vfo: VFO) async throws -> RITXITState {
        if quirks.usesFTX1ClarifierCommands {
            return try await getFTX1Clarifier(transmit: true, side: Self.ftx1ClarifierSide(for: vfo))
        }
        try requireMainClarifier(vfo, feature: "XIT")
        return try await getXIT()
    }

    /// Non-FTX-1 newcat RIT/XIT commands have no VFO parameter, so only
    /// the main side can be addressed.
    private func requireMainClarifier(_ vfo: VFO, feature: String) throws {
        guard vfo == .a || vfo == .main else {
            throw RigError.unsupportedOperation("\(feature) on VFO \(vfo.rawValue) is not supported by this radio")
        }
    }

    // MARK: - CF command

    /// The `CF` P1 digit for a VFO: `0` for Main, `1` for Sub. Matches
    /// Hamlib `ftx1_get_cf_vfo_param`, which treats `RIG_VFO_B` and
    /// `RIG_VFO_SUB` alike.
    static func ftx1ClarifierSide(for vfo: VFO) -> Character {
        switch vfo {
        case .a, .main: return "0"
        case .b, .sub: return "1"
        }
    }

    /// Sets one FTX-1 clarifier on `side` while preserving the other
    /// clarifier's enable state on that side.
    func setFTX1Clarifier(_ state: RITXITState, transmit: Bool, side: Character = "0") async throws {
        guard abs(state.offset) <= 9999 else {
            throw RigError.invalidParameter("FTX-1 clarifier offset must be between -9999 and +9999 Hz")
        }
        guard !state.enabled || state.offset != 0 else {
            throw RigError.invalidParameter("FTX-1 requires a nonzero offset to enable a clarifier")
        }

        let current = try await queryFTX1ClarifierState(side: side)
        let enabled = state.enabled ? "1" : "0"
        let rx = transmit ? (current.rxEnabled ? "1" : "0") : enabled
        let tx = transmit ? enabled : (current.txEnabled ? "1" : "0")
        try await sendSetCommand("CF\(side)00\(rx)\(tx)000")

        if state.enabled {
            let sign = state.offset < 0 ? "-" : "+"
            try await sendSetCommand("CF\(side)01\(sign)" + String(format: "%04d", abs(state.offset)))
        }
    }

    /// Reads one FTX-1 clarifier on `side` and, if enabled, its offset.
    func getFTX1Clarifier(transmit: Bool, side: Character = "0") async throws -> RITXITState {
        let state = try await queryFTX1ClarifierState(side: side)
        let enabled = transmit ? state.txEnabled : state.rxEnabled
        guard enabled else {
            return .disabled
        }

        try await sendCommand("CF\(side)01")
        let response = try await receiveResponse()
        return RITXITState(enabled: true, offset: try Self.ftx1ClarifierOffset(from: response, side: side))
    }

    private func queryFTX1ClarifierState(side: Character) async throws -> (rxEnabled: Bool, txEnabled: Bool) {
        try await sendCommand("CF\(side)00")
        let response = try await receiveResponse()
        return try Self.ftx1ClarifierState(from: response, side: side)
    }

    /// Parses a `CF P1 00` reply (read without its `;`). The P1 digit must
    /// match `side`, as in Hamlib `ftx1_parse_clar_state`.
    static func ftx1ClarifierState(from response: String, side: Character = "0") throws -> (rxEnabled: Bool, txEnabled: Bool) {
        let chars = Array(response)
        guard chars.count == 10,
              chars[0] == "C", chars[1] == "F", chars[2] == side,
              chars[3] == "0", chars[4] == "0",
              chars[5] == "0" || chars[5] == "1",
              chars[6] == "0" || chars[6] == "1",
              String(chars[7...9]) == "000" else {
            throw RigError.invalidResponse
        }
        return (chars[5] == "1", chars[6] == "1")
    }

    /// Parses a `CF P1 01 ±NNNN` reply (read without its `;`). The P1 digit
    /// must match `side`, as in Hamlib `ftx1_parse_clar_offset`.
    static func ftx1ClarifierOffset(from response: String, side: Character = "0") throws -> Int {
        let chars = Array(response)
        guard chars.count == 10,
              chars[0] == "C", chars[1] == "F", chars[2] == side,
              chars[3] == "0", chars[4] == "1",
              chars[5] == "+" || chars[5] == "-",
              chars[6...9].allSatisfy(\.isASCIIDigit),
              let magnitude = Int(String(chars[6...9])) else {
            throw RigError.invalidResponse
        }
        return chars[5] == "-" ? -magnitude : magnitude
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
