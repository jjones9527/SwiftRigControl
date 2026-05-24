import Foundation

// MARK: - VFO operations (v1.1 parity)
//
// Elecraft K-series command map. Hamlib falls through to
// `kenwood_vfo_op` for most ops (rigs/kenwood/k3.c) and only
// overrides TUNE per model:
//
//   K2     no SWT-based TUNE (uses the AUX/KAT button physically)
//   K3/K3S "SWT19"
//   KX2    "SWT20"
//   KX3    "SWT44"
//   K4     "SWH40"
//
// SwiftRigControl doesn't currently model which K-variant the
// connected radio is at the protocol level (the `isK2` flag is
// the only discriminator), so we expose only the Kenwood-shared
// ops here. The model-specific TUNE codes are a follow-on once
// `ElecraftProtocol` carries a richer model identity.

extension ElecraftProtocol {

    public func performVFOOperation(_ op: VFOOperation) async throws {
        let command: String

        switch op {
        case .stepUp:
            command = "UP"
        case .stepDown:
            command = "DN"
        case .bandUp:
            command = "BU"
        case .bandDown:
            command = "BD"
        case .memoryToVFO:
            command = "MR"
        case .copyVFO, .exchange, .toggle,
             .vfoToMemory, .memoryClear, .tune:
            throw RigError.unsupportedOperation(
                "VFO operation '\(op.rawValue)' is not a single Elecraft command in this protocol"
            )
        }

        try await sendCommand(command)
        if !isK2 {
            // Newer Elecrafts echo set commands the same way as
            // setMode / setFrequency. Drain the echo so the next
            // command sees a clean state.
            _ = try? await receiveResponse()
        }
    }
}
