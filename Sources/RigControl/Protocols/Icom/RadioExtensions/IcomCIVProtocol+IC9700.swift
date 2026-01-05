import Foundation

/// IC-9700 specific CI-V protocol implementation
///
/// This extension adds IC-9700-specific commands that differ from the common CI-V protocol.
/// Common commands shared across all Icom radios are in `IcomCIVProtocol+CommonCommands.swift`.
///
/// ## Key IC-9700 Characteristics:
/// - CI-V Address: 0xA2 (default, user-configurable)
/// - VFO Model: .mainSub (Main and Sub bands with independent operation)
/// - Command Echo: YES (radio echoes commands before responses)
/// - Mode Filter: NO (does not require/accept filter byte in mode commands)
/// - Dual Receiver: YES (independent Main and Sub receivers)
/// - Power Display: Watts (actual power output)
/// - D-STAR: YES (digital voice and data)
/// - Satellite Mode: YES (full duplex operation for satellite contacts)
///
/// ## IC-9700 Specific Features:
/// - VHF/UHF/1.2GHz coverage (144/430/1200 MHz)
/// - Memory channels: 1-109 per band
/// - D-STAR digital voice (DV mode)
/// - Satellite mode with independent VFO tracking
/// - Attenuator: 0dB or 10dB
/// - Preamp: OFF or ON
/// - AGC: FAST, MID, SLOW, OFF
/// - Dual watch capability
/// - Spectrum scope
///
/// ## Hardware Verification
/// All commands verified against IC-9700 CI-V manual (December 2025)
extension IcomCIVProtocol {

    // MARK: - Memory Operations (IC-9700 Specific)

