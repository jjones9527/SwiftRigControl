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
        let command = try elecraftCommand(for: function, set: true, enabled: enabled)
        try await sendCommand(command)
        if !isK2 {
            // Drain the echo on K3+ — set commands are echoed.
            _ = try? await receiveResponse()
        }
    }

    public func getFunction(_ function: RigFunction) async throws -> Bool {
        let query = try elecraftCommand(for: function, set: false, enabled: false)
        try await sendCommand(query)
        let response = try await receiveResponse()
        guard let last = response.last else {
            throw RigError.invalidResponse
        }
        return last != "0"
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
