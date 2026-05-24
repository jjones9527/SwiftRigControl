import Foundation

// MARK: - VFO operations (v1.1 parity)
//
// Yaesu newcat command map, cross-checked against Hamlib
// `rigs/yaesu/newcat.c::newcat_vfo_op` (lines 7470-7569):
//
//   "AB"  — copy current VFO to other (RIG_OP_CPY).
//             Some models use "VV" instead. We send "AB"; if
//             a future user reports a NAK on a model that
//             needs "VV", switch on `radioModel` here.
//   "SV"  — exchange / toggle A↔B (RIG_OP_XCHG, RIG_OP_TOGGLE).
//   "AM"  — write VFO to current memory channel (FROM_VFO).
//   "MA"  — recall current memory to VFO (TO_VFO).
//   "UP"  — step VFO up.
//   "DN"  — step VFO down.
//   "BU0" — band up (VFO-A on dual-VFO radios).
//   "BD0" — band down (VFO-A).
//   "AC002" — start ATU tune cycle (FT-991/FT-710/FTDX series).
//
// Yaesu does *not* expose memory clear as a single-token op
// (must rewrite the memory) — `.memoryClear` throws.

extension YaesuCATProtocol {

    public func performVFOOperation(_ op: VFOOperation) async throws {
        let command: String

        switch op {
        case .copyVFO:
            command = "AB"
        case .exchange, .toggle:
            command = "SV"
        case .vfoToMemory:
            command = "AM"
        case .memoryToVFO:
            command = "MA"
        case .stepUp:
            command = "UP"
        case .stepDown:
            command = "DN"
        case .bandUp:
            command = "BU0"
        case .bandDown:
            command = "BD0"
        case .tune:
            command = "AC002"
        case .memoryClear:
            throw RigError.unsupportedOperation(
                "VFO operation '\(op.rawValue)' is not a single Yaesu CAT command"
            )
        }

        try await sendCommand(command)
        // Yaesu set commands don't echo (rejected commands return
        // "?;"); trust the wire write.
    }
}
