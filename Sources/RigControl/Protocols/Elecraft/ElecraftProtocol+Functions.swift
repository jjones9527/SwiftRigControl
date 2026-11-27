import Foundation

// MARK: - Function toggles (v1.1 parity)
//
// Elecraft K-series command map. Hamlib's `k3_set_func`
// (rigs/kenwood/k3.c:2495-2566) overrides a few of the
// Kenwood-shared functions and adds K-specific ones:
//
//   K3/K4 inherit from kenwood_set_func for COMP/VOX/TONE/TSQL/LOCK
//   K3 specific:
//     "AP" + 0/1     APF (audio peak filter)
//     "SB" + 0/1     SB dual watch (sub receiver)
//     "DV" + 0/1     DV diversity
//   K4 specific:
//     "AG/" / "AG0"  mute
//
// We expose the Kenwood-shared subset plus the K3 overrides;
// model-specific bits stay deferred until `ElecraftProtocol`
// carries a richer per-model identity.

extension ElecraftProtocol {

    public func setFunction(_ function: RigFunction, enabled: Bool) async throws {
        if isK4, function == .audioPeakFilter {
            let state = try await readK4AudioPeakFilter()
            try await sendSetCommand("AP" + (enabled ? "1" : "0") + String(state.bandwidth))
            return
        }
        if isK4, function == .vox {
            let state = try await readK4VOX()
            try await sendSetCommand("VX" + state.mode + (enabled ? "1" : "0"))
            return
        }
        let command = try elecraftCommand(for: function, set: true, enabled: enabled)
        try await sendSetCommand(command)
    }

    public func getFunction(_ function: RigFunction) async throws -> Bool {
        if isK4, function == .audioPeakFilter {
            return try await readK4AudioPeakFilter().enabled
        }
        if isK4, function == .vox {
            return try await readK4VOX().enabled
        }
        let query = try elecraftCommand(for: function, set: false, enabled: false)
        try await sendCommand(query)
        let response = try await receiveResponse()
        guard let last = response.last else {
            throw RigError.invalidResponse
        }
        return last != "0"
    }

    // K4 VX includes the mode group: CW/direct data, voice, or AF data.
    // Read it before setting so the change targets the radio's current group.
    private func readK4VOX() async throws -> (mode: String, enabled: Bool) {
        try await sendCommand("VX")
        let response = try await receiveResponse()
        let fields = Array(response.dropFirst(2))
        guard response.hasPrefix("VX"), fields.count == 2,
              ["C", "V", "D"].contains(String(fields[0])),
              fields[1] == "0" || fields[1] == "1" else {
            throw RigError.invalidResponse
        }
        return (String(fields[0]), fields[1] == "1")
    }

    private func readK4AudioPeakFilter() async throws -> (enabled: Bool, bandwidth: Int) {
        try await sendCommand("AP")
        let response = try await receiveResponse()
        let fields = Array(response.dropFirst(2).utf8)
        guard response.hasPrefix("AP"), fields.count == 2,
              (48...49).contains(fields[0]), (48...50).contains(fields[1]) else {
            throw RigError.invalidResponse
        }
        return (fields[0] == 49, Int(fields[1] - 48))
    }

    private func elecraftCommand(
        for function: RigFunction,
        set: Bool,
        enabled: Bool
    ) throws -> String {
        let digit = enabled ? "1" : "0"

        switch function {
        case .compressor:
            return set ? "PR\(digit)" : "PR"
        case .vox:
            return set ? "VX\(digit)" : "VX"
        case .ctcssTone:
            return set ? "TO\(digit)" : "TO"
        case .ctcssSquelch:
            return set ? "CT\(digit)" : "CT"
        case .lock:
            return set ? "LK\(digit)" : "LK"
        case .audioPeakFilter:
            // K3-specific override of the Kenwood-shared NT.
            return set ? "AP\(digit)" : "AP"
        case .dualWatch:
            return set ? "SB\(digit)" : "SB"
        case .diversity:
            return set ? "DV\(digit)" : "DV"
        case .tuner, .autoNotch, .manualNotch, .satelliteMode,
             .monitor, .autoFrequencyControl, .beatCancel,
             .noiseBlanker2, .voiceSquelch, .reverseSplit,
             .mute, .scope, .scanResume:
            throw RigError.unsupportedOperation(
                "Function '\(function.rawValue)' is not exposed on Elecraft K-series via this protocol"
            )
        }
    }
}
