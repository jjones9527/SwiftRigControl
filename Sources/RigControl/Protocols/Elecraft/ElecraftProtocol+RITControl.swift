import Foundation

extension ElecraftProtocol {

    // MARK: - RIT/XIT Control

    /// Sets the RIT (Receiver Incremental Tuning) state.
    ///
    /// Note: The K2 and other Elecraft radios only support enabling/disabling RIT via CAT.
    /// The offset must be adjusted using the radio's physical RIT knob. When setting RIT,
    /// the offset parameter is ignored.
    ///
    /// - Parameter state: The desired RIT state
    /// - Throws: RigError if operation fails
    public func setRIT(_ state: RITXITState) async throws {
        let command = state.enabled ? "RT1" : "RT0"
        try await sendCommand(command)

        // K2 does NOT echo SET commands
        if !isK2 {
            let response = try await receiveResponse()
            guard response.hasPrefix(command) else {
                throw RigError.commandFailed("RIT setting failed")
            }
        } else {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    /// Gets the current RIT state including offset.
    ///
    /// - Returns: Current RIT state with enabled status and offset
    /// - Throws: RigError if operation fails
    public func getRIT() async throws -> RITXITState {
        // Get enabled status
        try await sendCommand("RT")
        let rtResponse = try await receiveResponse()

        guard rtResponse.hasPrefix("RT"),
              rtResponse.count >= 3 else {
            throw RigError.invalidResponse
        }

        let rtIndex = rtResponse.index(rtResponse.startIndex, offsetBy: 2)
        let enabled = rtResponse[rtIndex] == "1"

        // Get offset from IF command
        let offset = try await getRITXITOffset()

        return RITXITState(enabled: enabled, offset: offset)
    }

    /// Sets the XIT (Transmitter Incremental Tuning) state.
    ///
    /// Note: The K2 and other Elecraft radios only support enabling/disabling XIT via CAT.
    /// The offset must be adjusted using the radio's VFO A/B controls. When setting XIT,
    /// the offset parameter is ignored.
    ///
    /// - Parameter state: The desired XIT state
    /// - Throws: RigError if operation fails
    public func setXIT(_ state: RITXITState) async throws {
        let command = state.enabled ? "XT1" : "XT0"
        try await sendCommand(command)

        // K2 does NOT echo SET commands
        if !isK2 {
            let response = try await receiveResponse()
            guard response.hasPrefix(command) else {
                throw RigError.commandFailed("XIT setting failed")
            }
        } else {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    /// Gets the current XIT state including offset.
    ///
    /// - Returns: Current XIT state with enabled status and offset
    /// - Throws: RigError if operation fails
    public func getXIT() async throws -> RITXITState {
        // Get enabled status
        try await sendCommand("XT")
        let xtResponse = try await receiveResponse()

        guard xtResponse.hasPrefix("XT"),
              xtResponse.count >= 3 else {
            throw RigError.invalidResponse
        }

        let xtIndex = xtResponse.index(xtResponse.startIndex, offsetBy: 2)
        let enabled = xtResponse[xtIndex] == "1"

        // Get offset from IF command
        let offset = try await getRITXITOffset()

        return RITXITState(enabled: enabled, offset: offset)
    }

    /// Get RIT/XIT offset in Hz using the IF command.
    ///
    /// Note: The K2 doesn't support direct RIT/XIT offset queries (RO/XO commands),
    /// but the offset is included in the IF (transceiver info) response.
    ///
    /// - Returns: Current RIT/XIT offset in Hz
    /// - Throws: RigError if operation fails
    func getRITXITOffset() async throws -> Int {
        try await sendCommand("IF")
        let response = try await receiveResponse()

        // Response format from K2:
        // IF00014100000     +000011 0002000001 ;
        //   0         1         2         3
        //   0123456789012345678901234567890123456789
        //
        // [00-01]: IF (command)
        // [02-12]: VFO A frequency (11 digits)
        // [13-17]: 5 spaces
        // [18-23]: RIT/XIT offset (+/-00000 format, 6 chars including sign)
        // [24]   : space
        // [25-34]: additional status fields
        guard response.hasPrefix("IF"),
              response.count >= 24 else {
            throw RigError.invalidResponse
        }

        // Extract RIT offset (characters at positions 18-23, 0-indexed)
        let startIndex = response.index(response.startIndex, offsetBy: 18)
        let endIndex = response.index(startIndex, offsetBy: 6)
        let offsetString = String(response[startIndex..<endIndex])

        guard let offset = Int(offsetString) else {
            throw RigError.invalidResponse
        }

        return offset
    }

    /// Clears the RIT/XIT offset to zero.
    ///
    /// This command sets the RIT/XIT offset to zero, regardless of whether RIT or XIT is currently enabled.
    /// The change will be reflected when RIT or XIT is turned on.
    ///
    /// ## K2 Behavior During Transmit
    /// Per the K2 documentation: If this command is sent during transmit, the K2 will return `?;` but will
    /// still set a clear_pending flag. The offset will be cleared as soon as the K2 returns to receive mode,
    /// however briefly. The effect may be delayed depending on keying speed.
    ///
    /// - Throws: RigError if operation fails
    public func clearRITOffset() async throws {
        try await sendCommand("RC")

        if !isK2 {
            let response = try await receiveResponse()
            // K3/K4 echo the command
            guard response.hasPrefix("RC") else {
                throw RigError.commandFailed("RIT clear failed")
            }
        } else {
            // K2: May return ?; during transmit, but will still take effect
            // Don't check response, just add delay
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    /// Direction for RIT/XIT offset adjustment
    public enum RITOffsetDirection {
        case up
        case down
    }

    /// Adjusts the RIT/XIT offset by ±10 Hz.
    ///
    /// Increments or decrements the RIT/XIT offset by 10 Hz, even if RIT and XIT are both turned off.
    /// The change will be reflected when RIT or XIT is turned on.
    ///
    /// ## Range
    /// The RIT/XIT offset range under computer control is -9990 to +9990 Hz (±9.99 kHz).
    ///
    /// ## K2 FINE RIT Mode
    /// If FINE RIT mode is enabled on the K2 (narrow filter selected), the RD/RU commands will
    /// adjust the FINE RIT offset by one unit (range -15 to +15) instead of changing the main offset.
    ///
    /// - Parameter direction: Whether to increase (.up) or decrease (.down) the offset
    /// - Throws: RigError if operation fails
    public func adjustRITOffset(direction: RITOffsetDirection) async throws {
        let command = direction == .up ? "RU" : "RD"
        try await sendCommand(command)

        if !isK2 {
            let response = try await receiveResponse()
            guard response.hasPrefix(command) else {
                throw RigError.commandFailed("RIT offset adjustment failed")
            }
        } else {
            // K2 does not echo SET commands
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }
    }

    // MARK: - Transmit/Receive Status

    /// Gets the current transmit/receive status.
    ///
    /// This is the preferred method to check TX/RX status on Elecraft radios, as it requires
    /// far fewer bytes than the IF command.
    ///
    /// - Returns: `true` if transmitting, `false` if receiving
    /// - Throws: RigError if operation fails or command not supported
    public func getTXStatus() async throws -> Bool {
        try await sendCommand("TQ")
        let response = try await receiveResponse()

        // Response format: TQ0; (RX) or TQ1; (TX)
        guard response.hasPrefix("TQ"),
              response.count >= 3 else {
            throw RigError.invalidResponse
        }

        let statusIndex = response.index(response.startIndex, offsetBy: 2)
        return response[statusIndex] == "1"
    }

    // MARK: - Private Methods

    /// Sends a command to the radio.
    func sendCommand(_ command: String) async throws {
        var data = command.data(using: .ascii) ?? Data()
        // Add terminator (semicolon)
        data.append(ElecraftProtocol.terminator)

        try await transport.write(data)
    }

    /// Receives a response from the radio.
    ///
    /// For K2 radios, adds a delay after receiving to prevent buffer overflow
    /// on subsequent commands.
    ///
    /// ## Busy State Detection
    /// Per K2 documentation: Most SET commands cannot be safely handled when the K2 is in a busy state
    /// (transmit, direct frequency entry, scanning). The K2 will respond with `?;` to disallowed commands.
    ///
    /// - Throws: RigError.busy if radio returns `?;` (busy indication)
    /// - Throws: RigError.invalidResponse if response cannot be decoded
    func receiveResponse() async throws -> String {
        // Read until semicolon
        let data = try await transport.readUntil(
            terminator: ElecraftProtocol.terminator,
            timeout: responseTimeout
        )

        // Remove the terminator
        var responseData = data
        if responseData.last == ElecraftProtocol.terminator {
            responseData.removeLast()
        }

        guard let response = String(data: responseData, encoding: .ascii) else {
            throw RigError.invalidResponse
        }

        // Check for busy indication (K2 specific)
        // Per documentation: "The K2 will respond with ?; to disallowed commands at such times."
        if isK2 && response == "?" {
            throw RigError.busy
        }

        // K2 timing: Add delay after receiving response to prevent buffer overflow
        // The K2's slower processor needs time to process the command and clear its buffer
        // before accepting the next command
        if isK2 {
            try await Task.sleep(nanoseconds: k2CommandDelay)
        }

        return response
    }

    /// Converts a Mode enum to an Elecraft mode code.
    func modeToElecraftCode(_ mode: Mode) throws -> Int {
        switch mode {
        case .lsb: return 1
        case .usb: return 2
        case .cw: return 3
        case .fm: return 4
        case .am: return 5
        case .dataUSB: return 6  // FSK-D (data)
        case .cwR: return 7
        case .rtty: return 8  // RTTY
        case .dataLSB: return 9  // DATA-A (data on LSB)
        default:
            throw RigError.unsupportedOperation("Mode \(mode) not supported by Elecraft protocol")
        }
    }

    /// Converts an Elecraft mode code to a Mode enum.
    func elecraftCodeToMode(_ code: Int) throws -> Mode {
        switch code {
        case 1: return .lsb
        case 2: return .usb
        case 3: return .cw
        case 4: return .fm
        case 5: return .am
        case 6: return .dataUSB
        case 7: return .cwR
        case 8: return .rtty
        case 9: return .dataLSB
        default:
            throw RigError.invalidResponse
        }
    }
}
