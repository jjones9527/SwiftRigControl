import Foundation

/// Handles rigctld commands by executing them on a RigController.
///
/// This actor bridges the rigctld protocol to SwiftRigControl's RigController,
/// translating protocol commands into rig operations and formatting responses.
///
/// ## Usage
/// ```swift
/// let handler = RigctldCommandHandler(rigController: rig)
/// let response = await handler.handle(.getFrequency)
/// ```
public actor RigctldCommandHandler {
    /// The rig controller to execute commands on. Module-visible
    /// (not `private`) so extension files in the same module —
    /// e.g. `RigctldCommandHandler+LevelControl.swift` — can reach
    /// it.
    let rigController: RigController

    /// Initialize with a rig controller
    ///
    /// - Parameter rigController: The rig controller to execute commands on
    public init(rigController: RigController) {
        self.rigController = rigController
    }

    /// Handle a rigctld command
    ///
    /// - Parameter command: The command to execute
    /// - Returns: Response for the command
    public func handle(_ command: RigctldCommand) async -> RigctldResponse {
        do {
            return try await executeCommand(command)
        } catch let error as RigError {
            return mapRigError(error, command: command)
        } catch {
            return .error(.internalError, command: command)
        }
    }

    // MARK: - Command Execution

    private func executeCommand(_ command: RigctldCommand) async throws -> RigctldResponse {
        switch command {
        // Frequency control
        case .setFrequency(let hz):
            try await rigController.setFrequency(hz, vfo: .a)
            return .ok(command: command)

        case .getFrequency:
            let freq = try await rigController.frequency(vfo: .a, cached: false)
            return .frequency(freq, command: command)

        // Mode control
        case .setMode(let modeStr, _):
            let mode = try parseMode(modeStr)
            try await rigController.setMode(mode, vfo: .a)
            return .ok(command: command)

        case .getMode:
            let mode = try await rigController.mode(vfo: .a, cached: false)
            let passband = defaultPassband(for: mode)
            return .mode(formatMode(mode), passband: passband, command: command)

        // VFO control
        case .setVFO(let vfoStr):
            let vfo = try parseVFO(vfoStr)
            try await rigController.selectVFO(vfo)
            return .ok(command: command)

        case .getVFO:
            // SwiftRigControl doesn't track current VFO, default to VFOA
            return .vfo("VFOA", command: command)

        // PTT control
        case .setPTT(let enabled):
            try await rigController.setPTT(enabled)
            return .ok(command: command)

        case .getPTT:
            let ptt = try await rigController.isPTTEnabled()
            return .ptt(ptt, command: command)

        // Split operation
        case .setSplitVFO(let enabled, _):
            let caps = await rigController.capabilities
            if caps.hasSplit {
                try await rigController.setSplit(enabled)
                return .ok(command: command)
            } else {
                return .error(.notSupported, command: command)
            }

        case .getSplitVFO:
            let caps = await rigController.capabilities
            if caps.hasSplit {
                let split = try await rigController.isSplitEnabled()
                return .splitVFO(enabled: split, txVFO: "VFOB", command: command)
            } else {
                return .error(.notSupported, command: command)
            }

        case .setSplitFrequency(let hz):
            let caps = await rigController.capabilities
            if caps.hasSplit {
                try await rigController.setFrequency(hz, vfo: .b)
                return .ok(command: command)
            } else {
                return .error(.notSupported, command: command)
            }

        case .getSplitFrequency:
            let caps = await rigController.capabilities
            if caps.hasSplit {
                let freq = try await rigController.frequency(vfo: .b, cached: false)
                return .frequency(freq, command: command)
            } else {
                return .error(.notSupported, command: command)
            }

        case .setSplitMode(let modeStr, _):
            let caps = await rigController.capabilities
            if caps.hasSplit {
                let mode = try parseMode(modeStr)
                try await rigController.setMode(mode, vfo: .b)
                return .ok(command: command)
            } else {
                return .error(.notSupported, command: command)
            }

        case .getSplitMode:
            let caps = await rigController.capabilities
            if caps.hasSplit {
                let mode = try await rigController.mode(vfo: .b, cached: false)
                let passband = defaultPassband(for: mode)
                return .mode(formatMode(mode), passband: passband, command: command)
            } else {
                return .error(.notSupported, command: command)
            }

        // Power conversion
        case .power2mW(let power, _, _):
            // Convert normalized power (0.0-1.0) to milliwatts
            let caps = await rigController.capabilities
            let watts = Int(power * Double(caps.maxPower))
            let milliwatts = watts * 1000
            return RigctldResponse(value: String(milliwatts), command: command)

        case .mW2power(let powerMW, _, _):
            // Convert milliwatts to normalized power (0.0-1.0)
            let caps = await rigController.capabilities
            let watts = Double(powerMW) / 1000.0
            let normalized = watts / Double(caps.maxPower)
            let clamped = min(max(normalized, 0.0), 1.0)
            return RigctldResponse(value: String(format: "%.6f", clamped), command: command)

        // Level commands
        case .setLevel(let name, let value):
            return try await setLevel(name: name, value: value, command: command)

        case .getLevel(let name):
            return try await getLevel(name: name, command: command)

        // Power state
        case .setPowerStat(let on):
            try await rigController.setPowerState(on)
            return .ok(command: command)

        case .getPowerStat:
            let on = try await rigController.getPowerState()
            return RigctldResponse(value: on ? "1" : "0", command: command)

        // Information commands
        case .dumpCapabilities:
            return await dumpCapabilities()

        case .dumpState:
            return await dumpState()

        case .checkVFO:
            // SwiftRigControl always uses VFO mode
            return RigctldResponse(value: "1", command: command)

        // Protocol control
        case .setExtendedResponse:
            // This is handled at the session level, not here
            return .ok(command: command)

        case .quit:
            // This is handled at the session level
            return .ok(command: command)

        // Function toggles (Phase 4.5)
        case .setFunc(let name, let enabled):
            return try await setFunc(name: name, enabled: enabled, command: command)

        case .getFunc(let name):
            return try await getFunc(name: name, command: command)

        // Antenna selection (Phase 4.5)
        case .setAntenna(let antenna, _):
            // The optional `option` arg carries per-radio quirks
            // (RX-only routing on some radios) that we don't model.
            try await rigController.selectAntenna(antenna)
            return .ok(command: command)

        case .getAntenna(_):
            // Hamlib's get_ant returns four fields:
            //   <AntCurr> <Option> <AntTx> <AntRx>
            // We populate AntCurr from the radio and set the rest
            // to 0/AntCurr — sufficient for clients that care only
            // about the active antenna.
            let ant = try await rigController.antenna()
            let line = "\(ant)\n0\n\(ant)\n\(ant)"
            return RigctldResponse(value: line, command: command)

        // Scanning (Phase 4.5)
        case .scan(let function, _):
            // `channel` is parsed but ignored — CATProtocol.startScan
            // doesn't model per-call scan channels.
            return try await runScan(function: function, command: command)

        // CW (Phase 4.5)
        case .sendMorse(let text):
            try await rigController.sendCW(text)
            return .ok(command: command)

        case .stopMorse:
            try await rigController.stopCW()
            return .ok(command: command)

        // VFO operations (v1.1)
        case .vfoOp(let op):
            return try await runVFOOp(op: op, command: command)
        }
    }

    // MARK: - VFO operations (v1.1)

    private func runVFOOp(op: String, command: RigctldCommand) async throws -> RigctldResponse {
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

    // MARK: - Mode Conversion

    private func parseMode(_ modeStr: String) throws -> Mode {
        let normalized = modeStr.uppercased()

        switch normalized {
        case "LSB": return .lsb
        case "USB": return .usb
        case "CW", "CWL": return .cw
        case "CWR", "CWU": return .cwR
        case "AM": return .am
        case "FM": return .fm
        case "FMN": return .fmN
        case "WFM": return .wfm
        case "RTTY", "RTTYL": return .rtty
        case "RTTYR", "RTTYU": return .rttyR
        case "PKTLSB", "DATA-LSB", "DATALSB": return .dataLSB
        case "PKTUSB", "DATA-USB", "DATAUSB": return .dataUSB
        case "PKTFM", "DATA-FM", "DATAFM": return .dataFM
        default:
            throw RigError.invalidParameter("Unknown mode: \(modeStr)")
        }
    }

    private func formatMode(_ mode: Mode) -> String {
        switch mode {
        case .lsb: return "LSB"
        case .usb: return "USB"
        case .cw: return "CW"
        case .cwR: return "CWR"
        case .am: return "AM"
        case .fm: return "FM"
        case .fmN: return "FMN"
        case .wfm: return "WFM"
        case .rtty: return "RTTY"
        case .rttyR: return "RTTYR"
        case .dataLSB: return "PKTLSB"
        case .dataUSB: return "PKTUSB"
        case .dataFM: return "PKTFM"
        }
    }

    private func defaultPassband(for mode: Mode) -> Int {
        // Return typical passband widths for each mode
        switch mode {
        case .lsb, .usb: return 2400
        case .cw, .cwR: return 500
        case .am: return 6000
        case .fm: return 15000
        case .fmN: return 10000
        case .wfm: return 150000
        case .rtty, .rttyR: return 500
        case .dataLSB, .dataUSB: return 2400
        case .dataFM: return 15000
        }
    }

    // MARK: - VFO Conversion

    private func parseVFO(_ vfoStr: String) throws -> VFO {
        let normalized = vfoStr.uppercased()

        switch normalized {
        case "VFOA", "A": return .a
        case "VFOB", "B": return .b
        case "MAIN": return .main
        case "SUB": return .sub
        default:
            throw RigError.invalidParameter("Unknown VFO: \(vfoStr)")
        }
    }

    // MARK: - Function toggles (Phase 4.5)

    private func setFunc(name: String, enabled: Bool, command: RigctldCommand) async throws -> RigctldResponse {
        let normalized = name.uppercased()
        switch normalized {
        case "SBKIN":
            try await rigController.setBreakIn(enabled ? .semi : .off)
            return .ok(command: command)

        case "FBKIN":
            try await rigController.setBreakIn(enabled ? .full : .off)
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

    private func getFunc(name: String, command: RigctldCommand) async throws -> RigctldResponse {
        let normalized = name.uppercased()
        switch normalized {
        case "SBKIN":
            let mode = try await rigController.breakIn()
            return RigctldResponse(value: mode == .semi ? "1" : "0", command: command)

        case "FBKIN":
            let mode = try await rigController.breakIn()
            return RigctldResponse(value: mode == .full ? "1" : "0", command: command)

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
    private func mapHamlibFuncBit(_ token: String) -> RigFunction? {
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

    private func runScan(function: String, command: RigctldCommand) async throws -> RigctldResponse {
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

    // MARK: - Error Mapping

    private func mapRigError(_ error: RigError, command: RigctldCommand) -> RigctldResponse {
        let code: RigctldProtocol.ReturnCode

        switch error {
        case .notConnected:
            code = .communicationError
        case .timeout:
            code = .timeout
        case .invalidParameter:
            code = .invalidParam
        case .commandFailed:
            code = .rejected
        case .unsupportedOperation:
            code = .notSupported
        case .invalidResponse:
            code = .protocolError
        case .frequencyOutOfRange, .transmitNotAllowed, .modeNotSupported:
            code = .invalidParam
        case .unsupportedRadio:
            code = .notSupported
        case .serialPortError:
            code = .communicationError
        case .busy:
            code = .rejected
        }

        return .error(code, command: command)
    }

    // MARK: - Information Commands

    private func dumpCapabilities() async -> RigctldResponse {
        var lines: [String] = []

        let name = await rigController.radioName
        let caps = await rigController.capabilities

        lines.append("Caps dump for model: \(name)")
        lines.append("Model name: \(name)")
        lines.append("Mfg name: SwiftRigControl")
        lines.append("Backend: SwiftRigControl")
        lines.append("Rig type: Transceiver")
        lines.append("PTT type: RIG")
        lines.append("Has priv data: 1")

        // Frequency ranges
        lines.append("Freq range:")
        if let freqRange = caps.frequencyRange {
            lines.append("  \(freqRange.min)-\(freqRange.max) Hz")
        } else if let firstRange = caps.detailedFrequencyRanges.first {
            lines.append("  \(firstRange.min)-\(firstRange.max) Hz")
        }

        // Modes
        lines.append("Modes:")
        for mode in caps.supportedModes {
            lines.append("  \(formatMode(mode))")
        }

        // VFO operations
        lines.append("VFO ops: TOGGLE COPY")
        if caps.hasSplit {
            lines.append("Split: Yes")
        }

        // Power
        if caps.powerControl {
            lines.append("Max power: \(caps.maxPower) W")
        }

        // Level capabilities
        lines.append("Has set level: AF RF SQL PREAMP ATT RFPOWER AGC NB NR IF")
        lines.append("Has get level: AF RF SQL PREAMP ATT RFPOWER AGC NB NR IF")
        lines.append("Has set powerstat: Yes")

        return RigctldResponse(data: lines, command: .dumpCapabilities)
    }

    /// Emit the canonical Hamlib `\dump_state` payload.
    ///
    /// This is the wire format `netrigctl_open()` (in Hamlib's
    /// `rigs/dummy/netrigctl.c`) parses positionally with a fixed
    /// sequence of `read_string(..., "\n", ...)` + `num_sscanf`
    /// calls. Any missing or malformed line bails the client with
    /// `-8 Protocol error`, which is what MacWinlink beta37 saw
    /// when Direwolf's `PTT RIG 2` path (netrigctl backend) pointed
    /// at our embedded server (jjones9527/macwinlink-releases#54).
    ///
    /// Format (Hamlib `rigctl_parse.c:4685` `dump_state` +
    /// `netrigctl.c:249` `netrigctl_open`):
    /// ```
    /// <protocol_version>
    /// <rig_model>
    /// <itu_region>
    /// <rx_range_1>        // one per RX slot, up to HAMLIB_FRQRANGESIZ
    /// ...
    /// 0 0 0 0 0 0 0       // RX range terminator
    /// <tx_range_1>        // one per TX slot
    /// ...
    /// 0 0 0 0 0 0 0       // TX range terminator
    /// <tuning_step_1>     // one per step, up to HAMLIB_TSLSTSIZ
    /// ...
    /// 0 0                 // TS terminator
    /// <filter_1>          // one per filter, up to HAMLIB_FLTLSTSIZ
    /// ...
    /// 0 0                 // filter terminator
    /// <max_rit>
    /// <max_xit>
    /// <max_ifshift>
    /// <announces>
    /// <preamp values, space-separated, blank if none>
    /// <attenuator values, space-separated, blank if none>
    /// <has_get_func hex>
    /// <has_set_func hex>
    /// <has_get_level hex>
    /// <has_set_level hex>
    /// <has_get_parm hex>
    /// <has_set_parm hex>
    /// ```
    /// Where per-radio data isn't modeled by our capabilities, we
    /// emit safe conservative defaults that netrigctl_open accepts.
    /// The goal is a parseable handshake, not exhaustive capability
    /// accuracy — that lives in `\dump_caps`.
    private func dumpState() async -> RigctldResponse {
        var lines: [String] = []
        let caps = await rigController.capabilities

        // Protocol version + model + (deprecated) ITU region.
        // Hamlib `rigctl_parse.c:4696` uses `RIGCTLD_PROT_VER = 1`;
        // matching that unlocks the "protocol 1" `setting=value`
        // extension section. netrigctl reads the deprecated region
        // field but never uses it — real Hamlib emits `0` for
        // backward compat (see `rigctl_parse.c:4702`).
        lines.append("1")                                        // protocol version
        lines.append("2")                                        // rig_model = NETRIGCTL
        lines.append("0")                                        // deprecated ITU region

        // ---- RX frequency ranges + terminator ----
        // Line format (from `rigctl_parse.c:4708`):
        //   <startf> <endf> <modes-mask-hex> <low_power> <high_power>
        //   <vfo-mask-hex> <ant-mask-hex>
        // netrigctl parses 7 fields via `num_sscanf`
        // (`netrigctl.c:334`); anything less kills `-RIG_EPROTO`.
        //
        // The modes mask is a bitmask of Hamlib's `RIG_MODE_*`
        // values. We emit `0x1ff` (LSB|USB|CW|CWR|AM|FM|RTTY|RTTYR|WFM)
        // as a reasonable HF+VHF/UHF superset — netrigctl only uses
        // it to seed `rs->mode_list`, and the real rig-side
        // `\get_mode` still tells the truth. `-1 / -1` = don't-care
        // power window (netrigctl treats -1 as "unknown"). `0x03`
        // for both VFO and antenna masks = "both VFOs, both
        // antennas" — inert defaults that don't lock behavior.
        let modesMask = "0x1ff"
        let vfoMask = "0x3"
        let antMask = "0x3"

        // If we have detailed ranges, use them (each becomes a slot);
        // else fall back to the coarse `frequencyRange`; else emit no
        // RX ranges at all (immediate terminator — allowed but
        // unusual).
        let rxRanges = rxFrequencyRanges(caps: caps)
        for range in rxRanges {
            lines.append("\(range.startHz) \(range.endHz) \(modesMask) -1 -1 \(vfoMask) \(antMask)")
        }
        lines.append("0 0 0 0 0 0 0")                            // RX terminator

        // ---- TX frequency ranges + terminator ----
        // For TX we filter to ranges the radio can transmit on.
        // Users of `.detailedFrequencyRanges` mark this per-band
        // (some HF radios are RX-only above 30 MHz); users of the
        // coarse `frequencyRange` fall through to "TX = RX" which
        // matches what netrigctl expected before per-band TX
        // policy existed.
        let txRanges = txFrequencyRanges(caps: caps, fallback: rxRanges)
        let lowPower: Int
        let highPower: Int
        if caps.powerControl {
            // Hamlib expresses power in milliwatts. `.watts(max:)`
            // gives us watts; `.percentage` radios (all Icoms) have
            // no absolute watt figure — the coarse `caps.maxPower`
            // is the best we've got (typically 100).
            lowPower = 1_000                                     // conservative 1W floor
            highPower = max(caps.maxPower, 1) * 1_000
        } else {
            lowPower = -1
            highPower = -1
        }
        for range in txRanges {
            lines.append("\(range.startHz) \(range.endHz) \(modesMask) \(lowPower) \(highPower) \(vfoMask) \(antMask)")
        }
        lines.append("0 0 0 0 0 0 0")                            // TX terminator

        // ---- Tuning steps + terminator ----
        // Line format: `<modes-mask-hex> <step-hz>`. Real rigs
        // enumerate every per-mode step; we emit a single "any
        // mode, any step" slot (Hamlib convention: modes-mask
        // covers all, step = 1 Hz) plus terminator. netrigctl
        // never enforces the step against `set_freq` — it just
        // needs the sequence to parse.
        if caps.availableTuningSteps.isEmpty {
            lines.append("\(modesMask) 1")
        } else {
            for step in caps.availableTuningSteps {
                lines.append("\(modesMask) \(Int(step))")
            }
        }
        lines.append("0 0")                                      // TS terminator

        // ---- Filter widths + terminator ----
        // Same shape as tuning steps: `<modes-mask-hex> <width-hz>`.
        // We emit two typical widths — 3 kHz "wide" (SSB/AM) and
        // 500 Hz "narrow" (CW/RTTY) — under the all-modes mask
        // plus terminator. Matches what the Dummy rig emits.
        lines.append("\(modesMask) 3000")
        lines.append("\(modesMask) 500")
        lines.append("0 0")                                      // filter terminator

        // ---- Scalar limits ----
        // We don't model these per-radio yet. Zero is the "no
        // capability" sentinel that netrigctl accepts and that
        // reflects our current runtime behavior (no RIT/XIT/IF
        // shift levers exposed through CATProtocol).
        lines.append("0")                                        // max_rit
        lines.append("0")                                        // max_xit
        lines.append("0")                                        // max_ifshift

        // Announces bitmask. Hamlib `RIG_ANN_NONE = 0`.
        lines.append("0")                                        // announces

        // Preamp / attenuator lists. Space-separated, terminated
        // implicitly by end-of-line (netrigctl `sscanf(..., %d %d
        // ...)` accepts blank → 0 slots).
        lines.append("")                                         // preamp list
        lines.append("")                                         // attenuator list

        // ---- Function / level / parm bitmasks ----
        // netrigctl parses each with `strtoll(buf, NULL, 0)` — any
        // hex or decimal integer works. We advertise the level bits
        // we actually implement in `RigctldCommandHandler` and
        // leave the rest at zero. The exact numeric values here
        // mirror the Hamlib `RIG_LEVEL_*` / `RIG_FUNC_*` bit
        // positions, but netrigctl treats them as opaque flags for
        // its own advertise-what-you-support probing.
        //
        // Values chosen:
        //   has_get_func / has_set_func:
        //     RIG_FUNC_TUNER (1<<12) = 0x1000 — safe superset
        //     covering the compressor/VOX/lock/tuner surface we
        //     expose. Real per-radio filtering happens inside
        //     `handle(.setFunc/.getFunc)`.
        //   has_get_level / has_set_level:
        //     A conservative constant that includes the levels our
        //     `RigctldCommandHandler+LevelControl.swift` handles
        //     (AF, RF, SQL, RFPOWER, AGC, PREAMP, ATT, IF, NR, NB,
        //     RAWSTR, STRENGTH, KEYSPD, CWPITCH, MICGAIN). Exact
        //     bits documented at `hamlib/include/hamlib/rig.h`
        //     `RIG_LEVEL_*`.
        //   has_get_parm / has_set_parm: 0 — we expose no `\get_parm`
        //     / `\set_parm` surface.
        lines.append("0x1000")                                   // has_get_func
        lines.append("0x1000")                                   // has_set_func
        lines.append("0xffffffff")                               // has_get_level
        lines.append("0xffffffff")                               // has_set_level
        lines.append("0")                                        // has_get_parm
        lines.append("0")                                        // has_set_parm

        // Protocol 1 extension: `setting=value` lines terminated
        // by a `done` line. netrigctl skips these for `prot_ver == 0`
        // (see `netrigctl.c:628`); we advertise protocol 1 above,
        // so include the useful bits Direwolf/WSJT-X/JS8Call may
        // probe. `chk_vfo_executed` gating on the Hamlib side means
        // these are always safe to emit — the client either uses
        // them (protocol 1) or ignores them (protocol 0, but we
        // never claim that).
        let hasSetVFO = caps.hasVFOB ? 1 : 0
        lines.append("vfo_ops=0x0")
        lines.append("ptt_type=0x1")                             // RIG_PTT_RIG
        lines.append("targetable_vfo=0x0")
        lines.append("has_set_vfo=\(hasSetVFO)")
        lines.append("has_get_vfo=\(hasSetVFO)")
        lines.append("has_set_freq=1")
        lines.append("has_get_freq=1")
        lines.append("has_set_conf=0")
        lines.append("has_get_conf=0")
        lines.append("has_power2mW=1")
        lines.append("has_mW2power=1")
        lines.append("has_get_ant=1")
        lines.append("has_set_ant=1")
        lines.append("timeout=1000")                             // ms; matches Hamlib default
        lines.append("rig_model=2")
        lines.append("done")

        return RigctldResponse(data: lines, command: .dumpState, suppressRPRTTrailer: true)
    }

    /// Compact wire representation of a frequency slot.
    private struct FreqSlot {
        let startHz: UInt64
        let endHz: UInt64
    }

    private func rxFrequencyRanges(caps: RigCapabilities) -> [FreqSlot] {
        if !caps.detailedFrequencyRanges.isEmpty {
            return caps.detailedFrequencyRanges.map { FreqSlot(startHz: $0.min, endHz: $0.max) }
        }
        if let range = caps.frequencyRange {
            return [FreqSlot(startHz: range.min, endHz: range.max)]
        }
        return []
    }

    private func txFrequencyRanges(caps: RigCapabilities, fallback: [FreqSlot]) -> [FreqSlot] {
        if !caps.detailedFrequencyRanges.isEmpty {
            let tx = caps.detailedFrequencyRanges
                .filter(\.canTransmit)
                .map { FreqSlot(startHz: $0.min, endHz: $0.max) }
            return tx.isEmpty ? fallback : tx
        }
        return fallback
    }
}
