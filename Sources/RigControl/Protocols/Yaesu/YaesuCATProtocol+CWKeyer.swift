import Foundation

// MARK: - CW keyer
//
// Hamlib `newcat_set_level` / `newcat_get_level` and `newcat_set_func`,
// checked against what Hamlib 91e7b97 sends on the simulators
// (Scripts/hamlib-set-matrix.py):
//
//   KS%03d     keyer speed, wpm (newcat.c:4327-4333)
//   KP%02d     pitch step index, per-model scale (Quirks.cwPitchMinHz /
//              cwPitchStepHz; newcat.c:4310-4323)
//   BI1 / BI0  break-in on / off (Hamlib RIG_FUNC_FBKIN); semi or full is
//              the radio's menu setting, so .semi and .full both send BI1

extension YaesuCATProtocol: SupportsCWKeyer {

    public func setCWSpeed(_ speed: CWSpeed) async throws {
        try requireKeyer()
        try await sendSetCommand(String(format: "KS%03d", speed.wpm))
    }

    public func getCWSpeed() async throws -> CWSpeed {
        try requireKeyer()
        return CWSpeed(wpm: try await readKeyerNumber("KS"))
    }

    public func setCWPitch(_ pitch: CWPitch) async throws {
        try requireKeyer()
        let step = quirks.cwPitchStepHz
        let index = max(0, (pitch.hz - quirks.cwPitchMinHz + step / 2) / step)
        try await sendSetCommand(String(format: "KP%02d", index))
    }

    public func getCWPitch() async throws -> CWPitch {
        try requireKeyer()
        let index = try await readKeyerNumber("KP")
        return CWPitch(hz: quirks.cwPitchMinHz + quirks.cwPitchStepHz * index)
    }

    public func setBreakIn(_ mode: BreakInMode) async throws {
        try requireKeyer()
        try await sendSetCommand(mode == .off ? "BI0" : "BI1")
    }

    /// `BI1` reads as `.full`, as Hamlib reports it (RIG_FUNC_FBKIN); the
    /// radio's menu decides whether that is semi or full break-in.
    public func getBreakIn() async throws -> BreakInMode {
        try requireKeyer()
        return try await readKeyerNumber("BI") == 0 ? .off : .full
    }

    private func requireKeyer() throws {
        guard capabilities.supportsCWKeyer else {
            throw RigError.unsupportedOperation("CW keyer not supported by this radio")
        }
    }

    private func readKeyerNumber(_ query: String) async throws -> Int {
        try await sendCommand(query)
        let response = try await receiveResponse()
        guard response.hasPrefix(query), let value = Int(response.dropFirst(query.count)) else {
            throw RigError.invalidResponse
        }
        return value
    }
}
