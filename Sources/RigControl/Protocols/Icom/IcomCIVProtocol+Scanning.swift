import Foundation

// MARK: - Scanning (Phase 4.3)
//
// CI-V command map (cross-checked against Hamlib's
// `rigs/icom/icom_defs.h`):
//
//   C_CTL_SCAN  0x0E   — scan control
//     S_SCAN_STOP   0x00   stop scanning
//     S_SCAN_START  0x01   start (interpreted by current VFO/MEM state)
//     S_SCAN_PROG   0x02   programmed scan
//     S_SCAN_DELTA  0x03   delta-f scan
//
// Note on VFO/MEM state: Hamlib's icom_scan changes the radio's
// VFO/MEM selection before issuing the scan, so that 0x0E 0x01
// "do the right thing" picks up the desired scan kind. We do NOT
// do that — silently changing VFO mode under the user is
// surprising. Callers should `selectVFO` or recall a memory
// channel first if they want a non-default scan mode. The
// capability flags advertise what the radio supports; whether
// the radio is in the right mode to honor it is the caller's
// responsibility.

extension IcomCIVProtocol {

    public func startScan(_ kind: ScanKind) async throws {
        try requireScanSupported(kind)

        // S_SCAN_START (0x01) handles VFO, MEM, SLCT, and PRIO —
        // the radio interprets the bit based on its current
        // VFO/MEM/PRIO mode. PROG and DELTA have dedicated bytes.
        let subCmd: UInt8
        switch kind {
        case .vfo, .memory, .selectedMemory, .priority:
            subCmd = 0x01  // S_SCAN_START
        case .programmed:
            subCmd = 0x02  // S_SCAN_PROG
        case .deltaF:
            subCmd = 0x03  // S_SCAN_DELTA
        }

        let frame = CIVFrame(
            to: civAddress,
            command: [0x0E, subCmd],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected scan start (\(kind))")
        }
    }

    public func stopScan() async throws {
        guard scanIsSupportedAtAll else {
            throw RigError.unsupportedOperation("Scanning not supported by this radio")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x0E, 0x00],  // S_SCAN_STOP
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected scan stop")
        }
    }

    // MARK: - Internal helpers

    /// True if the radio advertises ANY scan kind. Used by
    /// ``stopScan()`` since stopping doesn't pick a specific kind.
    private var scanIsSupportedAtAll: Bool {
        capabilities.supportsVFOScan
            || capabilities.supportsMemoryScan
            || capabilities.supportsSelectedMemoryScan
            || capabilities.supportsPriorityScan
            || capabilities.supportsProgrammedScan
            || capabilities.supportsDeltaFScan
    }

    /// Throws if `kind` is not advertised in capabilities.
    private func requireScanSupported(_ kind: ScanKind) throws {
        let supported: Bool
        switch kind {
        case .vfo:            supported = capabilities.supportsVFOScan
        case .memory:         supported = capabilities.supportsMemoryScan
        case .selectedMemory: supported = capabilities.supportsSelectedMemoryScan
        case .priority:       supported = capabilities.supportsPriorityScan
        case .programmed:     supported = capabilities.supportsProgrammedScan
        case .deltaF:         supported = capabilities.supportsDeltaFScan
        }
        if !supported {
            throw RigError.unsupportedOperation(
                "Scan kind \(kind) not supported by this radio"
            )
        }
    }
}
