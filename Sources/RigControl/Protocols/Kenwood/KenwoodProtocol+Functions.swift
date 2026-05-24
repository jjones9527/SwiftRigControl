import Foundation

// MARK: - Function toggles (v1.1 parity)
//
// Kenwood text command map, cross-checked against Hamlib
// `rigs/kenwood/kenwood.c::kenwood_set_func` (lines 4339-4467)
// and `kenwood_get_func` (lines 4504-4630):
//
//   "PR0" / "PR" + 0/1   compressor (TS-890S uses PR0; others PR)
//   "VX"  + 0/1          VOX
//   "TO"  + 0/1          CTCSS tone
//   "CT"  + 0/1          CTCSS squelch
//   "LK"  + 0/1          lock
//   "AC11" + 0/1         tuner enable (AC110/AC111)
//   "NT"  + 0/1          auto notch
//   "BC"  + 0/1          beat canceller
//   "NB2" + 0/1          noise blanker 2 (TS-890S only)
//
// Kenwood doesn't expose MN, SATMODE, MUTE, REV, MON, AFC,
// DUAL_WATCH, SCOPE, RESUME via the text protocol — those throw
// .unsupportedOperation here.

extension KenwoodProtocol {

    public func setFunction(_ function: RigFunction, enabled: Bool) async throws {
        let prefix = try kenwoodPrefix(for: function)
        let suffix = enabled ? "1" : "0"
        try await sendCommand(prefix + suffix)
    }

    public func getFunction(_ function: RigFunction) async throws -> Bool {
        let prefix = try kenwoodPrefix(for: function)
        try await sendCommand(prefix)
        let response = try await receiveResponse()
        // Kenwood reply echoes the prefix followed by the
        // status digit. E.g. "PR1" → on.
        guard response.hasPrefix(prefix),
              let statusChar = response.dropFirst(prefix.count).first else {
            throw RigError.invalidResponse
        }
        return statusChar == "1"
    }

    private func kenwoodPrefix(for function: RigFunction) throws -> String {
        switch function {
        case .compressor: return "PR"
        case .vox:        return "VX"
        case .ctcssTone:  return "TO"
        case .ctcssSquelch: return "CT"
        case .lock:       return "LK"
        case .tuner:      return "AC11"
        case .autoNotch:  return "NT"
        case .beatCancel: return "BC"
        case .noiseBlanker2: return "NB2"
        case .manualNotch, .satelliteMode, .monitor,
             .autoFrequencyControl, .dualWatch, .audioPeakFilter,
             .voiceSquelch, .reverseSplit, .mute, .diversity,
             .scope, .scanResume:
            throw RigError.unsupportedOperation(
                "Function '\(function.rawValue)' has no Kenwood text-protocol equivalent"
            )
        }
    }
}
