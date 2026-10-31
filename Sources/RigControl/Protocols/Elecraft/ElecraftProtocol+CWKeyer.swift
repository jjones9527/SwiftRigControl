import Foundation

// MARK: - CW keyer
//
// Hamlib drives the K-series keyer speed through `kenwood_set_level`,
// `KS%03d` (checked on the simulator with Scripts/hamlib-set-matrix.py).
// Hamlib's K2 / K3 / K3S / K4 / KX2 / KX3 caps list no CW pitch or
// break-in level, so those throw unsupportedOperation here.

extension ElecraftProtocol: SupportsCWKeyer {

    public func setCWSpeed(_ speed: CWSpeed) async throws {
        try requireKeyer()
        try await sendSetCommand(String(format: "KS%03d", speed.wpm))
    }

    public func getCWSpeed() async throws -> CWSpeed {
        try requireKeyer()
        try await sendCommand("KS")
        let response = try await receiveResponse()
        guard response.hasPrefix("KS"), let wpm = Int(response.dropFirst(2)) else {
            throw RigError.invalidResponse
        }
        return CWSpeed(wpm: wpm)
    }

    public func setCWPitch(_ pitch: CWPitch) async throws {
        throw RigError.unsupportedOperation("CW pitch is not exposed on Elecraft K-series via this protocol")
    }

    public func getCWPitch() async throws -> CWPitch {
        throw RigError.unsupportedOperation("CW pitch is not exposed on Elecraft K-series via this protocol")
    }

    public func setBreakIn(_ mode: BreakInMode) async throws {
        throw RigError.unsupportedOperation("Break-in is not exposed on Elecraft K-series via this protocol")
    }

    public func getBreakIn() async throws -> BreakInMode {
        throw RigError.unsupportedOperation("Break-in is not exposed on Elecraft K-series via this protocol")
    }

    private func requireKeyer() throws {
        guard capabilities.supportsCWKeyer else {
            throw RigError.unsupportedOperation("CW keyer not supported by this radio")
        }
    }
}
