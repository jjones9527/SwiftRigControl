import Foundation

/// Native FlexRadio SmartSDR TCP protocol for one slice receiver.
///
/// SmartSDR listens on TCP port 4992 and uses newline-delimited messages:
/// commands are `C<sequence>|<command>`, replies are `R<sequence>|<code>|`,
/// and asynchronous state updates begin with `S`. This is distinct from the
/// Kenwood-compatible CAT bridge represented by `RadioDefinition.Flex.flex6000`.
public actor FlexSmartSDRProtocol: CATProtocol, SupportsSendCW {
    public let transport: any SerialTransport
    public let capabilities: RigCapabilities

    /// Zero-based SmartSDR slice index (`0...7`, corresponding to A–H).
    public let slice: Int

    private static let terminator: UInt8 = 0x0A
    private let responseTimeout: TimeInterval = 2.0
    private var sequence = 0
    private var frequency: UInt64?
    private var mode: Mode?
    private var transmitting = false
    private var transmitSlice = false

    /// Creates a native SmartSDR controller for one slice.
    ///
    /// - Parameters:
    ///   - transport: An openable TCP transport, normally targeting port 4992.
    ///   - capabilities: Capability declaration for the SmartSDR endpoint.
    ///   - slice: Zero-based slice index from 0 (A) through 7 (H).
    public init(
        transport: any SerialTransport,
        capabilities: RigCapabilities = RadioCapabilitiesDatabase.Flex.smartSDR,
        slice: Int
    ) {
        precondition((0...7).contains(slice), "SmartSDR slice must be 0...7")
        self.transport = transport
        self.capabilities = capabilities
        self.slice = slice
    }

    public func connect() async throws {
        try await transport.open()
        try await transport.flush()
        try await perform("sub slice \(slice)")
    }

    public func disconnect() async {
        await transport.close()
    }

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        try requireVFOA(vfo)
        let mhz = String(format: "%.6f", Double(hz) / 1_000_000)
        try await perform("slice tune \(slice) \(mhz) autopan=1")
        frequency = hz
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        try requireVFOA(vfo)
        try await refreshSlice()
        guard let frequency else { throw RigError.invalidResponse }
        return frequency
    }

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        try requireVFOA(vfo)
        let smartSDRMode = try Self.smartSDRMode(for: mode)
        try await perform("slice set \(slice) mode=\(smartSDRMode)")
        self.mode = mode
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        try requireVFOA(vfo)
        try await refreshSlice()
        guard let mode else { throw RigError.invalidResponse }
        return mode
    }

    public func setPTT(_ enabled: Bool) async throws {
        if enabled {
            try await perform("dax audio set \(slice + 1) tx=1")
        }
        try await perform("slice set \(slice) tx=1")
        try await perform("xmit \(enabled ? 1 : 0)")
        transmitting = enabled
        transmitSlice = true
    }

    public func getPTT() async throws -> Bool {
        try await refreshSlice()
        return transmitSlice && transmitting
    }

    public func selectVFO(_ vfo: VFO) async throws {
        try requireVFOA(vfo)
    }

    public func sendCW(_ text: String) async throws {
        guard capabilities.supportsSendCW else {
            throw RigError.unsupportedOperation("CW text send not supported by this radio")
        }
        let message = text.unicodeScalars
            .filter(\.isASCII)
            .map { $0.value == 0x20 ? "\u{7F}" : String($0) }
            .joined()
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        guard !message.isEmpty else {
            throw RigError.invalidParameter("CW message must contain ASCII text")
        }
        try await perform("cwx send \"\(message)\"")
    }

    public func stopCW() async throws {
        guard capabilities.supportsSendCW else {
            throw RigError.unsupportedOperation("CW text send not supported by this radio")
        }
        try await perform("cwx clear")
    }

    private func refreshSlice() async throws {
        try await perform("sub slice \(slice)")
    }

    private func perform(_ command: String) async throws {
        let currentSequence = sequence
        sequence = sequence == 999_999 ? 0 : sequence + 1
        let wire = "C\(currentSequence)|\(command)\n"
        guard let data = wire.data(using: .ascii) else {
            throw RigError.invalidParameter("SmartSDR command is not ASCII")
        }
        try await transport.write(data)

        for _ in 0..<32 {
            let line = try await readLine()
            if line.hasPrefix("S") {
                parseStatus(line)
                continue
            }
            if line.hasPrefix("R\(currentSequence)|") {
                let fields = line.split(separator: "|", omittingEmptySubsequences: false)
                guard fields.count >= 2, let code = UInt32(fields[1], radix: 16) else {
                    throw RigError.invalidResponse
                }
                guard code == 0 else {
                    throw RigError.commandFailed("SmartSDR error 0x\(String(code, radix: 16))")
                }
                return
            }
            // Version/handle/banner lines are valid during initial connection.
        }
        throw RigError.invalidResponse
    }

    private func readLine() async throws -> String {
        var data = try await transport.readUntil(
            terminator: Self.terminator,
            timeout: responseTimeout
        )
        if data.last == Self.terminator { data.removeLast() }
        if data.last == 0x0D { data.removeLast() }
        guard let line = String(data: data, encoding: .utf8) else {
            throw RigError.invalidResponse
        }
        return line
    }

    /// Parses the state tokens used by Hamlib's `smartsdr_parse_S`.
    func parseStatus(_ line: String) {
        guard line.hasPrefix("S"), let separator = line.firstIndex(of: "|") else { return }
        let payload = line[line.index(after: separator)...]
        let tokens = payload.split(whereSeparator: { $0 == " " || $0 == "\n" })
        guard tokens.count >= 2 else { return }

        if tokens[0] == "slice", Int(tokens[1]) == slice {
            for token in tokens.dropFirst(2) {
                let pair = token.split(separator: "=", maxSplits: 1)
                guard pair.count == 2 else { continue }
                switch pair[0] {
                case "RF_frequency":
                    if let mhz = Double(pair[1]) {
                        frequency = UInt64((mhz * 1_000_000).rounded())
                    }
                case "mode": mode = Self.mode(from: String(pair[1]))
                case "tx": transmitSlice = pair[1] == "1"
                default: break
                }
            }
        } else {
            for token in tokens {
                if token == "state=TRANSMITTING" { transmitting = true }
                if token.hasPrefix("state="), token != "state=TRANSMITTING" {
                    transmitting = false
                }
            }
        }
    }

    private func requireVFOA(_ vfo: VFO) throws {
        guard vfo == .a || vfo == .main else {
            throw RigError.unsupportedOperation("SmartSDR slice definitions expose VFO A only")
        }
    }

    static func smartSDRMode(for mode: Mode) throws -> String {
        switch mode {
        case .usb: return "USB"
        case .lsb: return "LSB"
        case .dataUSB: return "DIGU"
        case .dataLSB: return "DIGL"
        case .cw, .cwR: return "CW"
        case .am: return "AM"
        case .fm: return "FM"
        case .fmN: return "NFM"
        default: throw RigError.unsupportedOperation("Mode \(mode) not supported by SmartSDR")
        }
    }

    static func mode(from value: String) -> Mode? {
        switch value.uppercased() {
        case "USB": return .usb
        case "LSB": return .lsb
        case "DIGU": return .dataUSB
        case "DIGL": return .dataLSB
        case "CW": return .cw
        case "AM", "SAM": return .am
        case "FM": return .fm
        case "NFM", "FMN": return .fmN
        case "RTTY": return .rtty
        default: return nil
        }
    }
}
