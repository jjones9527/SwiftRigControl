import Foundation

// MARK: - Antenna selection (Phase 4.4)
//
// CI-V command map (cross-checked against Hamlib's
// `rigs/icom/icom_defs.h` and `icom_set_ant`/`icom_get_ant`):
//
//   C_CTL_ANT  0x12   — antenna selection
//     The "sub-command" position carries the 0-based antenna
//     index (0 = ANT 1, 1 = ANT 2, …). Some radios accept an
//     optional 1-byte payload for RX-only routing; we don't
//     expose that here — it's per-radio quirky and rarely used.
//
// Our public API is 1-based (`selectAntenna(1)` → ANT 1) to
// match how the operator and the Icom front panel refer to the
// jacks. The wire conversion is `byte = index - 1`.

extension IcomCIVProtocol {

    public func selectAntenna(_ index: Int) async throws {
        guard capabilities.antennaCount > 1 else {
            throw RigError.unsupportedOperation("Antenna selection not supported by this radio")
        }
        guard (1...capabilities.antennaCount).contains(index) else {
            throw RigError.invalidParameter(
                "Antenna index \(index) out of range (1...\(capabilities.antennaCount))"
            )
        }
        let antByte = UInt8(index - 1)  // 0-based on the wire
        let frame = CIVFrame(
            to: civAddress,
            command: [0x12, antByte],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected antenna selection (\(index))")
        }
    }

    public func getAntenna() async throws -> Int {
        guard capabilities.antennaCount > 1 else {
            throw RigError.unsupportedOperation("Antenna selection not supported by this radio")
        }
        // Read with no sub-command: the response carries the
        // current antenna as the sub-command byte in the echo.
        let frame = CIVFrame(
            to: civAddress,
            command: [0x12],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2,
              response.command[0] == 0x12 else {
            throw RigError.invalidResponse
        }
        let antByte = response.command[1]
        let index = Int(antByte) + 1  // wire is 0-based, public API is 1-based
        guard (1...capabilities.antennaCount).contains(index) else {
            throw RigError.invalidResponse
        }
        return index
    }
}
