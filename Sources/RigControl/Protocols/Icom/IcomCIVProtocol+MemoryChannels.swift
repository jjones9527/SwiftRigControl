import Foundation

extension IcomCIVProtocol {

    // MARK: - Memory Channel Operations

    /// Stores a configuration to a memory channel.
    ///
    /// Uses CI-V command 0x1A 0x00 (Advanced Settings - Memory Contents) to write a complete
    /// memory channel configuration including frequency, mode, filter, name, and optional features.
    ///
    /// - Parameter channel: Memory channel configuration to store
    /// - Throws: `RigError` if operation fails or channel number is invalid
    public func setMemoryChannel(_ channel: MemoryChannel) async throws {
        // Validate channel configuration
        try channel.validate(for: capabilities)

        // Encode channel data to CI-V format
        var data = [UInt8]()

        // Channel number (2 bytes BCD)
        data.append(contentsOf: encodeChannelNumber(channel.number))

        // Frequency (5 bytes BCD)
        data.append(contentsOf: BCDEncoding.encodeFrequency(channel.frequency))

        // Mode (1 byte)
        let modeCode = try modeToIcomCode(channel.mode)
        data.append(modeCode)

        // Filter selection (1 byte)
        data.append(UInt8(channel.filterSelection ?? 1))

        // Data mode (1 byte) - 0x00 = off, 0x01 = on
        data.append((channel.dataMode ?? false) ? 0x01 : 0x00)

        // Duplex offset (3 bytes BCD, signed)
        data.append(contentsOf: encodeDuplexOffset(channel.duplexOffset ?? 0))

        // CTCSS/DCS tone (2 bytes) - simplified, 0x0000 = none
        data.append(contentsOf: encodeToneFrequency(channel.toneFrequency))

        // Channel name (10 bytes ASCII, space-padded)
        data.append(contentsOf: encodeChannelName(channel.name))

        // Build and send memory write command
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, CIVFrame.AdvancedCode.memoryContents],
            data: data
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected memory channel \(channel.number) write")
        }
    }

    /// Reads a memory channel configuration from the radio.
    ///
    /// Uses CI-V command 0x1A 0x00 (Advanced Settings - Memory Contents) to read a complete
    /// memory channel configuration.
    ///
    /// - Parameter number: Memory channel number to read
    /// - Returns: Memory channel configuration
    /// - Throws: `RigError` if operation fails, channel is empty, or number is invalid
    public func getMemoryChannel(_ number: Int) async throws -> MemoryChannel {
        // Build query command with channel number
        let channelBCD = encodeChannelNumber(number)

        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, CIVFrame.AdvancedCode.memoryContents],
            data: channelBCD
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Check for NAK (channel empty or invalid)
        if response.isNak {
            throw RigError.commandFailed("Memory channel \(number) is empty or invalid")
        }

        // Parse response data
        // Expected: [channel 2] [freq 5] [mode 1] [filter 1] [data mode 1] [duplex 3] [tone 2] [name 10]
        guard response.command.count >= 2,
              response.command[0] == CIVFrame.Command.advancedSettings,
              response.command[1] == CIVFrame.AdvancedCode.memoryContents,
              response.data.count >= 25 else {
            throw RigError.invalidResponse
        }

        let data = response.data

        // Decode channel number (bytes 0-1, already validated)
        // Skip decoding, we know it matches 'number'

        // Decode frequency (bytes 2-6)
        let frequency = try BCDEncoding.decodeFrequency(Array(data[2..<7]))

        // Decode mode (byte 7)
        let modeCode = data[7]
        let mode = try icomCodeToMode(modeCode)

        // Decode filter selection (byte 8)
        let filterSelection = Int(data[8])

        // Decode data mode (byte 9)
        let dataMode = data[9] == 0x01

        // Decode duplex offset (bytes 10-12)
        let duplexOffset = decodeDuplexOffset(Array(data[10..<13]))

        // Decode tone frequency (bytes 13-14)
        let toneFrequency = decodeToneFrequency(Array(data[13..<15]))

        // Decode channel name (bytes 15-24)
        let name = decodeChannelName(Array(data[15..<25]))

        return MemoryChannel(
            number: number,
            frequency: frequency,
            mode: mode,
            name: name,
            splitEnabled: nil,  // Not stored in basic memory format
            txFrequency: nil,   // Not stored in basic memory format
            toneFrequency: toneFrequency,
            toneSqelchFrequency: nil,  // Not differentiated in basic format
            dcsCode: nil,       // Would require separate parsing
            duplexOffset: duplexOffset != 0 ? duplexOffset : nil,
            skipScan: nil,      // Not stored in basic memory format
            lockout: nil,       // Not stored in basic memory format
            filterSelection: filterSelection != 0 ? filterSelection : nil,
            dataMode: dataMode ? true : nil,
            powerLevel: nil     // Not stored in basic memory format
        )
    }

    /// Gets the total number of memory channels supported by the radio.
    ///
    /// Returns model-specific channel counts. Actual channel numbering may start at 0 or 1
    /// depending on the radio model.
    ///
    /// - Returns: Number of memory channels
    /// - Throws: `RigError.unsupportedOperation` if memory not supported
    public func getMemoryChannelCount() async throws -> Int {
        // Return model-specific channel count
        // Common values: 99 (most radios), 100 (IC-7600), 109 (IC-7100/9700)
        switch radioModel {
        case .ic7300, .ic705, .ic703:
            return 99
        case .xieguG90, .xieguX6100, .xieguX6200:
            return 99  // Xiegu radios use 1-99 memory channels
        case .ic7600:
            return 100
        case .ic7100, .ic9700:
            return 109  // Includes program scan edges and call channels
        case .ic905:
            return 109  // Similar to IC-9700
        case .ic9100, .ic7000:
            return 99
        case .ic7610, .ic7700, .ic7410, .ic7400, .ic7200, .ic751, .ic735, .ic718:
            return 99
        case .ic7851, .ic7850, .ic7800:
            return 99
        case .ic756proIII, .ic756proII, .ic756pro, .ic756:
            return 99
        case .ic746pro, .ic746:
            return 99
        case .ic706mkiig, .ic706mkii, .ic706:
            return 99
        case .ic970, .ic910h, .ic9000, .ic820h:
            return 99
        case .ic275, .ic375, .ic475:
            return 99
        case .ic2730, .ic2820h:
            return 99
        case .id5100, .id4100:
            return 99
        case .icr8600, .icr75, .icr30, .icr9500:
            return 99
        }
    }

    /// Clears (erases) a memory channel.
    ///
    /// Uses CI-V command 0x0B (Memory Clear) to erase the specified channel.
    ///
    /// - Parameter number: Memory channel number to clear
    /// - Throws: `RigError` if operation fails or number is invalid
    public func clearMemoryChannel(_ number: Int) async throws {
        // Build clear command with channel number
        let channelBCD = encodeChannelNumber(number)

        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.memoryClear],
            data: channelBCD
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected memory channel \(number) clear")
        }
    }

    // MARK: - Memory Channel Encoding/Decoding Helpers

    /// Encodes a channel number to 2-byte BCD format.
    ///
    /// - Parameter number: Channel number (0-999)
    /// - Returns: 2-byte BCD representation [low, high]
    internal func encodeChannelNumber(_ number: Int) -> [UInt8] {
        let low = UInt8((number % 10) | ((number / 10 % 10) << 4))
        let high = UInt8((number / 100 % 10) | ((number / 1000 % 10) << 4))
        return [low, high]
    }

    /// Encodes a duplex offset to 3-byte signed BCD format.
    ///
    /// - Parameter offset: Offset in Hz (negative for -, positive for +, 0 for simplex)
    /// - Returns: 3-byte BCD representation with sign bit
    internal func encodeDuplexOffset(_ offset: Int) -> [UInt8] {
        if offset == 0 {
            return [0x00, 0x00, 0x00]
        }

        let absOffset = abs(offset)
        let low = UInt8((absOffset % 10) | ((absOffset / 10 % 10) << 4))
        let mid = UInt8((absOffset / 100 % 10) | ((absOffset / 1000 % 10) << 4))
        let high = UInt8((absOffset / 10000 % 10) | ((absOffset / 100000 % 10) << 4))

        // Sign bit in MSB of high byte
        let signBit: UInt8 = offset < 0 ? 0x80 : 0x00

        return [low, mid, high | signBit]
    }

    /// Decodes a 3-byte signed BCD duplex offset.
    ///
    /// - Parameter data: 3-byte BCD data
    /// - Returns: Offset in Hz (negative for -, positive for +)
    internal func decodeDuplexOffset(_ data: [UInt8]) -> Int {
        guard data.count >= 3 else { return 0 }

        let low = data[0]
        let mid = data[1]
        let high = data[2]

        // Extract sign bit
        let isNegative = (high & 0x80) != 0
        let highCleaned = high & 0x7F

        let offset = Int(low & 0x0F) +
                     Int((low >> 4) & 0x0F) * 10 +
                     Int(mid & 0x0F) * 100 +
                     Int((mid >> 4) & 0x0F) * 1000 +
                     Int(highCleaned & 0x0F) * 10000 +
                     Int((highCleaned >> 4) & 0x0F) * 100000

        return isNegative ? -offset : offset
    }

    /// Encodes a CTCSS tone frequency to 2-byte format.
    ///
    /// - Parameter frequency: Tone frequency in Hz (67.0-254.1), or nil for no tone
    /// - Returns: 2-byte tone representation (0x0000 for none)
    internal func encodeToneFrequency(_ frequency: Double?) -> [UInt8] {
        guard let freq = frequency else {
            return [0x00, 0x00]
        }

        // Convert frequency to BCD (multiply by 10 to preserve decimal)
        let toneValue = Int(freq * 10)
        let low = UInt8((toneValue % 10) | ((toneValue / 10 % 10) << 4))
        let high = UInt8((toneValue / 100 % 10) | ((toneValue / 1000 % 10) << 4))

        return [low, high]
    }

    /// Decodes a 2-byte CTCSS tone frequency.
    ///
    /// - Parameter data: 2-byte tone data
    /// - Returns: Tone frequency in Hz, or nil if no tone set
    internal func decodeToneFrequency(_ data: [UInt8]) -> Double? {
        guard data.count >= 2 else { return nil }

        let low = data[0]
        let high = data[1]

        // Check for no tone
        if low == 0x00 && high == 0x00 {
            return nil
        }

        let toneValue = Int(low & 0x0F) +
                        Int((low >> 4) & 0x0F) * 10 +
                        Int(high & 0x0F) * 100 +
                        Int((high >> 4) & 0x0F) * 1000

        return Double(toneValue) / 10.0
    }

    /// Encodes a channel name to 10-byte space-padded ASCII.
    ///
    /// - Parameter name: Channel name (max 10 characters), or nil for unnamed
    /// - Returns: 10-byte ASCII representation
    internal func encodeChannelName(_ name: String?) -> [UInt8] {
        var nameBytes = [UInt8](repeating: 0x20, count: 10)  // Space-padded

        if let name = name {
            let truncated = String(name.prefix(10))
            let ascii = truncated.data(using: .ascii) ?? Data()
            for (i, byte) in ascii.enumerated() where i < 10 {
                nameBytes[i] = byte
            }
        }

        return nameBytes
    }

    /// Decodes a 10-byte space-padded ASCII channel name.
    ///
    /// - Parameter data: 10-byte name data
    /// - Returns: Channel name string, or nil if all spaces
    internal func decodeChannelName(_ data: [UInt8]) -> String? {
        guard data.count >= 10 else { return nil }

        let nameData = Data(data[0..<10])
        guard let name = String(data: nameData, encoding: .ascii) else {
            return nil
        }

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
