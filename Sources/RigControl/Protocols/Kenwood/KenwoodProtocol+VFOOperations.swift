import Foundation

// MARK: - VFO operations (v1.1 parity)
//
// Kenwood-text command map, cross-checked against Hamlib
// `rigs/kenwood/kenwood.c::kenwood_vfo_op` (lines 5724-5753):
//
//   "UP"    — step VFO up by configured tuning step
//   "DN"    — step VFO down
//   "BU"    — band up
//   "BD"    — band down
//   "MC"    — memory clear (current channel)
//   "MR"    — memory read (recall current memory to active VFO)
//                Hamlib uses this for RIG_OP_TO_VFO
//   "AC111" — start ATU tune cycle (TS-590S/SG/890S/990S)
//
// Kenwood text protocol does *not* expose VFO copy / exchange /
// from-VFO-to-memory as single tokens — those are sequences of
// FA/FB get/set, not compound ops. We mirror Hamlib's selection
// and throw `.unsupportedOperation` for the rest.

extension KenwoodProtocol {

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
        case .memoryClear:
            command = "MC"
        case .memoryToVFO:
            command = "MR"
        case .tune:
            command = "AC111"
        case .copyVFO, .exchange, .toggle, .vfoToMemory:
            throw RigError.unsupportedOperation(
                "VFO operation '\(op.rawValue)' has no Kenwood text-protocol equivalent"
            )
        }

        try await sendCommand(command)
        // Kenwood set commands don't echo; trust the wire write
        // and move on, matching how setPower / setSplit work in
        // this protocol.
    }
}
