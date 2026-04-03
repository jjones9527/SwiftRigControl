import Foundation

extension IcomCIVProtocol {

    // MARK: - Level Controls (0x14 sub-commands)

    /// Set AF (audio frequency) level.
    ///
    /// Controls the receiver audio volume.
    ///
    /// **Command**: `0x14 0x01 [level BCD]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 range)
    ///
    /// - Parameter level: Volume level (0=minimum, 255=maximum)
    /// - Throws: `RigError.commandFailed` if radio rejects the value
    public func setAFLevel(_ level: UInt8) async throws {
        let bcdLevel = BCDEncoding.encodePower(Int(level))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x01],
            data: bcdLevel
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("AF level command rejected")
        }
    }

    /// Read AF (audio frequency) level.
    ///
    /// **Command**: `0x14 0x01` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: Current volume level (0-255)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getAFLevel() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x01],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }

    /// Set RF gain level.
    ///
    /// Controls the receiver RF gain, affecting sensitivity and overload performance.
    ///
    /// **Command**: `0x14 0x02 [level BCD]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 range)
    ///
    /// - Parameter level: Gain level (0=minimum, 255=maximum)
    /// - Throws: `RigError.commandFailed` if radio rejects the value
    public func setRFGain(_ level: UInt8) async throws {
        let bcdLevel = BCDEncoding.encodePower(Int(level))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x02],
            data: bcdLevel
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("RF gain command rejected")
        }
    }

    /// Read RF gain level.
    ///
    /// **Command**: `0x14 0x02` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: Current gain level (0-255)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getRFGain() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x02],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }

    /// Set squelch level.
    ///
    /// Controls the squelch threshold for FM/AM modes.
    ///
    /// **Command**: `0x14 0x03 [level BCD]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 range)
    ///
    /// - Parameter level: Squelch threshold (0=open, 255=tight)
    /// - Throws: `RigError.commandFailed` if radio rejects the value
    public func setSquelch(_ level: UInt8) async throws {
        let bcdLevel = BCDEncoding.encodePower(Int(level))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x03],
            data: bcdLevel
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Squelch command rejected")
        }
    }

    /// Read squelch level.
    ///
    /// **Command**: `0x14 0x03` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: Current squelch threshold (0-255)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getSquelch() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x03],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }

    /// Set noise reduction (NR) level.
    ///
    /// Controls the strength of the digital noise reduction DSP filter.
    ///
    /// **Command**: `0x14 0x06 [level BCD]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 range)
    ///
    /// - Parameter level: NR strength (0=minimum, 255=maximum)
    /// - Throws: `RigError.commandFailed` if radio rejects the value
    ///
    /// - Note: NR must be enabled separately using `setNoiseReduction(true)`
    public func setNRLevel(_ level: UInt8) async throws {
        let bcdLevel = BCDEncoding.encodePower(Int(level))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x06],
            data: bcdLevel
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("NR level command rejected")
        }
    }

    /// Read noise reduction (NR) level.
    ///
    /// **Command**: `0x14 0x06` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: Current NR strength (0-255)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getNRLevel() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x06],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }

    /// Set CW pitch (sidetone frequency).
    ///
    /// Controls the frequency of the CW sidetone heard during transmission.
    ///
    /// **Command**: `0x14 0x09 [pitch BCD]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 range = 300-900Hz)
    ///
    /// - Parameter pitch: Pitch level (0=300Hz, 128=600Hz, 255=900Hz)
    /// - Throws: `RigError.commandFailed` if radio rejects the value
    public func setCWPitch(_ pitch: UInt8) async throws {
        let bcdPitch = BCDEncoding.encodePower(Int(pitch))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x09],
            data: bcdPitch
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("CW pitch command rejected")
        }
    }

    /// Read CW pitch (sidetone frequency).
    ///
    /// **Command**: `0x14 0x09` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: Current pitch level (0-255, mapping to 300-900Hz)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getCWPitch() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x09],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }

    /// Set RF power output level.
    ///
    /// Controls the transmitter power output.
    ///
    /// **Command**: `0x14 0x0A [power BCD]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 range)
    ///
    /// - Parameter level: Power level (0=minimum, 255=maximum)
    /// - Throws: `RigError.commandFailed` if radio rejects the value
    ///
    /// - Note: Actual power output depends on radio model (IC-7100: 100W, IC-7600: 100W, IC-9700: 100W HF)
    public func setRFPowerLevel(_ level: UInt8) async throws {
        let bcdLevel = BCDEncoding.encodePower(Int(level))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0A],
            data: bcdLevel
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("RF power level command rejected")
        }
    }

    /// Read RF power output level.
    ///
    /// **Command**: `0x14 0x0A` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: Current power level (0-255)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getRFPowerLevel() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0A],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }

    /// Set microphone gain level.
    ///
    /// Controls the microphone input gain for SSB/AM/FM transmit.
    ///
    /// **Command**: `0x14 0x0B [gain BCD]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 range)
    ///
    /// - Parameter gain: Gain level (0=minimum, 255=maximum)
    /// - Throws: `RigError.commandFailed` if radio rejects the value
    public func setMicGain(_ gain: UInt8) async throws {
        let bcdGain = BCDEncoding.encodePower(Int(gain))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0B],
            data: bcdGain
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("MIC gain command rejected")
        }
    }

    /// Read microphone gain level.
    ///
    /// **Command**: `0x14 0x0B` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: Current gain level (0-255)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getMicGain() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0B],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }

    /// Set CW keying speed.
    ///
    /// Controls the dot/dash timing for CW keying (WPM).
    ///
    /// **Command**: `0x14 0x0C [speed BCD]`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 range = 6-48 WPM)
    ///
    /// - Parameter speed: Speed level (0=6 WPM, 255=48 WPM)
    /// - Throws: `RigError.commandFailed` if radio rejects the value
    public func setKeySpeed(_ speed: UInt8) async throws {
        let bcdSpeed = BCDEncoding.encodePower(Int(speed))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0C],
            data: bcdSpeed
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Key speed command rejected")
        }
    }

    /// Read CW keying speed.
    ///
    /// **Command**: `0x14 0x0C` (read)
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical)
    ///
    /// - Returns: Current speed level (0-255, mapping to 6-48 WPM)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getKeySpeed() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0C],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }


}
