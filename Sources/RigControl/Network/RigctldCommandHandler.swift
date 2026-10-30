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
                // Hamlib reports the receive VFO as the TX VFO when split
                // is off (`kenwood_get_split_vfo`, `icom_get_split_vfo`).
                return .splitVFO(enabled: split, txVFO: split ? "VFOB" : "VFOA", command: command)
            } else {
                return .error(.notSupported, command: command)
            }

        // RIT / XIT. Hamlib's offset of 0 resets the clarifier; we turn
        // it off. `j` / `z` report the offset, 0 when off.
        case .setRIT(let hz):
            try await rigController.setRIT(hz == 0 ? .disabled : RITXITState(enabled: true, offset: hz))
            return .ok(command: command)

        case .getRIT:
            let state = try await rigController.getRIT(cached: false)
            return RigctldResponse(value: String(state.enabled ? state.offset : 0), command: command)

        case .setXIT(let hz):
            try await rigController.setXIT(hz == 0 ? .disabled : RITXITState(enabled: true, offset: hz))
            return .ok(command: command)

        case .getXIT:
            let state = try await rigController.getXIT(cached: false)
            return RigctldResponse(value: String(state.enabled ? state.offset : 0), command: command)

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

    // MARK: - Mode Conversion

    func parseMode(_ modeStr: String) throws -> Mode {
        let normalized = modeStr.uppercased()

        // Hamlib's mode_str[] (misc.c:460-480) also accepts the dashed
        // spellings: CW-R, RTTY-R, LSB-D, USB-D and FM-D. It prints PKTFM
        // as FM-D, so newer clients echo that back. We still print PKTFM,
        // which every Hamlib version parses. AM-D / PKTAM (packet AM) has
        // no Mode case and stays an error.
        switch normalized {
        case "LSB": return .lsb
        case "USB": return .usb
        case "CW", "CWL": return .cw
        case "CWR", "CW-R", "CWU": return .cwR
        case "AM": return .am
        case "AMN", "AM-N": return .amN
        case "FM": return .fm
        case "FMN": return .fmN
        case "WFM": return .wfm
        case "RTTY", "RTTYL": return .rtty
        case "RTTYR", "RTTY-R", "RTTYU": return .rttyR
        case "PKTLSB", "LSB-D", "DATA-LSB", "DATALSB": return .dataLSB
        case "PKTUSB", "USB-D", "DATA-USB", "DATAUSB": return .dataUSB
        case "PKTFM", "FM-D", "DATA-FM", "DATAFM": return .dataFM
        case "PKTFMN", "DATA-FMN", "DATA-FM-N", "DATAFMN": return .dataFMN
        case "C4FM": return .c4fm
        case "D-STAR", "DSTAR", "DV": return .dstar
        default:
            throw RigError.invalidParameter("Unknown mode: \(modeStr)")
        }
    }

    func formatMode(_ mode: Mode) -> String {
        switch mode {
        case .lsb: return "LSB"
        case .usb: return "USB"
        case .cw: return "CW"
        case .cwR: return "CWR"
        case .am: return "AM"
        case .amN: return "AMN"
        case .fm: return "FM"
        case .fmN: return "FMN"
        case .wfm: return "WFM"
        case .rtty: return "RTTY"
        case .rttyR: return "RTTYR"
        case .dataLSB: return "PKTLSB"
        case .dataUSB: return "PKTUSB"
        case .dataFM: return "PKTFM"
        case .dataFMN: return "PKTFMN"
        case .c4fm: return "C4FM"
        case .dstar: return "D-STAR"
        }
    }

    func defaultPassband(for mode: Mode) -> Int {
        // Return typical passband widths for each mode
        switch mode {
        case .lsb, .usb: return 2400
        case .cw, .cwR: return 500
        case .am: return 6000
        case .amN: return 3000
        case .fm: return 15000
        case .fmN: return 10000
        case .wfm: return 150000
        case .rtty, .rttyR: return 500
        case .dataLSB, .dataUSB: return 2400
        case .dataFM: return 15000
        case .dataFMN: return 10000
        case .c4fm: return 12500
        case .dstar: return 6000
        }
    }

    // MARK: - VFO Conversion

    func parseVFO(_ vfoStr: String) throws -> VFO {
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

    // MARK: - Error Mapping

    private func mapRigError(_ error: RigError, command: RigctldCommand) -> RigctldResponse {
        let code: RigctldProtocol.ReturnCode

        // Mapping targets are canonical Hamlib codes.  See
        // `RigctldProtocol.ReturnCode` for the Hamlib symbols each
        // case corresponds to.
        switch error {
        case .notConnected:
            code = .ioError                  // RIG_EIO
        case .timeout:
            code = .timeout                  // RIG_ETIMEOUT
        case .invalidParameter:
            code = .invalidParam             // RIG_EINVAL
        case .commandFailed:
            code = .rejected                 // RIG_ERJCTED
        case .unsupportedOperation:
            code = .notSupported             // RIG_ENAVAIL
        case .invalidResponse:
            code = .protocolError            // RIG_EPROTO
        case .frequencyOutOfRange, .transmitNotAllowed, .modeNotSupported:
            code = .invalidParam             // RIG_EINVAL
        case .unsupportedRadio:
            code = .notSupported             // RIG_ENAVAIL
        case .serialPortError:
            code = .ioError                  // RIG_EIO
        case .busy:
            code = .rejected                 // RIG_ERJCTED
        }

        return .error(code, command: command)
    }

}
