import Foundation

// rigctld `G` (vfo_op), `U` / `u` (set/get func) and `g` (scan) dispatch.
// Split from RigctldCommandHandler.swift to keep it under the 500-line
// soft cap; methods are internal because executeCommand calls them.

extension RigctldCommandHandler {

    // MARK: - VFO operations (v1.1)

    func runVFOOp(op: String, command: RigctldCommand) async throws -> RigctldResponse {
        // Hamlib token → SwiftRigControl `VFOOperation`.
        // Bit names lifted from `rig_strvfo_op` (src/misc.c).
        let token = op.uppercased()
        let mapped: VFOOperation
        switch token {
        case "CPY":         mapped = .copyVFO
        case "XCHG":        mapped = .exchange
        case "TOGGLE":      mapped = .toggle
        case "FROM_VFO":    mapped = .vfoToMemory
        case "TO_VFO":      mapped = .memoryToVFO
        case "MCL":         mapped = .memoryClear
        case "UP":          mapped = .stepUp
        case "DOWN":        mapped = .stepDown
        case "BAND_UP":     mapped = .bandUp
        case "BAND_DOWN":   mapped = .bandDown
        case "TUNE":        mapped = .tune
        default:
            return .error(.invalidParam, command: command)
        }
        try await rigController.performVFOOperation(mapped)
        return .ok(command: command)
    }

    // MARK: - Function toggles (Phase 4.5)

    func setFunc(name: String, enabled: Bool, command: RigctldCommand) async throws -> RigctldResponse {
        let normalized = name.uppercased()
        switch normalized {
        case "SBKIN":
            try await rigController.setBreakIn(enabled ? .semi : .off)
            return .ok(command: command)

        case "FBKIN":
            try await rigController.setBreakIn(enabled ? .full : .off)
            return .ok(command: command)

        // Hamlib RIG_FUNC_NB / RIG_FUNC_NR are on/off switches; the levels
        // are separate (L NB / L NR). Through v1.3.1 these returned
        // RPRT -4. Our NR API couples state and level, so turning NR on
        // from off uses mid-scale; if it is already on nothing is sent.
        case "NB":
            try await rigController.setNoiseBlanker(enabled ? .enabled(level: nil) : .off)
            return .ok(command: command)

        case "NR":
            if !enabled {
                try await rigController.setNoiseReduction(.off)
            } else if case .off = try await rigController.noiseReduction() {
                try await rigController.setNoiseReduction(.enabled(level: 128))
            }
            return .ok(command: command)

        // Hamlib RIG_FUNC_RIT / RIG_FUNC_XIT switch the clarifier on or off
        // and keep its offset (icom.c `S_FUNC_RIT`, newcat `RT` / `XT`).
        // Through v1.3.1 these returned RPRT -4.
        case "RIT":
            let offset = try await currentOffset { try await self.rigController.getRIT(cached: false) }
            try await rigController.setRIT(RITXITState(enabled: enabled, offset: offset))
            return .ok(command: command)

        case "XIT":
            let offset = try await currentOffset { try await self.rigController.getXIT(cached: false) }
            try await rigController.setXIT(RITXITState(enabled: enabled, offset: offset))
            return .ok(command: command)

        default:
            // v1.1: also map the RigFunction enum — Hamlib bit
            // names match our enum's raw values once normalised.
            if let function = mapHamlibFuncBit(normalized) {
                try await rigController.setFunction(function, enabled: enabled)
                return .ok(command: command)
            }
            return .error(.notImplemented, command: command)
        }
    }

    /// The clarifier's current offset, or 0 on radios that can't read it
    /// back (the G90's RIT is set-only, Hamlib `aff6e940`).
    func currentOffset(_ read: () async throws -> RITXITState) async throws -> Int {
        do {
            return try await read().offset
        } catch RigError.unsupportedOperation {
            return 0
        }
    }

    func getFunc(name: String, command: RigctldCommand) async throws -> RigctldResponse {
        let normalized = name.uppercased()
        switch normalized {
        case "SBKIN":
            let mode = try await rigController.breakIn()
            return RigctldResponse(value: mode == .semi ? "1" : "0", command: command)

        case "FBKIN":
            let mode = try await rigController.breakIn()
            return RigctldResponse(value: mode == .full ? "1" : "0", command: command)

        case "NB":
            let on = try await rigController.noiseBlanker() != .off
            return RigctldResponse(value: on ? "1" : "0", command: command)

        case "NR":
            let on = try await rigController.noiseReduction() != .off
            return RigctldResponse(value: on ? "1" : "0", command: command)

        case "RIT":
            let on = try await rigController.getRIT(cached: false).enabled
            return RigctldResponse(value: on ? "1" : "0", command: command)

        case "XIT":
            let on = try await rigController.getXIT(cached: false).enabled
            return RigctldResponse(value: on ? "1" : "0", command: command)

        default:
            if let function = mapHamlibFuncBit(normalized) {
                let on = try await rigController.getFunction(function)
                return RigctldResponse(value: on ? "1" : "0", command: command)
            }
            return .error(.notImplemented, command: command)
        }
    }

    /// Maps a Hamlib `RIG_FUNC_*` token (e.g. "COMP", "VOX",
    /// "LOCK") to our ``RigFunction`` enum. Returns `nil` for
    /// tokens we don't cover (which falls through to
    /// `.notImplemented` for backward compat with the original
    /// Phase 4.5 surface).
    func mapHamlibFuncBit(_ token: String) -> RigFunction? {
        switch token {
        case "COMP":        return .compressor
        case "VOX":         return .vox
        case "TONE":        return .ctcssTone
        case "TSQL":        return .ctcssSquelch
        case "LOCK":        return .lock
        case "TUNER":       return .tuner
        case "ANF":         return .autoNotch
        case "MN":          return .manualNotch
        case "SATMODE":     return .satelliteMode
        case "MON":         return .monitor
        case "AFC":         return .autoFrequencyControl
        case "BC":          return .beatCancel
        case "NB2":         return .noiseBlanker2
        case "APF":         return .audioPeakFilter
        case "REV":         return .reverseSplit
        case "DUAL_WATCH":  return .dualWatch
        case "DIVERSITY":   return .diversity
        case "MUTE":        return .mute
        case "SCOPE":       return .scope
        case "RESUME":      return .scanResume
        case "VSC":         return .voiceSquelch
        default:            return nil
        }
    }

    // MARK: - Scanning (Phase 4.5)

    func runScan(function: String, command: RigctldCommand) async throws -> RigctldResponse {
        let normalized = function.uppercased()
        if normalized == "STOP" {
            try await rigController.stopScan()
            return .ok(command: command)
        }
        let kind: ScanKind
        switch normalized {
        case "VFO":   kind = .vfo
        case "MEM":   kind = .memory
        case "SLCT":  kind = .selectedMemory
        case "PRIO":  kind = .priority
        case "PROG":  kind = .programmed
        case "DELTA": kind = .deltaF
        default:
            return .error(.invalidParam, command: command)
        }
        try await rigController.startScan(kind)
        return .ok(command: command)
    }
}
