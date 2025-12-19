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
    /// The rig controller to execute commands on
    private let rigController: RigController

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
        }
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
        case "WFM": return .wfm
        case "RTTY", "RTTYL": return .rtty
        case "RTTYR", "RTTYU": return .rttyR
        case "PKTLSB", "DATALSB": return .dataLSB
        case "PKTUSB", "DATAUSB": return .dataUSB
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

    // MARK: - Level Control

    /// Set a level value (supports AGC, NB, NR)
    private func setLevel(name: String, value: String, command: RigctldCommand) async throws -> RigctldResponse {
        let normalized = name.uppercased()

        switch normalized {
        case "AGC":
            // Parse AGC value - Hamlib uses numeric codes
            // Map common values: 0=OFF, 1=FAST, 2=MEDIUM/MID, 3=SLOW
            let agcSpeed: AGCSpeed
            switch value {
            case "0", "OFF":
                agcSpeed = .off
            case "1", "FAST":
                agcSpeed = .fast
            case "2", "MID", "MEDIUM":
                agcSpeed = .medium
            case "3", "SLOW":
                agcSpeed = .slow
            case "4", "AUTO":
                agcSpeed = .auto
            default:
                throw RigError.invalidParameter("Invalid AGC value: \(value)")
            }

            try await rigController.setAGC(agcSpeed)
            return .ok(command: command)

        case "NB":
            // Parse NB value - 0=OFF, 1-255=enabled with level
            guard let nbValue = Int(value) else {
                throw RigError.invalidParameter("Invalid NB value: \(value)")
            }

            let nbConfig: NoiseBlanker
            if nbValue == 0 {
                nbConfig = .off
            } else if nbValue >= 1 && nbValue <= 255 {
                nbConfig = .enabled(level: nbValue)
            } else {
                throw RigError.invalidParameter("NB value must be 0-255, got \(nbValue)")
            }

            try await rigController.setNoiseBlanker(nbConfig)
            return .ok(command: command)

        case "NR":
            // Parse NR value - 0=OFF, 1-255=enabled with level
            guard let nrValue = Int(value) else {
                throw RigError.invalidParameter("Invalid NR value: \(value)")
            }

            let nrConfig: NoiseReduction
            if nrValue == 0 {
                nrConfig = .off
            } else if nrValue >= 1 && nrValue <= 255 {
                nrConfig = .enabled(level: nrValue)
            } else {
                throw RigError.invalidParameter("NR value must be 0-255, got \(nrValue)")
            }

            try await rigController.setNoiseReduction(nrConfig)
            return .ok(command: command)

        case "IF", "IFFILTER":
            // Parse IF filter value - 1=FIL1, 2=FIL2, 3=FIL3
            guard let filterNum = Int(value) else {
                throw RigError.invalidParameter("Invalid IF filter value: \(value)")
            }

            guard let filter = IFFilter(rawValue: UInt8(filterNum)) else {
                throw RigError.invalidParameter("IF filter must be 1, 2, or 3, got \(filterNum)")
            }

            try await rigController.setIFFilter(filter)
            return .ok(command: command)

        default:
            return .error(.notImplemented, command: command)
        }
    }

    /// Get a level value (supports AGC, NB, NR, IF filter)
    private func getLevel(name: String, command: RigctldCommand) async throws -> RigctldResponse {
        let normalized = name.uppercased()

        switch normalized {
        case "AGC":
            let agc = try await rigController.agc()
            // Map AGCSpeed to numeric value for Hamlib compatibility
            let value: String
            switch agc {
            case .off: value = "0"
            case .fast: value = "1"
            case .medium: value = "2"
            case .slow: value = "3"
            case .auto: value = "4"
            }
            return RigctldResponse(value: value, command: command)

        case "NB":
            let nb = try await rigController.noiseBlanker()
            // Map NoiseBlanker to numeric value: 0=OFF, 1-255=level
            let value: String
            switch nb {
            case .off:
                value = "0"
            case .enabled(let level):
                value = String(level ?? 1)  // Default to 1 if no level
            }
            return RigctldResponse(value: value, command: command)

        case "NR":
            let nr = try await rigController.noiseReduction()
            // Map NoiseReduction to numeric value: 0=OFF, 1-255=level
            let value: String
            switch nr {
            case .off:
                value = "0"
            case .enabled(let level):
                value = String(level)
            }
            return RigctldResponse(value: value, command: command)

        case "IF", "IFFILTER":
            let filter = try await rigController.ifFilter()
            // Map IFFilter to numeric value: 1=FIL1, 2=FIL2, 3=FIL3
            let value = String(filter.rawValue)
            return RigctldResponse(value: value, command: command)

        default:
            return .error(.notImplemented, command: command)
        }
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

        return RigctldResponse(data: lines, command: .dumpCapabilities)
    }

    private func dumpState() async -> RigctldResponse {
        var lines: [String] = []

        let caps = await rigController.capabilities

        // Protocol version
        lines.append("0")  // Protocol version

        // Rig model
        lines.append("2")  // Model number (NET rigctl)

        // ITU region
        lines.append("1")  // ITU region 1

        // Frequency range
        if let freqRange = caps.frequencyRange {
            lines.append("\(freqRange.min) \(freqRange.max) 0x\(String(0x1ff, radix: 16)) -1 -1 0x\(String(0x03, radix: 16)) 0x\(String(0x03, radix: 16))")
        } else if let firstRange = caps.detailedFrequencyRanges.first {
            lines.append("\(firstRange.min) \(firstRange.max) 0x\(String(0x1ff, radix: 16)) -1 -1 0x\(String(0x03, radix: 16)) 0x\(String(0x03, radix: 16))")
        }

        // End marker
        lines.append("0 0 0 0 0 0 0")

        // VFO list
        if caps.hasVFOB {
            lines.append("VFOA VFOB")
        } else {
            lines.append("VFOA")
        }

        return RigctldResponse(data: lines, command: .dumpState)
    }
}
