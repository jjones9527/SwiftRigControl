import Foundation

// MARK: - CW keyer
//
// Hamlib `kenwood_set_level` / `kenwood_get_level` and the per-model
// overrides, checked against what Hamlib 91e7b97 sends on the simulators
// (Scripts/hamlib-set-matrix.py):
//
//   KS%03d              keyer speed, wpm (kenwood.c RIG_LEVEL_KEYSPD)
//   PT%0*d              pitch step index; 3 digits on the TS-890S / TS-990S
//   EXnnn0000%02d       pitch through a menu item on the TS-590 / 480 / 2000
//   SD0000 / SD0050     full break-in on / off via the break-in delay
//                       (RIG_FUNC_FBKIN); TS-590 / 480 / 2000 only
//
// Per-model forms are in KenwoodLevelProfile (cwPitch, breakInViaDelay).

extension KenwoodProtocol: SupportsCWKeyer {

    public func setCWSpeed(_ speed: CWSpeed) async throws {
        try requireKeyer()
        try await sendSetCommand(String(format: "KS%03d", speed.wpm))
    }

    public func getCWSpeed() async throws -> CWSpeed {
        try requireKeyer()
        return CWSpeed(wpm: try await readNumber("KS"))
    }

    public func setCWPitch(_ pitch: CWPitch) async throws {
        try requireKeyer()
        switch levelProfile.cwPitch {
        case .none:
            throw RigError.unsupportedOperation("CW pitch has no CAT command on this radio")
        case .pt(let minHz, let stepHz, let digits):
            let index = max(0, (pitch.hz - minHz + stepHz / 2) / stepHz)
            try await sendSetCommand("PT" + String(format: "%0\(digits)d", index))
        case .exMenu(let number, let minHz, let stepHz):
            let index = max(0, (pitch.hz - minHz) / stepHz)
            try await sendSetCommand(String(format: "EX%03d0000%02d", number, index))
        }
    }

    public func getCWPitch() async throws -> CWPitch {
        try requireKeyer()
        switch levelProfile.cwPitch {
        case .none:
            throw RigError.unsupportedOperation("CW pitch has no CAT command on this radio")
        case .pt(let minHz, let stepHz, _):
            return CWPitch(hz: minHz + stepHz * (try await readNumber("PT")))
        case .exMenu(let number, let minHz, let stepHz):
            let query = String(format: "EX%03d0000", number)
            return CWPitch(hz: minHz + stepHz * (try await readNumber(query)))
        }
    }

    /// Full break-in is the only CAT-settable break-in on Kenwood, through
    /// the delay: `.full` is `SD0000`, `.semi` `SD0050`, as Hamlib's
    /// FBKIN on / off. Turning break-in off is a menu setting, so `.off`
    /// throws.
    public func setBreakIn(_ mode: BreakInMode) async throws {
        try requireKeyer()
        guard levelProfile.breakInViaDelay else {
            throw RigError.unsupportedOperation("Break-in has no CAT command on this radio")
        }
        switch mode {
        case .full: try await sendSetCommand("SD0000")
        case .semi: try await sendSetCommand("SD0050")
        case .off:
            throw RigError.unsupportedOperation("Kenwood break-in is switched off in the menu, not over CAT")
        }
    }

    public func getBreakIn() async throws -> BreakInMode {
        try requireKeyer()
        guard levelProfile.breakInViaDelay else {
            throw RigError.unsupportedOperation("Break-in has no CAT command on this radio")
        }
        return try await readNumber("SD") == 0 ? .full : .semi
    }

    private func requireKeyer() throws {
        guard capabilities.supportsCWKeyer else {
            throw RigError.unsupportedOperation("CW keyer not supported by this radio")
        }
    }

    /// Sends `query` and parses the digits after it in the reply.
    private func readNumber(_ query: String) async throws -> Int {
        try await sendCommand(query)
        let response = try await receiveResponse()
        guard response.hasPrefix(query),
              let value = Int(response.dropFirst(query.count).trimmingCharacters(in: .whitespaces)) else {
            throw RigError.invalidResponse
        }
        return value
    }
}
