import Foundation

// MARK: - Function toggles (v1.1 parity)
//
// Kenwood text command map, cross-checked against Hamlib
// `rigs/kenwood/kenwood.c::kenwood_set_func` / `kenwood_get_func`:
//
//   "PR"  + 0/1          compressor
//   "VX"  + 0/1          VOX ("ZZVE" on PowerSDR / Thetis)
//   "TO"  + 0/1          CTCSS tone
//   "CT"  + 0/1          CTCSS squelch
//   "LK"  + 0/1          lock; LKn0 on the TS-590, LKnn on the TS-480 /
//                        TS-2000 (KenwoodLevelProfile.lockForm)
//   "AC1" + 0/1 + "0"    tuner on/off, no tune cycle; ACnn0 on the
//                        TS-590, "AC n0" on the TS-570, ZZTUn on
//                        PowerSDR (KenwoodLevelProfile.tunerForm)
//   "NT"  + 0/1          auto notch
//   "BC"  + 0/1          beat canceller
//   "NB2" + 0/1          noise blanker 2 (TS-890S only)
//
// Kenwood doesn't expose MN, SATMODE, MUTE, REV, MON, AFC,
// DUAL_WATCH, SCOPE, RESUME via the text protocol — those throw
// .unsupportedOperation here.

extension KenwoodProtocol {

    public func setFunction(_ function: RigFunction, enabled: Bool) async throws {
        try await sendSetCommand(try kenwoodSetCommand(for: function, enabled: enabled))
    }

    public func getFunction(_ function: RigFunction) async throws -> Bool {
        let (query, replyPrefix) = try kenwoodQuery(for: function)
        try await sendCommand(query)
        let response = try await receiveResponse()
        guard response.hasPrefix(replyPrefix) else {
            throw RigError.invalidResponse
        }
        let digits = Array(response.dropFirst(replyPrefix.count))
        switch function {
        case .tuner where levelProfile.tunerForm != .powerSDR:
            // AC P1 P2 P3: P2 is the TX tuner (kenwood_get_func, kenwood.c:4633).
            guard digits.count >= 2 else { throw RigError.invalidResponse }
            return digits[1] == "1"
        default:
            // The first digit is the state, also for LKn0 / LKnn.
            guard let first = digits.first else { throw RigError.invalidResponse }
            return first == "1"
        }
    }

    private func kenwoodSetCommand(for function: RigFunction, enabled: Bool) throws -> String {
        let d = enabled ? "1" : "0"
        switch function {
        case .lock:
            switch levelProfile.lockForm {
            case .single:       return "LK\(d)"
            case .trailingZero: return "LK\(d)0"
            case .doubled:      return "LK\(d)\(d)"
            }
        case .tuner:
            // Through v1.3.1 this sent AC111 for "on", which starts a tune
            // cycle, and AC110 for "off", which is Hamlib's "on".
            switch levelProfile.tunerForm {
            case .standard:           return "AC1\(d)0"
            case .receiveAndTransmit: return "AC\(d)\(d)0"
            case .ts570:              return "AC \(d)0"
            case .powerSDR:           return "ZZTU\(d)"
            }
        case .vox:
            return levelProfile.voxPrefix + d
        default:
            return try kenwoodQuery(for: function).query + d
        }
    }

    /// The read command and the prefix of its reply.
    private func kenwoodQuery(for function: RigFunction) throws -> (query: String, replyPrefix: String) {
        switch function {
        case .compressor: return ("PR", "PR")
        case .vox:        return (levelProfile.voxPrefix, levelProfile.voxPrefix)
        case .ctcssTone:  return ("TO", "TO")
        case .ctcssSquelch: return ("CT", "CT")
        case .lock:       return ("LK", "LK")
        case .tuner:
            return levelProfile.tunerForm == .powerSDR ? ("ZZTU", "ZZTU") : ("AC", "AC")
        case .autoNotch:  return ("NT", "NT")
        case .beatCancel: return ("BC", "BC")
        case .noiseBlanker2: return ("NB2", "NB2")
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