    /// Select memory channel (IC-9700 specific: channels 1-109 per band)
    /// Command: 0x08 [channel BCD]
    ///
    /// IC-9700 has extended memory channels per band:
    /// - 0001-0099: Standard memory channels
    /// - 0100: P1 (Program scan edge)
    /// - 0101: P2 (Program scan edge)
    /// - 0102: P3 (Program scan edge)
    /// - 0103: P4 (Program scan edge)
    /// - 0104: P5 (Program scan edge)
    /// - 0105: P6 (Program scan edge)
    /// - 0106-0109: Call channels
    public func selectMemoryChannelIC9700(_ channel: Int) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("selectMemoryChannelIC9700 is only available on IC-9700")
        }
        guard channel >= 1 && channel <= 109 else {
            throw RigError.invalidParameter("Memory channel must be 1-109 for IC-9700")
        }
        // Encode channel number in BCD (2 bytes)
        let lo = UInt8(channel % 10)
        let hi = UInt8((channel / 10) % 10) << 4 | UInt8((channel / 100))
        let channelBCD = [lo, hi]
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectMemory],
            data: channelBCD
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Memory channel \(channel) selection rejected")
        }
    }

    // MARK: - Scan Operations (IC-9700 Specific)

    /// Start programmed scan (IC-9700)
    /// Command: 0x0E 0x12
    public func startProgrammedScanIC9700() async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("startProgrammedScanIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.scan],
            data: [0x12]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Programmed scan command rejected")
        }
    }

    /// Start memory scan (IC-9700)
    /// Command: 0x0E 0x22
    public func startMemoryScanIC9700() async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("startMemoryScanIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.scan],
            data: [0x22]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Memory scan command rejected")
        }
    }

    /// Start select memory scan (IC-9700)
    /// Command: 0x0E 0x23
    public func startSelectMemoryScanIC9700() async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("startSelectMemoryScanIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.scan],
            data: [0x23]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Select memory scan command rejected")
        }
    }

    /// Set as select memory channel (IC-9700)
    /// Command: 0x0E 0xB1
    public func setSelectMemoryIC9700() async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setSelectMemoryIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.scan],
            data: [0xB1]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Select memory command rejected")
        }
    }

    /// Set as non-select memory channel (IC-9700)
    /// Command: 0x0E 0xB0
    public func setNonSelectMemoryIC9700() async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setNonSelectMemoryIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.scan],
            data: [0xB0]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Non-select memory command rejected")
        }
    }

    // MARK: - Attenuator & Preamp (IC-9700 Specific)

    /// Set attenuator (IC-9700 specific: 0dB or 10dB only)
    /// Command: 0x11 [attenuation value]
    /// Values: 0x00=OFF, 0x10=10dB
    public func setAttenuatorIC9700(_ value: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setAttenuatorIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.attenuator],
            data: [value]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Attenuator command rejected")
        }
    }

    /// Read attenuator setting (IC-9700)
    public func getAttenuatorIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getAttenuatorIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.attenuator],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 1, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    /// Set preamp (IC-9700 specific)
    /// Command: 0x16 0x02 [preamp code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setPreampIC9700(_ code: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setPreampIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x02],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Preamp command rejected")
        }
    }

    /// Read preamp setting (IC-9700)
    public func getPreampIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getPreampIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x02],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    // MARK: - Voice Synthesizer (IC-9700)

    /// Announce frequency, mode, and S-meter by voice (IC-9700)
    /// Command: 0x13 0x00
    public func announceFrequencyModeAndSignalIC9700() async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("announceFrequencyModeAndSignalIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x13, 0x00],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Voice announce command rejected")
        }
    }

    /// Announce frequency and S-meter by voice (IC-9700)
    /// Command: 0x13 0x01
    public func announceFrequencyAndSignalIC9700() async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("announceFrequencyAndSignalIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x13, 0x01],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Voice announce command rejected")
        }
    }

    /// Announce mode by voice (IC-9700)
    /// Command: 0x13 0x02
    public func announceModeIC9700() async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("announceModeIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x13, 0x02],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Voice announce command rejected")
        }
    }

    // MARK: - Level Controls (IC-9700 Specific)

    /// Set NR level (0-255) (IC-9700)
    /// Command: 0x14 0x06 [level BCD]
    public func setNRLevelIC9700(_ level: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setNRLevelIC9700 is only available on IC-9700")
        }
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

    /// Read NR level (IC-9700)
    public func getNRLevelIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getNRLevelIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x06],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-9700 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 3 {
            guard response.command[0] == 0x14, response.data[0] == 0x06 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(Array(response.data[1...])))
        } else if response.command.count >= 2 && response.data.count >= 2 {
            // Fallback to standard format
            guard response.command[0] == 0x14, response.command[1] == 0x06 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(response.data))
        } else {
            throw RigError.invalidResponse
        }
    }

    /// Set notch position (0-255) (IC-9700)
    /// Command: 0x14 0x0D [position BCD]
    public func setNotchPositionIC9700(_ position: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setNotchPositionIC9700 is only available on IC-9700")
        }
        let bcdPosition = BCDEncoding.encodePower(Int(position))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0D],
            data: bcdPosition
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Notch position command rejected")
        }
    }

    /// Read notch position (IC-9700)
    public func getNotchPositionIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getNotchPositionIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0D],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-9700 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 3 {
            guard response.command[0] == 0x14, response.data[0] == 0x0D else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(Array(response.data[1...])))
        } else if response.command.count >= 2 && response.data.count >= 2 {
            // Fallback to standard format
            guard response.command[0] == 0x14, response.command[1] == 0x0D else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(response.data))
        } else {
            throw RigError.invalidResponse
        }
    }

    /// Set monitor gain (0-255) (IC-9700)
    /// Command: 0x14 0x15 [gain BCD]
    public func setMonitorGainIC9700(_ gain: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setMonitorGainIC9700 is only available on IC-9700")
        }
        let bcdGain = BCDEncoding.encodePower(Int(gain))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x15],
            data: bcdGain
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Monitor gain command rejected")
        }
    }

    /// Read monitor gain (IC-9700)
    public func getMonitorGainIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getMonitorGainIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x15],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-9700 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 3 {
            guard response.command[0] == 0x14, response.data[0] == 0x15 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(Array(response.data[1...])))
        } else if response.command.count >= 2 && response.data.count >= 2 {
            // Fallback to standard format
            guard response.command[0] == 0x14, response.command[1] == 0x15 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(response.data))
        } else {
            throw RigError.invalidResponse
        }
    }

    /// Set VOX gain (0-255) (IC-9700)
    /// Command: 0x14 0x16 [gain BCD]
    public func setVoxGainIC9700(_ gain: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setVoxGainIC9700 is only available on IC-9700")
        }
        let bcdGain = BCDEncoding.encodePower(Int(gain))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x16],
            data: bcdGain
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("VOX gain command rejected")
        }
    }

    /// Read VOX gain (IC-9700)
    public func getVoxGainIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getVoxGainIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x16],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-9700 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 3 {
            guard response.command[0] == 0x14, response.data[0] == 0x16 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(Array(response.data[1...])))
        } else if response.command.count >= 2 && response.data.count >= 2 {
            // Fallback to standard format
            guard response.command[0] == 0x14, response.command[1] == 0x16 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(response.data))
        } else {
            throw RigError.invalidResponse
        }
    }

    /// Set anti-VOX gain (0-255) (IC-9700)
    /// Command: 0x14 0x17 [gain BCD]
    public func setAntiVoxGainIC9700(_ gain: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setAntiVoxGainIC9700 is only available on IC-9700")
        }
        let bcdGain = BCDEncoding.encodePower(Int(gain))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x17],
            data: bcdGain
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Anti-VOX gain command rejected")
        }
    }

    /// Read anti-VOX gain (IC-9700)
    public func getAntiVoxGainIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getAntiVoxGainIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x17],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-9700 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 3 {
            guard response.command[0] == 0x14, response.data[0] == 0x17 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(Array(response.data[1...])))
        } else if response.command.count >= 2 && response.data.count >= 2 {
            // Fallback to standard format
            guard response.command[0] == 0x14, response.command[1] == 0x17 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(response.data))
        } else {
            throw RigError.invalidResponse
        }
    }

    // MARK: - Meter Readings (IC-9700 Specific)

    /// Read squelch status (IC-9700)
    /// Command: 0x15 0x01
    /// Returns: 0x00=closed, 0x01=open
    public func getSquelchStatusIC9700() async throws -> Bool {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getSquelchStatusIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x15, 0x01],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Read PO meter level (IC-9700)
    /// Command: 0x15 0x11
    public func getPOMeterLevelIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getPOMeterLevelIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x15, 0x11],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-9700 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 3 {
            guard response.command[0] == 0x15, response.data[0] == 0x11 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(Array(response.data[1...])))
        } else if response.command.count >= 2 && response.data.count >= 2 {
            // Fallback to standard format
            guard response.command[0] == 0x15, response.command[1] == 0x11 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(response.data))
        } else {
            throw RigError.invalidResponse
        }
    }

    // MARK: - Function Settings (IC-9700 Specific)

    /// Set AGC (IC-9700)
    /// Command: 0x16 0x12 [AGC code]
    /// Codes: 0x00=OFF, 0x01=FAST, 0x02=MID, 0x03=SLOW
    public func setAGCIC9700(_ code: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setAGCIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x12],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("AGC command rejected")
        }
    }

    /// Read AGC setting (IC-9700)
    public func getAGCIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getAGCIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x12],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    /// Set monitor function (IC-9700)
    /// Command: 0x16 0x45 [MON code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setMonitorIC9700(_ enabled: Bool) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setMonitorIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x45],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Monitor command rejected")
        }
    }

    /// Read monitor function setting (IC-9700)
    public func getMonitorIC9700() async throws -> Bool {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getMonitorIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x45],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Set manual notch (IC-9700)
    /// Command: 0x16 0x48 [notch code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setManualNotchIC9700(_ enabled: Bool) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setManualNotchIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x48],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Manual notch command rejected")
        }
    }

    /// Read manual notch setting (IC-9700)
    public func getManualNotchIC9700() async throws -> Bool {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getManualNotchIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x48],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Set dial lock (IC-9700)
    /// Command: 0x16 0x50 [lock code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setDialLockIC9700(_ enabled: Bool) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setDialLockIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x50],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Dial lock command rejected")
        }
    }

    /// Read dial lock setting (IC-9700)
    public func getDialLockIC9700() async throws -> Bool {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getDialLockIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x50],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Set DSQL/CSQL (DV mode only) - IC-9700 specific
    /// Command: 0x16 0x5B [squelch code]
    /// Codes: 0x00=OFF, 0x01=DSQL ON, 0x02=CSQL ON
    public func setDigitalSquelchIC9700(_ code: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setDigitalSquelchIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x5B],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Digital squelch command rejected")
        }
    }

    /// Read DSQL/CSQL setting (DV mode only) (IC-9700)
    public func getDigitalSquelchIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getDigitalSquelchIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x5B],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    // MARK: - Power Control (IC-9700)

    /// Turn OFF the transceiver (IC-9700)
    /// Command: 0x18 0x00
    public func powerOffIC9700() async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("powerOffIC9700 is only available on IC-9700")
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

    /// Turn ON the transceiver (IC-9700)
    /// Command: Multiple 0xFE preambles + 0x18 0x01
    public func powerOnIC9700() async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("powerOnIC9700 is only available on IC-9700")
        }
        // IC-9700 requires multiple 0xFE preambles before the command
        // Number depends on baud rate: 115200bps=150
        var preambles = [UInt8](repeating: 0xFE, count: 150)  // Default for 115200 bps
        preambles.append(contentsOf: [0xFE, civAddress, 0xE0, 0x18, 0x01, 0xFD])

        try await transport.write(Data(preambles))
        // Wait for response
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
    }

    // MARK: - Satellite Mode (IC-9700 Unique Feature)

    /// Set satellite mode ON/OFF (IC-9700 unique)
    /// Command: 0x16 0x5A [SAT code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setSatelliteModeIC9700(_ enabled: Bool) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setSatelliteModeIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x5A],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Satellite mode command rejected")
        }
    }

    /// Read satellite mode setting (IC-9700 unique)
    public func getSatelliteModeIC9700() async throws -> Bool {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getSatelliteModeIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x5A],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    // MARK: - VFO Operations (IC-9700 Specific)

    /// Exchange main/sub bands (IC-9700)
    /// Command: 0x07 0xB0
    public func exchangeBandsIC9700() async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("exchangeBandsIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectVFO],
            data: [0xB0]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Exchange bands rejected")
        }
    }

    /// Equalize main/sub bands (IC-9700)
    /// Command: 0x07 0xB1
    public func equalizeBandsIC9700() async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("equalizeBandsIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectVFO],
            data: [0xB1]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Equalize bands rejected")
        }
    }

    /// Set dualwatch (IC-9700)
    /// Command: 0x07 [dualwatch code]
    /// Codes: 0xC2=OFF, 0xC3=ON
    public func setDualwatchIC9700(_ enabled: Bool) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setDualwatchIC9700 is only available on IC-9700")
        }
        let code: UInt8 = enabled ? 0xC3 : 0xC2
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectVFO],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Dualwatch command rejected")
        }
    }

    // MARK: - Selected/Unselected VFO (IC-9700)

    /// Read selected or unselected VFO frequency (IC-9700)
    /// Command: 0x25 [VFO selector]
    /// VFO: 0x00=Selected VFO, 0x01=Unselected VFO
    public func readVFOFrequencyIC9700(_ vfoSelector: UInt8) async throws -> UInt64 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("readVFOFrequencyIC9700 is only available on IC-9700")
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
        return bcdToFrequencyIC9700(Array(response.data.dropFirst()))
    }

    /// Read selected or unselected VFO mode (IC-9700)
    /// Command: 0x26 [VFO selector]
    /// VFO: 0x00=Selected VFO, 0x01=Unselected VFO
    public func readVFOModeIC9700(_ vfoSelector: UInt8) async throws -> (mode: Mode, dataMode: Bool, filter: UInt8) {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("readVFOModeIC9700 is only available on IC-9700")
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
        case CIVFrame.ModeCode.fm: mode = .fm
        case 0x17: mode = .dataUSB  // DV mode on IC-9700
        default: mode = .usb  // Default fallback
        }
        return (mode, dataMode, filter)
    }

    // MARK: - Helper Methods (IC-9700)

    /// Convert BCD format (5 bytes) to frequency in Hz (IC-9700)
    private func bcdToFrequencyIC9700(_ bcd: [UInt8]) -> UInt64 {
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
}
