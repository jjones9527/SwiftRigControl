import Foundation

// MARK: - Function toggles (v1.1 parity)
//
// Yaesu newcat command map, cross-checked against Hamlib
// `rigs/yaesu/newcat.c::newcat_set_func` (lines 5992-6420):
//
//   "PR0" + 0/1     compressor (FT-991/FT-710/FTDX use PR0; older "PR")
//   "VX" + 0/1      VOX
//   "CT0" + 0/2     CTCSS tone (data 2 = encode-only)
//   "CT0" + 0/1     CTCSS squelch (data 1 = encode+decode)
//   "LK" + 0/1      lock (some models use 0/4 for lock-on)
//   "AC00" + 0/1    tuner enable
//   "BC0" + 0/1     auto notch
//   "BP00" + 0/1    manual notch
//   "ML0" + 0/1     monitor
//   "NB0" + 0/2     noise blanker 2
//   "CO" frame     audio peak filter (model-specific framing)
//
// Yaesu does NOT expose AFC, SATMODE, MUTE, REV, BC, DUAL_WATCH,
// SCOPE, RESUME, DIVERSITY via newcat — those throw .
// unsupportedOperation here.

extension YaesuCATProtocol {

    public func setFunction(_ function: RigFunction, enabled: Bool) async throws {
        let command = try yaesuCommand(for: function, set: true, enabled: enabled)
        try await sendCommand(command)
    }

    public func getFunction(_ function: RigFunction) async throws -> Bool {
        let prefix = try yaesuCommand(for: function, set: false, enabled: false)
        try await sendCommand(prefix)
        let response = try await receiveResponse()
        // Yaesu responses echo the prefix and trail a status
        // digit. The exact format varies (some commands return
        // multi-char payloads); we treat any non-zero last
        // digit as "on" — consistent with what `newcat_get_func`
        // does internally.
        guard let lastDigit = response.last else {
            throw RigError.invalidResponse
        }
        return lastDigit != "0"
    }

    private func yaesuCommand(
        for function: RigFunction,
        set: Bool,
        enabled: Bool
    ) throws -> String {
        let digit = enabled ? "1" : "0"

        switch function {
        case .compressor:
            return set ? "PR0\(digit)" : "PR0"
        case .vox:
            return set ? "VX\(digit)" : "VX"
        case .ctcssTone:
            // CT0 + 2/0 (2 = encode-only).
            let tonePayload = enabled ? "2" : "0"
            return set ? "CT0\(tonePayload)" : "CT0"
        case .ctcssSquelch:
            // CT0 + 1/0 (1 = encode+decode).
            return set ? "CT0\(digit)" : "CT0"
        case .lock:
            return set ? "LK\(digit)" : "LK"
        case .tuner:
            return set ? "AC00\(digit)" : "AC00"
        case .autoNotch:
            return set ? "BC0\(digit)" : "BC0"
        case .manualNotch:
            return set ? "BP00\(digit)" : "BP00"
        case .monitor:
            return set ? "ML0\(digit)" : "ML0"
        case .noiseBlanker2:
            let nbPayload = enabled ? "2" : "0"
            return set ? "NB0\(nbPayload)" : "NB0"
        case .satelliteMode, .autoFrequencyControl, .beatCancel,
             .dualWatch, .audioPeakFilter, .voiceSquelch,
             .reverseSplit, .mute, .diversity, .scope, .scanResume:
            throw RigError.unsupportedOperation(
                "Function '\(function.rawValue)' has no Yaesu newcat equivalent"
            )
        }
    }
}
