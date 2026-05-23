import Foundation

// MARK: - Antenna selection (Phase 4.4)
//
// Elecraft CAT wire format (cross-checked against Hamlib's
// `kenwood_set_ant` / `kenwood_get_ant` — Elecraft K-series use
// the Kenwood-derived `AN` command):
//
//   K2  with KAT-2 / K2/100 with external tuner:  `AN<n>;` /
//   `AN;` for query. `<n>` is the ASCII digit '1' or '2'.
//   K3/K3S/K4: `AN<n>99;` (same prefix, longer payload —
//   currently we ship the short K2 form since the K2 is our
//   only hardware-verified Elecraft).
//
// The KAT-2 internal tuner (K2) and the KAT100 external tuner
// (K2/100) are required for antenna selection on the K2.
// Without them, the radio either ignores the AN command or
// returns an error. Our capability flag (`antennaCount: 2` on
// the K2 definition) advertises potential support; callers
// without the tuner installed will see `commandFailed` at
// runtime. This matches Hamlib's `K2_ANTS = RIG_ANT_1|RIG_ANT_2`
// posture.

extension ElecraftProtocol {

    public func selectAntenna(_ index: Int) async throws {
        guard capabilities.antennaCount > 1 else {
            throw RigError.unsupportedOperation("Antenna selection not supported by this radio")
        }
        guard (1...capabilities.antennaCount).contains(index) else {
            throw RigError.invalidParameter(
                "Antenna index \(index) out of range (1...\(capabilities.antennaCount))"
            )
        }
        // K2: `AN<n>;`. Longer forms used by K3/K4 are not yet
        // ship-supported because we don't have hardware to verify
        // against; when added, branch on isK2.
        let command = "AN\(index)"
        try await sendCommand(command)
        // K2 SET commands don't echo (per existing protocol notes
        // in setPower for K2), so we don't wait for an ACK on the
        // K2 path. For other K-series (when added) the existing
        // ElecraftProtocol pattern is `_ = try await receiveResponse()`.
        if !isK2 {
            _ = try await receiveResponse()
        }
    }

    public func getAntenna() async throws -> Int {
        guard capabilities.antennaCount > 1 else {
            throw RigError.unsupportedOperation("Antenna selection not supported by this radio")
        }
        try await sendCommand("AN")
        let response = try await receiveResponse()
        // Response: `AN<n>;`. Strip the prefix; parse one ASCII digit.
        guard response.hasPrefix("AN"),
              let antChar = response.dropFirst(2).first,
              let antDigit = antChar.wholeNumberValue,
              (1...capabilities.antennaCount).contains(antDigit) else {
            throw RigError.invalidResponse
        }
        return antDigit
    }
}
