import Foundation

extension IcomCIVProtocol {

    // MARK: - Power Control (0x18)

    /// Turn OFF the transceiver (IC-7100)
    /// Command: 0x18 0x00
    public func powerOffIC7100() async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("powerOffIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x18, 0x00],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Power OFF command rejected")
        }
    }

    /// Turn ON the transceiver (IC-7100)
    /// Command: Multiple 0xFE preambles + 0x18 0x01
    /// Note: Requires extra preamble codes based on baud rate
    public func powerOnIC7100() async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("powerOnIC7100 is only available on IC-7100")
        }
        // IC-7100 requires multiple 0xFE preambles before the command
        // Number depends on baud rate: 19200bps=25, 9600bps=13, 4800bps=7, etc.
        var preambles = [UInt8](repeating: 0xFE, count: 25)  // Default for 19200 bps
        preambles.append(contentsOf: [0xFE, civAddress, 0xE0, 0x18, 0x01, 0xFD])

        try await transport.write(Data(preambles))
        // Wait for response
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
    }

    // MARK: - RIT Control (0x21)

    /// Set RIT frequency (IC-7100)
    /// Command: 0x21 0x00 [freq BCD]
    public func setRITFrequencyIC7100(_ hz: Int) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setRITFrequencyIC7100 is only available on IC-7100")
        }
        // RIT frequency is ±9.999 kHz
        guard abs(hz) <= 9999 else {
            throw RigError.invalidParameter("RIT frequency must be ±9.999 kHz")
        }

        let absHz = abs(hz)
        let direction: UInt8 = hz >= 0 ? 0x00 : 0x01

        // Encode as BCD: kHz, 100Hz, 10Hz, 1Hz
        let khz = UInt8(absHz / 1000)
        let hundreds = UInt8((absHz % 1000) / 100)
        let tens = UInt8((absHz % 100) / 10)
        let ones = UInt8(absHz % 10)

        let bcd = [ones | (tens << 4), hundreds | (khz << 4), direction]

        let frame = CIVFrame(
            to: civAddress,
            command: [0x21, 0x00],
            data: bcd
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("RIT frequency command rejected")
        }
    }

    /// Read RIT frequency (IC-7100)
    public func getRITFrequencyIC7100() async throws -> Int {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getRITFrequencyIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x21, 0x00],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-7100 format: command=[21], data=[00, bcd1, bcd2, direction]
        if response.command.count == 1 && response.data.count >= 4 {
            guard response.command[0] == 0x21, response.data[0] == 0x00 else {
                throw RigError.invalidResponse
            }
            let ones = Int(response.data[1] & 0x0F)
            let tens = Int((response.data[1] >> 4) & 0x0F) * 10
            let hundreds = Int(response.data[2] & 0x0F) * 100
            let khz = Int((response.data[2] >> 4) & 0x0F) * 1000
            let direction = response.data[3]

            let absHz = khz + hundreds + tens + ones
            return direction == 0x00 ? absHz : -absHz
        }
        // Fallback to standard format
        else if response.command.count >= 2 && response.data.count >= 3 {
            guard response.command[0] == 0x21, response.command[1] == 0x00 else {
                throw RigError.invalidResponse
            }
            let ones = Int(response.data[0] & 0x0F)
            let tens = Int((response.data[0] >> 4) & 0x0F) * 10
            let hundreds = Int(response.data[1] & 0x0F) * 100
            let khz = Int((response.data[1] >> 4) & 0x0F) * 1000
            let direction = response.data[2]

            let absHz = khz + hundreds + tens + ones
            return direction == 0x00 ? absHz : -absHz
        }
        else {
            throw RigError.invalidResponse
        }
    }

    /// Set RIT ON/OFF (IC-7100)
    /// Command: 0x21 0x01 [ON/OFF]
    public func setRITIC7100(_ enabled: Bool) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setRITIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x21, 0x01],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("RIT ON/OFF command rejected")
        }
    }

    /// Read RIT ON/OFF status (IC-7100)
    public func getRITIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getRITIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x21, 0x01],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-7100 format: command=[21], data=[01, value]
        if response.command.count == 1 && response.data.count >= 2 {
            guard response.command[0] == 0x21, response.data[0] == 0x01 else {
                throw RigError.invalidResponse
            }
            return response.data[1] == 0x01
        }
        // Fallback to standard format
        else if response.command.count >= 2 && response.data.count >= 1 {
            guard response.command[0] == 0x21, response.command[1] == 0x01 else {
                throw RigError.invalidResponse
            }
            return response.data[0] == 0x01
        }
        else {
            throw RigError.invalidResponse
        }
    }

    // MARK: - Selected/Unselected VFO (0x25, 0x26)

    /// Read selected or unselected VFO frequency (IC-7100)
    /// Command: 0x25 [VFO selector]
    /// VFO: 0x00=Selected VFO, 0x01=Unselected VFO
    public func readVFOFrequencyIC7100(_ vfoSelector: UInt8) async throws -> UInt64 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("readVFOFrequencyIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x25],
            data: [vfoSelector]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 1, response.data.count >= 5 else {
            throw RigError.invalidResponse
        }
        // Skip first byte (VFO selector echo), then parse frequency
        return bcdToFrequencyIC7100(Array(response.data.dropFirst()))
    }

    /// Read selected or unselected VFO mode (IC-7100)
    /// Command: 0x26 [VFO selector]
    /// VFO: 0x00=Selected VFO, 0x01=Unselected VFO
    public func readVFOModeIC7100(_ vfoSelector: UInt8) async throws -> (mode: Mode, dataMode: Bool, filter: UInt8) {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("readVFOModeIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x26],
            data: [vfoSelector]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 1, response.data.count >= 3 else {
            throw RigError.invalidResponse
        }

        let modeCode = response.data[1]
        let dataMode = response.data[2] == 0x01
        let filter = response.data[3]

        // Convert Icom mode code to Mode enum
        let mode: Mode
        switch modeCode {
        case CIVFrame.ModeCode.lsb: mode = .lsb
        case CIVFrame.ModeCode.usb: mode = .usb
        case CIVFrame.ModeCode.am: mode = .am
        case CIVFrame.ModeCode.cw: mode = .cw
        case CIVFrame.ModeCode.cwR: mode = .cwR
        case CIVFrame.ModeCode.rtty: mode = .rtty
        case CIVFrame.ModeCode.rttyR: mode = .rttyR
        case CIVFrame.ModeCode.fm: mode = .fm
        case CIVFrame.ModeCode.wfm: mode = .wfm
        case 0x17: mode = .dataUSB  // DV mode on IC-7100
        default: mode = .usb  // Default fallback
        }
        return (mode, dataMode, filter)
    }

    // MARK: - Helper Methods

    /// Convert frequency in Hz to BCD format (5 bytes) (IC-7100)
    func frequencyToBCDIC7100(_ hz: UInt64) -> [UInt8] {
        var freq = hz
        var bcd = [UInt8]()

        // Encode 10 BCD digits (5 bytes) from least significant to most significant
        for _ in 0..<5 {
            let low = UInt8(freq % 10)
            freq /= 10
            let high = UInt8(freq % 10)
            freq /= 10
            bcd.append((high << 4) | low)
        }

        return bcd
    }

    /// Convert BCD format (5 bytes) to frequency in Hz (IC-7100)
    func bcdToFrequencyIC7100(_ bcd: [UInt8]) -> UInt64 {
        guard bcd.count == 5 else { return 0 }

        var freq: UInt64 = 0
        var multiplier: UInt64 = 1

        for byte in bcd {
            let low = UInt64(byte & 0x0F)
            let high = UInt64((byte >> 4) & 0x0F)

            freq += low * multiplier
            multiplier *= 10
            freq += high * multiplier
            multiplier *= 10
        }

        return freq
    }

    // MARK: - IC-7100 Response Format Helpers

    /// Helper method to read a Function command (0x16) response in IC-7100 format
    ///
    /// The IC-7100 uses a unique response format where the subcommand byte is echoed
    /// in the data field rather than the command field:
    ///
    /// **Standard Icom Format:**
    /// ```
    /// Request:  FE FE 88 E0 16 [sub] FD
    /// Response: FE FE E0 88 16 [sub] [value] FD
    ///           command=[16, sub], data=[value]
    /// ```
    ///
    /// **IC-7100 Format:**
    /// ```
    /// Request:  FE FE 88 E0 16 [sub] FD
    /// Response: FE FE E0 88 16 [sub] [value] FD
    ///           command=[16], data=[sub, value]
    /// ```
    ///
    /// - Parameter subCommand: The function subcommand byte (e.g., 0x02 for Preamp)
    /// - Returns: The value byte from the response
    /// - Throws: `RigError.invalidResponse` if response format is incorrect
    func getFunctionIC7100(_ subCommand: UInt8) async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.function, subCommand],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-7100 format: command=[16], data=[subCommand, value]
        if response.command.count == 1 && response.data.count == 2 {
            guard response.command[0] == CIVFrame.Command.function,
                  response.data[0] == subCommand else {
                throw RigError.invalidResponse
            }
            return response.data[1]
        }
        // Fallback to standard format (defensive programming)
        else if response.command.count >= 2 && response.data.count >= 1 {
            guard response.command[0] == CIVFrame.Command.function,
                  response.command[1] == subCommand else {
                throw RigError.invalidResponse
            }
            return response.data[0]
        }
        else {
            throw RigError.invalidResponse
        }
    }

    /// Helper method to read a Level command (0x14) response in IC-7100 format
    ///
    /// Similar to Function commands, Level commands use IC-7100 response format.
    ///
    /// - Parameter subCommand: The level subcommand byte
    /// - Returns: The decoded integer value (from BCD)
    /// - Throws: `RigError.invalidResponse` if response format is incorrect
    func getLevelIC7100(_ subCommand: UInt8) async throws -> Int {
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.settings, subCommand],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-7100 format: command=[14], data=[subCommand, value_bcd...]
        if response.command.count == 1 && response.data.count >= 3 {
            guard response.command[0] == CIVFrame.Command.settings,
                  response.data[0] == subCommand else {
                throw RigError.invalidResponse
            }
            return BCDEncoding.decodePower(Array(response.data[1...]))
        }
        // Fallback to standard format
        else if response.command.count >= 2 && response.data.count >= 2 {
            guard response.command[0] == CIVFrame.Command.settings,
                  response.command[1] == subCommand else {
                throw RigError.invalidResponse
            }
            return BCDEncoding.decodePower(response.data)
        }
        else {
            throw RigError.invalidResponse
        }
    }

    /// Helper method to read an Advanced Settings command (0x1A) response in IC-7100 format
    ///
    /// - Parameter subCommand: The advanced settings subcommand byte
    /// - Returns: The value byte from the response
    /// - Throws: `RigError.invalidResponse` if response format is incorrect
    func getAdvancedSettingIC7100(_ subCommand: UInt8) async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, subCommand],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-7100 format: command=[1A], data=[subCommand, value]
        if response.command.count == 1 && response.data.count >= 2 {
            guard response.command[0] == CIVFrame.Command.advancedSettings,
                  response.data[0] == subCommand else {
                throw RigError.invalidResponse
            }
            return response.data[1]
        }
        // Fallback to standard format
        else if response.command.count >= 2 && !response.data.isEmpty {
            guard response.command[0] == CIVFrame.Command.advancedSettings,
                  response.command[1] == subCommand else {
                throw RigError.invalidResponse
            }
            return response.data[0]
        }
        else {
            throw RigError.invalidResponse
        }
    }

    /// Helper method to read a Read Level command (0x15) response in IC-7100 format
    ///
    /// - Parameter subCommand: The read level subcommand byte
    /// - Returns: True if non-zero, false if zero
    /// - Throws: `RigError.invalidResponse` if response format is incorrect
    func getReadLevelIC7100(_ subCommand: UInt8) async throws -> Bool {
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.readLevel, subCommand],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-7100 format: command=[15], data=[subCommand, value_bcd...]
        if response.command.count == 1 && response.data.count >= 3 {
            guard response.command[0] == CIVFrame.Command.readLevel,
                  response.data[0] == subCommand else {
                throw RigError.invalidResponse
            }
            return response.data[1] != 0x00
        }
        // Fallback to standard format
        else if response.command.count >= 2 && response.data.count >= 2 {
            guard response.command[0] == CIVFrame.Command.readLevel,
                  response.command[1] == subCommand else {
                throw RigError.invalidResponse
            }
            return response.data[0] != 0x00
        }
        else {
            throw RigError.invalidResponse
        }
    }

}
