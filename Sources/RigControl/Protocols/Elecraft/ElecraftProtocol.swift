import Foundation

/// Actor implementing the Elecraft text-based CAT protocol.
///
/// Elecraft radios (K2, K3, K3S, K4, KX2, KX3) use a text-based ASCII protocol
/// where commands are terminated with semicolons.
///
/// Example commands:
/// - `FA14230000;` - Set VFO A to 14.230 MHz
/// - `FA;` - Query VFO A frequency
/// - `MD2;` - Set mode to USB
/// - `TX;` - Enable PTT
///
/// ## K2-Specific Timing Requirements
/// The Elecraft K2 requires a small delay (50ms) between commands to prevent buffer overflow
/// and ensure reliable communication. This protocol automatically adds appropriate delays
/// based on the radio model, so users don't need to implement timing logic in their code.
///
/// Other Elecraft radios (K3, K3S, K4, KX series) have faster processors and larger buffers,
/// so they don't require these delays.
public actor ElecraftProtocol: CATProtocol {
    /// The serial transport for communication
    public let transport: any SerialTransport

    /// The capabilities of this radio
    public let capabilities: RigCapabilities

    /// Default timeout for radio responses
    let responseTimeout: TimeInterval = 1.0

    /// Inter-command delay for K2 (nanoseconds)
    /// The K2's slower processor requires time between commands to prevent buffer overflow
    let k2CommandDelay: UInt64 = 50_000_000  // 50ms

    /// Whether this is a K2 radio (requires command delays)
    let isK2: Bool

    /// Command terminator (semicolon)
    static let terminator: UInt8 = 0x3B  // ';'

    /// Initializes a new Elecraft protocol instance.
    ///
    /// - Parameters:
    ///   - transport: The serial transport to use
    ///   - capabilities: The capabilities of this radio model
    public init(transport: any SerialTransport, capabilities: RigCapabilities) {
        self.transport = transport
        self.capabilities = capabilities
        // Detect K2 by checking max power (K2 = 15W, others >= 100W)
        self.isK2 = capabilities.maxPower <= 15
    }

    public init(transport: any SerialTransport) {
        self.transport = transport
        self.capabilities = .full
        self.isK2 = false
    }

    // MARK: - Connection

    public func connect() async throws {
        try await transport.open()
        try await transport.flush()

        // Send AI0; to disable auto-info mode
        try await sendCommand("AI0")
    }

    public func disconnect() async {
        await transport.close()
    }

    // MARK: - Frequency Control

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        let command: String
        switch vfo {
        case .a, .main:
            command = String(format: "FA%011llu", hz)
        case .b, .sub:
            command = String(format: "FB%011llu", hz)
        }

        try await sendCommand(command)

        // K2 does NOT echo SET commands, only QUERY commands
        // K3/K4 and newer radios echo SET commands
        if !isK2 {
            // Newer Elecraft radios echo the command as confirmation
            let response = try await receiveResponse()
            guard response.hasPrefix(command) else {
                throw RigError.commandFailed("Unexpected response: \(response)")
            }
        } else {
            // K2: Just send and trust it worked, add delay for command processing
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        let command: String
        switch vfo {
        case .a, .main:
            command = "FA"
        case .b, .sub:
            command = "FB"
        }

        try await sendCommand(command)
        let response = try await receiveResponse()

        // Response format: FAxxxxxxxxxx; or FBxxxxxxxxxx;
        guard response.hasPrefix(command),
              response.count >= command.count + 11 else {
            throw RigError.invalidResponse
        }

        let startIndex = response.index(response.startIndex, offsetBy: command.count)
        let endIndex = response.index(startIndex, offsetBy: 11)
        let freqString = String(response[startIndex..<endIndex])

        guard let freq = UInt64(freqString) else {
            throw RigError.invalidResponse
        }

        return freq
    }

    // MARK: - Mode Control

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        let modeCode = try modeToElecraftCode(mode)
        let command = "MD\(modeCode)"

        try await sendCommand(command)

        // K2 does NOT echo SET commands, only QUERY commands
        if !isK2 {
            let response = try await receiveResponse()
            guard response.hasPrefix(command) else {
                throw RigError.commandFailed("Unexpected response: \(response)")
            }
        } else {
            // K2: Just send and trust it worked, add delay for command processing
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        try await sendCommand("MD")
        let response = try await receiveResponse()

        // Response format: MDx; where x is mode code
        guard response.hasPrefix("MD"),
              response.count >= 3 else {
            throw RigError.invalidResponse
        }

        let codeIndex = response.index(response.startIndex, offsetBy: 2)
        let codeChar = response[codeIndex]

        guard let modeCode = Int(String(codeChar)) else {
            throw RigError.invalidResponse
        }

        return try elecraftCodeToMode(modeCode)
    }

    // MARK: - PTT Control

    public func setPTT(_ enabled: Bool) async throws {
        let command = enabled ? "TX" : "RX"
        try await sendCommand(command)

        // K2: SET commands don't echo, just add delay
        // Per KIO2 Pgmrs Ref: TX/RX commands only work in SSB and RTTY modes
        if isK2 {
            // K2 needs time to switch TX/RX state
            // TX transition may take longer than standard command delay
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms for TX/RX state change
        } else {
            // K3/K4: May not echo either, just delay
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }

    public func getPTT() async throws -> Bool {
        // K2 supports TQ (Transmit Query) command - preferred method
        // Per KIO2 Pgmrs Ref: "This is the preferred way to check RX/TX status"
        // For K3/K4, we can also use the IF command which includes TX status

        if isK2 {
            // Use TQ command for K2 (most efficient)
            // Add small delay before query to ensure TX state has stabilized
            try await Task.sleep(nanoseconds: 20_000_000) // 20ms
            return try await getTXStatus()
        } else {
            // For K3/K4, use IF command which includes TX status
            // IF response format includes 't' field: 1 if TX, 0 if RX
            try await sendCommand("IF")
            let response = try await receiveResponse()

            // IF response format: IF[f]*****+yyyyrx*00tmvspb01*;
            // Position 28 is the TX flag
            guard response.hasPrefix("IF"),
                  response.count >= 29 else {
                throw RigError.invalidResponse
            }

            let txIndex = response.index(response.startIndex, offsetBy: 28)
            return response[txIndex] == "1"
        }
    }

    // MARK: - VFO Control

    public func selectVFO(_ vfo: VFO) async throws {
        let frCommand: String
        let ftCommand: String

        switch vfo {
        case .a, .main:
            frCommand = "FR0"  // Receive on VFO A
            ftCommand = "FT0"  // Transmit on VFO A
        case .b, .sub:
            frCommand = "FR1"  // Receive on VFO B
            ftCommand = "FT1"  // Transmit on VFO B
        }

        // Set receive VFO
        try await sendCommand(frCommand)
        if !isK2 {
            let frResponse = try await receiveResponse()
            guard frResponse.hasPrefix(frCommand) else {
                throw RigError.commandFailed("VFO RX selection failed")
            }
        } else {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }

        // Set transmit VFO
        try await sendCommand(ftCommand)
        if !isK2 {
            let ftResponse = try await receiveResponse()
            guard ftResponse.hasPrefix(ftCommand) else {
                throw RigError.commandFailed("VFO TX selection failed")
            }
        } else {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    // MARK: - Power Control

    public func setPower(_ watts: Int) async throws {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        let command: String
        if isK2 {
            // K2: Use direct watts (000-015 for QRP, 000-150 for K2/100 with QRO)
            // Per KIO2 Pgmrs Ref rev E: PCnnn; where nnn is watts, not percentage
            command = String(format: "PC%03d", watts)
        } else {
            // K3/K4: Use percentage (000-100)
            let percentage = min(max((watts * 100) / capabilities.maxPower, 0), 100)
            command = String(format: "PC%03d", percentage)
        }

        try await sendCommand(command)

        // K2 does NOT echo SET commands, only QUERY commands
        if !isK2 {
            let response = try await receiveResponse()
            guard response.hasPrefix("PC") else {
                throw RigError.commandFailed("Power setting failed")
            }
        } else {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    public func getPower() async throws -> Int {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        try await sendCommand("PC")
        let response = try await receiveResponse()

        // Response format: PCxxx;
        guard response.hasPrefix("PC"),
              response.count >= 5 else {
            throw RigError.invalidResponse
        }

        let startIndex = response.index(response.startIndex, offsetBy: 2)
        let endIndex = response.index(startIndex, offsetBy: 3)
        let valueString = String(response[startIndex..<endIndex])

        guard let value = Int(valueString) else {
            throw RigError.invalidResponse
        }

        if isK2 {
            // K2: Response is direct watts (000-015 for QRP, 000-150 for K2/100 with QRO)
            // Per KIO2 Pgmrs Ref rev E: PCnnn; where nnn is watts, not percentage
            return value
        } else {
            // K3/K4: Response is percentage (000-100), convert to watts
            return (value * capabilities.maxPower) / 100
        }
    }

    // MARK: - Split Operation

    public func setSplit(_ enabled: Bool) async throws {
        guard capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split operation not supported")
        }

        if enabled {
            // Split: RX on VFO A, TX on VFO B
            try await sendCommand("FR0")
            if !isK2 {
                let frResponse = try await receiveResponse()
                guard frResponse.hasPrefix("FR0") else {
                    throw RigError.commandFailed("Split RX VFO selection failed")
                }
            } else {
                try await Task.sleep(nanoseconds: k2CommandDelay)
            }

            try await sendCommand("FT1")
            if !isK2 {
                let ftResponse = try await receiveResponse()
                guard ftResponse.hasPrefix("FT1") else {
                    throw RigError.commandFailed("Split TX VFO selection failed")
                }
            } else {
                try await Task.sleep(nanoseconds: k2CommandDelay)
            }
        } else {
            // Normal: RX and TX on VFO A
            try await sendCommand("FR0")
            if !isK2 {
                let frResponse = try await receiveResponse()
                guard frResponse.hasPrefix("FR0") else {
                    throw RigError.commandFailed("Normal RX VFO selection failed")
                }
            } else {
                try await Task.sleep(nanoseconds: k2CommandDelay)
            }

            try await sendCommand("FT0")
            if !isK2 {
                let ftResponse = try await receiveResponse()
                guard ftResponse.hasPrefix("FT0") else {
                    throw RigError.commandFailed("Normal TX VFO selection failed")
                }
            } else {
                try await Task.sleep(nanoseconds: k2CommandDelay)
            }
        }
    }

    public func getSplit() async throws -> Bool {
        try await sendCommand("FT")
        let response = try await receiveResponse()

        // Response format: FTx; where x is 0 or 1
        guard response.hasPrefix("FT"),
              response.count >= 3 else {
            throw RigError.invalidResponse
        }

        let codeIndex = response.index(response.startIndex, offsetBy: 2)
        let codeChar = response[codeIndex]

        return codeChar == "1"
    }

    // MARK: - Signal Strength

    public func getSignalStrength() async throws -> SignalStrength {
        // Send SM0; for main receiver (some models also support SM; for current RX)
        try await sendCommand("SM0")
        let response = try await receiveResponse()

        // Response format: "SM0nnnn" where nnnn is 0000-0030 (dB over S0)
        guard response.hasPrefix("SM0"),
              response.count >= 7 else {
            throw RigError.invalidResponse
        }

        let startIndex = response.index(response.startIndex, offsetBy: 3)
        let endIndex = response.index(startIndex, offsetBy: 4)
        let valueString = String(response[startIndex..<endIndex])

        guard let rawValue = Int(valueString) else {
            throw RigError.invalidResponse
        }

        // Elecraft: 0-30 represents dB over S0
        // S0 to S9 = 54 dB (6 dB per S-unit)
        // So: S1 = 6 dB, S2 = 12 dB, ..., S9 = 54 dB
        let sUnits = min(rawValue / 6, 9)
        let overS9 = sUnits >= 9 ? max(rawValue - 54, 0) : 0

        return SignalStrength(sUnits: sUnits, overS9: overS9, raw: rawValue)
    }
}
