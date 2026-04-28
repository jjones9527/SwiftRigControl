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

    // MARK: - CATProtocol Conformance (Int-typed bridge)

    /// `CATProtocol` conformance — delegates to `setAFLevel(_:)` using `UInt8` clamping.
    public func setAFGain(_ level: Int) async throws {
        try await setAFLevel(UInt8(clamping: max(0, min(255, level))))
    }

    /// `CATProtocol` conformance — delegates to `getAFLevel()`.
    public func getAFGain() async throws -> Int {
        Int(try await getAFLevel())
    }

    /// `CATProtocol` conformance — delegates to `setRFGain(_:UInt8)` using `UInt8` clamping.
    public func setRFGain(_ level: Int) async throws {
        try await setRFGain(UInt8(clamping: max(0, min(255, level))))
    }

    /// `CATProtocol` conformance — delegates to `getRFGain() -> UInt8`.
    public func getRFGain() async throws -> Int {
        let raw: UInt8 = try await getRFGain()
        return Int(raw)
    }

    /// `CATProtocol` conformance — delegates to `setSquelch(_:UInt8)` using `UInt8` clamping.
    public func setSquelch(_ level: Int) async throws {
        try await setSquelch(UInt8(clamping: max(0, min(255, level))))
    }

    /// `CATProtocol` conformance — delegates to `getSquelch() -> UInt8`.
    public func getSquelch() async throws -> Int {
        let raw: UInt8 = try await getSquelch()
        return Int(raw)
    }

    // MARK: - Preamp (CATProtocol conformance)

    /// Sets the preamplifier stage via CI-V command `0x16 0x02`.
    ///
    /// - Parameter level: 0 = off, 1 = Preamp 1, 2 = Preamp 2
    public func setPreamp(_ level: Int) async throws {
        let code: UInt8
        switch level {
        case 0:  code = CIVFrame.PreampCode.off
        case 1:  code = CIVFrame.PreampCode.preamp1
        case 2:  code = CIVFrame.PreampCode.preamp2
        default: throw RigError.invalidParameter("Preamp level must be 0, 1, or 2")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.function, CIVFrame.FunctionCode.preamp],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else { throw RigError.commandFailed("Set preamp rejected") }
    }

    /// Gets the current preamplifier stage (0 = off, 1 = Preamp 1, 2 = Preamp 2).
    public func getPreamp() async throws -> Int {
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.function, CIVFrame.FunctionCode.preamp],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard let byte = response.data.first else { throw RigError.invalidResponse }
        switch byte {
        case CIVFrame.PreampCode.off:     return 0
        case CIVFrame.PreampCode.preamp1: return 1
        case CIVFrame.PreampCode.preamp2: return 2
        default: throw RigError.invalidResponse
        }
    }

    // MARK: - Attenuator (CATProtocol conformance)

    /// Sets the front-end attenuator via CI-V command `0x11`.
    ///
    /// - Parameter dB: 0 (off), 6, 12, or 18. Not all steps available on every model.
    public func setAttenuator(_ dB: Int) async throws {
        let code: UInt8
        switch dB {
        case 0:  code = CIVFrame.AttenuatorCode.off
        case 6:  code = CIVFrame.AttenuatorCode.dB6
        case 12: code = CIVFrame.AttenuatorCode.dB12
        case 18: code = CIVFrame.AttenuatorCode.dB18
        default: throw RigError.invalidParameter("Unsupported attenuator level: \(dB) dB")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.attenuator],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else { throw RigError.commandFailed("Set attenuator rejected") }
    }

    /// Gets the current attenuator level in dB (0 = off).
    public func getAttenuator() async throws -> Int {
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.attenuator],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard let byte = response.data.first else { throw RigError.invalidResponse }
        switch byte {
        case CIVFrame.AttenuatorCode.off:  return 0
        case CIVFrame.AttenuatorCode.dB6:  return 6
        case CIVFrame.AttenuatorCode.dB12: return 12
        case CIVFrame.AttenuatorCode.dB18: return 18
        default: throw RigError.invalidResponse
        }
    }

    // MARK: - Power State (CATProtocol conformance)

    /// Powers the radio on or places it in standby via CI-V command `0x18`.
    ///
    /// Most Icom radios support power-off (standby) via CI-V.
    /// Power-on via CI-V requires an active RS-232/CI-V connection and is model-dependent.
    public func setPowerState(_ on: Bool) async throws {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x18],
            data: [on ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        // Some radios don't ACK power-off (they power off immediately).
        // Attempt to read the response; ignore timeout for power-off.
        if let response = try? await receiveFrame(), response.isNak {
            throw RigError.commandFailed("Power state command rejected")
        }
    }

    /// Returns `true` if the radio is powered on by probing with a frequency read.
    ///
    /// A successful response means on; a timeout means off or in standby.
    public func getPowerState() async throws -> Bool {
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.readFrequency],
            data: []
        )
        do {
            try await sendFrame(frame)
            _ = try await receiveFrame()
            return true
        } catch RigError.timeout {
            return false
        }
    }

    // MARK: - CW Keyer Speed

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
