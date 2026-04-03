import Foundation

/// IC-7600 specific CI-V protocol implementation
///
/// This extension adds IC-7600-specific commands that differ from the common CI-V protocol.
/// Common commands shared across all Icom radios are in `IcomCIVProtocol+CommonCommands.swift`.
///
/// ## Key IC-7600 Characteristics:
/// - CI-V Address: 0x7A (default, user-configurable)
/// - VFO Model: .targetable (can specify VFO in commands)
/// - Command Echo: NO (radio does not echo commands)
/// - Mode Filter: YES (requires filter byte in mode commands)
/// - Dual Receiver: YES (Main and Sub bands)
/// - Power Display: Watts (actual power output)
///
/// ## IC-7600 Specific Features:
/// - Memory channels: 0-99
/// - Attenuator: 0dB, 6dB, 12dB, or 18dB
/// - Preamp: OFF, P.AMP1, P.AMP2
/// - AGC: FAST, MID, SLOW
/// - Dual receiver with band independent operation
/// - Advanced filter controls
/// - Extensive meter readings
///
/// ## Hardware Verification
/// All commands verified against IC-7600 CI-V manual (December 2025)
extension IcomCIVProtocol {

    // MARK: - Memory Operations (IC-7600 Specific)

    /// Select memory channel (IC-7600 specific: channels 0-99)
    /// Command: 0x08 [channel BCD]
    public func selectMemoryChannelIC7600(_ channel: Int) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("selectMemoryChannelIC7600 is only available on IC-7600")
        }
        guard channel >= 0 && channel <= 99 else {
            throw RigError.invalidParameter("Memory channel must be 0-99 for IC-7600")
        }
        // Encode channel number in BCD (2 bytes for 0-99)
        let hi = UInt8((channel / 10) << 4 | (channel % 10))
        let lo = UInt8(0x00)
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

    // MARK: - Scan Operations (IC-7600 Specific)

    /// Control scanning operations (IC-7600)
    /// Command: 0x0E [sub-command]
    public func setScanIC7600(_ mode: UInt8) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setScanIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.scan],
            data: [mode]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Scan command rejected")
        }
    }

    /// Stop scanning (IC-7600)
    public func stopScanIC7600() async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("stopScanIC7600 is only available on IC-7600")
        }
        try await setScanIC7600(CIVFrame.ScanCode.stop)
    }

    /// Start programmed scan (IC-7600)
    public func startProgrammedScanIC7600() async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("startProgrammedScanIC7600 is only available on IC-7600")
        }
        try await setScanIC7600(CIVFrame.ScanCode.programmed)
    }

    /// Start memory scan (IC-7600)
    public func startMemoryScanIC7600() async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("startMemoryScanIC7600 is only available on IC-7600")
        }
        try await setScanIC7600(CIVFrame.ScanCode.memory)
    }

    // MARK: - Attenuator & Preamp (IC-7600 Specific)

    /// Set attenuator (IC-7600 specific: 0dB, 6dB, 12dB, or 18dB)
    /// Command: 0x11 [attenuation value]
    /// - Parameter value: Attenuation in dB (0, 6, 12, or 18)
    public func setAttenuatorIC7600(_ value: UInt8) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setAttenuatorIC7600 is only available on IC-7600")
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

    /// Read attenuator setting (IC-7600)
    public func getAttenuatorIC7600() async throws -> UInt8 {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getAttenuatorIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.attenuator],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Attenuator command 0x11 is single-byte, no subcommand
        // IC-7600 returns: command=[11], data=[value]
        guard response.command.count >= 1,
              response.command[0] == CIVFrame.Command.attenuator,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    /// Select antenna (IC-7600)
    /// Command: 0x12 [antenna number]
    public func setAntennaIC7600(_ antenna: UInt8) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setAntennaIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.antenna],
            data: [antenna]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Antenna selection rejected")
        }
    }

    /// Read antenna selection (IC-7600)
    public func getAntennaIC7600() async throws -> UInt8 {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getAntennaIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.antenna],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 1,
              response.command[0] == CIVFrame.Command.antenna,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    /// Voice announcement (IC-7600)
    /// Command: 0x13 [announcement type]
    public func announceIC7600(_ type: UInt8) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("announceIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.announce],
            data: [type]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Announce command rejected")
        }
    }

    // MARK: - Level Controls (IC-7600 Specific, NOT in common)

    /// Set inner TWIN PBT (0-255) (IC-7600)
    /// Command: 0x14 0x07 [value BCD]
    public func setInnerPBTIC7600(_ value: Int) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setInnerPBTIC7600 is only available on IC-7600")
        }
        try await setLevelIC7600(CIVFrame.SettingsCode.innerPBT, value: value)
    }

    /// Read inner TWIN PBT (IC-7600)
    public func getInnerPBTIC7600() async throws -> Int {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getInnerPBTIC7600 is only available on IC-7600")
        }
        return try await getLevelIC7600(CIVFrame.SettingsCode.innerPBT)
    }

    /// Set outer TWIN PBT (0-255) (IC-7600)
    /// Command: 0x14 0x08 [value BCD]
    public func setOuterPBTIC7600(_ value: Int) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setOuterPBTIC7600 is only available on IC-7600")
        }
        try await setLevelIC7600(CIVFrame.SettingsCode.outerPBT, value: value)
    }

    /// Read outer TWIN PBT (IC-7600)
    public func getOuterPBTIC7600() async throws -> Int {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getOuterPBTIC7600 is only available on IC-7600")
        }
        return try await getLevelIC7600(CIVFrame.SettingsCode.outerPBT)
    }

    /// Set notch position (0-255) (IC-7600)
    /// Command: 0x14 0x0D [value BCD]
    public func setNotchPositionIC7600(_ value: Int) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setNotchPositionIC7600 is only available on IC-7600")
        }
        try await setLevelIC7600(CIVFrame.SettingsCode.notchPosition, value: value)
    }

    /// Read notch position (IC-7600)
    public func getNotchPositionIC7600() async throws -> Int {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getNotchPositionIC7600 is only available on IC-7600")
        }
        return try await getLevelIC7600(CIVFrame.SettingsCode.notchPosition)
    }

    /// Set compression level (0-255) (IC-7600)
    /// Command: 0x14 0x0E [value BCD]
    public func setCompLevelIC7600(_ value: Int) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setCompLevelIC7600 is only available on IC-7600")
        }
        try await setLevelIC7600(CIVFrame.SettingsCode.compLevel, value: value)
    }

    /// Read compression level (IC-7600)
    public func getCompLevelIC7600() async throws -> Int {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getCompLevelIC7600 is only available on IC-7600")
        }
        return try await getLevelIC7600(CIVFrame.SettingsCode.compLevel)
    }

    /// Set break-in delay (0-255) (IC-7600)
    /// Command: 0x14 0x0F [value BCD]
    public func setBreakInDelayIC7600(_ value: Int) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setBreakInDelayIC7600 is only available on IC-7600")
        }
        try await setLevelIC7600(CIVFrame.SettingsCode.breakInDelay, value: value)
    }

    /// Read break-in delay (IC-7600)
    public func getBreakInDelayIC7600() async throws -> Int {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getBreakInDelayIC7600 is only available on IC-7600")
        }
        return try await getLevelIC7600(CIVFrame.SettingsCode.breakInDelay)
    }

    /// Set balance (0-255) (IC-7600)
    /// Command: 0x14 0x11 [value BCD]
    public func setBalanceIC7600(_ value: Int) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setBalanceIC7600 is only available on IC-7600")
        }
        try await setLevelIC7600(CIVFrame.SettingsCode.balance, value: value)
    }

    /// Read balance (IC-7600)
    public func getBalanceIC7600() async throws -> Int {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getBalanceIC7600 is only available on IC-7600")
        }
        return try await getLevelIC7600(CIVFrame.SettingsCode.balance)
    }

    /// Set drive gain (0-255) (IC-7600)
    /// Command: 0x14 0x13 [value BCD]
    public func setDriveGainIC7600(_ value: Int) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setDriveGainIC7600 is only available on IC-7600")
        }
        try await setLevelIC7600(CIVFrame.SettingsCode.driveGain, value: value)
    }

    /// Read drive gain (IC-7600)
    public func getDriveGainIC7600() async throws -> Int {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getDriveGainIC7600 is only available on IC-7600")
        }
        return try await getLevelIC7600(CIVFrame.SettingsCode.driveGain)
    }

    /// Set brightness level (0-255) (IC-7600)
    /// Command: 0x14 0x18 [value BCD]
    public func setBrightLevelIC7600(_ value: Int) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setBrightLevelIC7600 is only available on IC-7600")
        }
        try await setLevelIC7600(CIVFrame.SettingsCode.brightLevel, value: value)
    }

    /// Read brightness level (IC-7600)
    public func getBrightLevelIC7600() async throws -> Int {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getBrightLevelIC7600 is only available on IC-7600")
        }
        return try await getLevelIC7600(CIVFrame.SettingsCode.brightLevel)
    }

    // MARK: - Meter Readings (IC-7600 Specific)

    /// Read squelch condition (IC-7600)
    /// Command: 0x15 0x01
    public func getSquelchConditionIC7600() async throws -> Bool {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getSquelchConditionIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.readLevel, CIVFrame.LevelRead.squelch],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-7600 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 3 {
            // IC-7600/IC-7100 format: command=[15], data=[01, value_bcd...]
            guard response.command[0] == CIVFrame.Command.readLevel,
                  response.data[0] == CIVFrame.LevelRead.squelch else {
                throw RigError.invalidResponse
            }
            return response.data[1] != 0x00
        } else if response.command.count >= 2 && response.data.count >= 2 {
            // Standard format: command=[15, 01], data=[value_bcd...]
            guard response.command[0] == CIVFrame.Command.readLevel,
                  response.command[1] == CIVFrame.LevelRead.squelch else {
                throw RigError.invalidResponse
            }
            return response.data[0] != 0x00
        } else {
            throw RigError.invalidResponse
        }
    }


}
