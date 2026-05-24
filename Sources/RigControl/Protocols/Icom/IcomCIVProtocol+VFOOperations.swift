import Foundation

// MARK: - VFO operations (v1.1 parity)
//
// CI-V command map, cross-checked against Hamlib `icom.c::icom_vfo_op`
// (rigs/icom/icom.c:8710-8800) and `icom_defs.h`:
//
//   0x07 (C_SET_VFO) sub-commands:
//     0xA0 = S_BTOA   — copy active VFO to other (CPY)
//     0xB0 = S_XCHNG  — exchange A↔B
//     0xC0/C1/C2     — dual-watch on/off; not a VFO op for us
//
//   0x09 (C_WR_MEM)              — write VFO to current memory channel (FROM_VFO)
//   0x0A (C_MEM2VFO)             — recall current memory to VFO  (TO_VFO)
//   0x0B (C_CLR_MEM)             — clear current memory channel  (MCL)
//
//   0x1C (C_CTL_PTT) 0x01 (S_ANT_TUN) + 0x02 — start ATU tune (TUNE)
//
// Hamlib does not implement UP/DOWN/BAND_UP/BAND_DOWN/LEFT/RIGHT/
// TOGGLE for Icom (no CI-V wire equivalent). We follow suit —
// callers that need band navigation should set frequency directly.

extension IcomCIVProtocol {

    public func performVFOOperation(_ op: VFOOperation) async throws {
        let command: [UInt8]

        switch op {
        case .copyVFO:
            command = [0x07, 0xA0]
        case .exchange, .toggle:
            // Icom exposes only XCHG (0x07 0xB0); .toggle aliases
            // to XCHG since most user UIs treat them as the same
            // button. Radios that distinguish (none in our set)
            // would override.
            command = [0x07, 0xB0]
        case .vfoToMemory:
            command = [0x09]
        case .memoryToVFO:
            command = [0x0A]
        case .memoryClear:
            command = [0x0B]
        case .tune:
            // 0x1C 0x01 + data=0x02 (start tuning cycle)
            let frame = CIVFrame(to: civAddress, command: [0x1C, 0x01], data: [0x02])
            try await sendFrame(frame)
            let response = try await receiveFrame()
            guard response.isAck else {
                throw RigError.commandFailed("Radio rejected ATU tune")
            }
            return
        case .stepUp, .stepDown, .bandUp, .bandDown:
            throw RigError.unsupportedOperation(
                "VFO operation '\(op.rawValue)' has no Icom CI-V equivalent"
            )
        }

        let frame = CIVFrame(to: civAddress, command: command, data: [])
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed(
                "Radio rejected VFO operation '\(op.rawValue)'"
            )
        }
    }
}
