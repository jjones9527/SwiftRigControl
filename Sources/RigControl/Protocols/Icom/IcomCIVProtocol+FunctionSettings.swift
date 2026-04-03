import Foundation

extension IcomCIVProtocol {

    // MARK: - Function Settings (0x16 sub-commands)

    /// Set noise blanker ON/OFF.
    ///
    /// Enables or disables the impulse noise blanker circuit.
    ///
    /// **Command**: `0x16 0x22 [0x00=OFF, 0x01=ON]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Parameter enabled: True to enable, false to disable
    /// - Throws: `RigError.commandFailed` if radio rejects the operation
    public func setNoiseBlanker(_ enabled: Bool) async throws {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x22],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Noise blanker command rejected")
        }
    }

    /// Read noise blanker ON/OFF status.
    ///
    /// **Command**: `0x16 0x22` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: True if enabled, false if disabled
    /// - Throws: `RigError.invalidResponse` if response is malformed
    internal func getNoiseBlankerState() async throws -> Bool {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x22],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Set noise reduction ON/OFF.
    ///
    /// Enables or disables the digital noise reduction DSP filter.
    ///
    /// **Command**: `0x16 0x40 [0x00=OFF, 0x01=ON]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Parameter enabled: True to enable, false to disable
    /// - Throws: `RigError.commandFailed` if radio rejects the operation
    ///
    /// - Note: NR strength can be adjusted using `setNRLevel(_:)`
    public func setNoiseReduction(_ enabled: Bool) async throws {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x40],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Noise reduction command rejected")
        }
    }

    /// Read noise reduction ON/OFF status.
    ///
    /// **Command**: `0x16 0x40` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: True if enabled, false if disabled
    /// - Throws: `RigError.invalidResponse` if response is malformed
    internal func getNoiseReductionState() async throws -> Bool {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x40],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Set auto notch ON/OFF.
    ///
    /// Enables or disables the automatic notch filter that removes carrier interference.
    ///
    /// **Command**: `0x16 0x41 [0x00=OFF, 0x01=ON]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Parameter enabled: True to enable, false to disable
    /// - Throws: `RigError.commandFailed` if radio rejects the operation
    public func setAutoNotch(_ enabled: Bool) async throws {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x41],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Auto notch command rejected")
        }
    }

    /// Read auto notch ON/OFF status.
    ///
    /// **Command**: `0x16 0x41` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: True if enabled, false if disabled
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getAutoNotch() async throws -> Bool {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x41],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Set repeater tone ON/OFF.
    ///
    /// Enables or disables the CTCSS/PL tone encoder for repeater access.
    ///
    /// **Command**: `0x16 0x42 [0x00=OFF, 0x01=ON]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Parameter enabled: True to enable, false to disable
    /// - Throws: `RigError.commandFailed` if radio rejects the operation
    public func setRepeaterTone(_ enabled: Bool) async throws {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x42],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Repeater tone command rejected")
        }
    }

    /// Read repeater tone ON/OFF status.
    ///
    /// **Command**: `0x16 0x42` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: True if enabled, false if disabled
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getRepeaterTone() async throws -> Bool {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x42],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Set tone squelch ON/OFF.
    ///
    /// Enables or disables the CTCSS/PL tone decoder squelch.
    ///
    /// **Command**: `0x16 0x43 [0x00=OFF, 0x01=ON]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Parameter enabled: True to enable, false to disable
    /// - Throws: `RigError.commandFailed` if radio rejects the operation
    public func setToneSquelch(_ enabled: Bool) async throws {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x43],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Tone squelch command rejected")
        }
    }

    /// Read tone squelch ON/OFF status.
    ///
    /// **Command**: `0x16 0x43` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: True if enabled, false if disabled
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getToneSquelch() async throws -> Bool {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x43],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Set speech compressor ON/OFF.
    ///
    /// Enables or disables the speech compressor for SSB/AM transmit.
    ///
    /// **Command**: `0x16 0x44 [0x00=OFF, 0x01=ON]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Parameter enabled: True to enable, false to disable
    /// - Throws: `RigError.commandFailed` if radio rejects the operation
    public func setSpeechCompressor(_ enabled: Bool) async throws {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x44],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Speech compressor command rejected")
        }
    }

    /// Read speech compressor ON/OFF status.
    ///
    /// **Command**: `0x16 0x44` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: True if enabled, false if disabled
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getSpeechCompressor() async throws -> Bool {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x44],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Set VOX (voice-operated transmit) ON/OFF.
    ///
    /// Enables or disables voice-activated transmission.
    ///
    /// **Command**: `0x16 0x46 [0x00=OFF, 0x01=ON]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Parameter enabled: True to enable, false to disable
    /// - Throws: `RigError.commandFailed` if radio rejects the operation
    public func setVOX(_ enabled: Bool) async throws {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x46],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("VOX command rejected")
        }
    }

    /// Read VOX (voice-operated transmit) ON/OFF status.
    ///
    /// **Command**: `0x16 0x46` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: True if enabled, false if disabled
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getVOX() async throws -> Bool {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x46],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    // MARK: - Transceiver ID (0x19)

    /// Read transceiver ID.
    ///
    /// Returns the radio model's CI-V address/ID code.
    ///
    /// **Command**: `0x19 0x00`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: Radio ID (0x88=IC-7100, 0x7A=IC-7600, 0xA2=IC-9700)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    ///
    /// - Note: Useful for auto-detection of connected radio model
    public func readTransceiverID() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x19, 0x00],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

}
