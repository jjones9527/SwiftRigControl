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

    // MARK: - Function Controls (IC-7600 Specific)

    /// Set preamp (IC-7600)
    /// - Parameter value: 0=OFF, 1=P.AMP1, 2=P.AMP2
    public func setPreampIC7600(_ value: UInt8) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setPreampIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.preamp, value: value)
    }

    /// Read preamp setting (IC-7600)
    public func getPreampIC7600() async throws -> UInt8 {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getPreampIC7600 is only available on IC-7600")
        }
        return try await getFunctionIC7600(CIVFrame.FunctionCode.preamp)
    }

    /// Set AGC (IC-7600)
    /// - Parameter value: 1=FAST, 2=MID, 3=SLOW
    public func setAGCIC7600(_ value: UInt8) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setAGCIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.agc, value: value)
    }

    /// Read AGC setting (IC-7600)
    public func getAGCIC7600() async throws -> UInt8 {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getAGCIC7600 is only available on IC-7600")
        }
        return try await getFunctionIC7600(CIVFrame.FunctionCode.agc)
    }

    /// Set audio peak filter (IC-7600)
    /// - Parameter enabled: true=ON, false=OFF
    public func setAudioPeakFilterIC7600(_ enabled: Bool) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setAudioPeakFilterIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.audioPeakFilter, value: enabled ? 0x01 : 0x00)
    }

    /// Read audio peak filter setting (IC-7600)
    public func getAudioPeakFilterIC7600() async throws -> Bool {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getAudioPeakFilterIC7600 is only available on IC-7600")
        }
        let value = try await getFunctionIC7600(CIVFrame.FunctionCode.audioPeakFilter)
        return value != 0x00
    }

    /// Set monitor (IC-7600)
    /// - Parameter enabled: true=ON, false=OFF
    public func setMonitorIC7600(_ enabled: Bool) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setMonitorIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.monitor, value: enabled ? 0x01 : 0x00)
    }

    /// Read monitor setting (IC-7600)
    public func getMonitorIC7600() async throws -> Bool {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getMonitorIC7600 is only available on IC-7600")
        }
        let value = try await getFunctionIC7600(CIVFrame.FunctionCode.monitor)
        return value != 0x00
    }

    /// Set break-in (IC-7600)
    /// - Parameter enabled: true=ON, false=OFF
    public func setBreakInIC7600(_ enabled: Bool) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setBreakInIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.breakIn, value: enabled ? 0x01 : 0x00)
    }

    /// Read break-in setting (IC-7600)
    public func getBreakInIC7600() async throws -> Bool {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getBreakInIC7600 is only available on IC-7600")
        }
        let value = try await getFunctionIC7600(CIVFrame.FunctionCode.breakIn)
        return value != 0x00
    }

    /// Set manual notch (IC-7600)
    /// - Parameter enabled: true=ON, false=OFF
    public func setManualNotchIC7600(_ enabled: Bool) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setManualNotchIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.manualNotch, value: enabled ? 0x01 : 0x00)
    }

    /// Read manual notch setting (IC-7600)
    public func getManualNotchIC7600() async throws -> Bool {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getManualNotchIC7600 is only available on IC-7600")
        }
        let value = try await getFunctionIC7600(CIVFrame.FunctionCode.manualNotch)
        return value != 0x00
    }

    /// Set twin peak filter (IC-7600)
    /// - Parameter enabled: true=ON, false=OFF
    public func setTwinPeakFilterIC7600(_ enabled: Bool) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setTwinPeakFilterIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.twinPeakFilter, value: enabled ? 0x01 : 0x00)
    }

    /// Read twin peak filter setting (IC-7600)
    public func getTwinPeakFilterIC7600() async throws -> Bool {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getTwinPeakFilterIC7600 is only available on IC-7600")
        }
        let value = try await getFunctionIC7600(CIVFrame.FunctionCode.twinPeakFilter)
        return value != 0x00
    }

    /// Set dial lock (IC-7600)
    /// - Parameter enabled: true=ON, false=OFF
    public func setDialLockIC7600(_ enabled: Bool) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setDialLockIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.dialLock, value: enabled ? 0x01 : 0x00)
    }

    /// Read dial lock setting (IC-7600)
    public func getDialLockIC7600() async throws -> Bool {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getDialLockIC7600 is only available on IC-7600")
        }
        let value = try await getFunctionIC7600(CIVFrame.FunctionCode.dialLock)
        return value != 0x00
    }

    // MARK: - Advanced Settings (IC-7600 Specific)

    /// Set filter width (IC-7600)
    /// Command: 0x1A 0x03 [filter index 0-49]
    public func setFilterWidthIC7600(_ index: UInt8) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setFilterWidthIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, CIVFrame.AdvancedCode.filterWidth],
            data: [index]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Filter width command rejected")
        }
    }

    /// Read filter width (IC-7600)
    public func getFilterWidthIC7600() async throws -> UInt8 {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getFilterWidthIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, CIVFrame.AdvancedCode.filterWidth],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-7600 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 2 {
            // IC-7600/IC-7100 format: command=[1A], data=[03, value]
            guard response.command[0] == CIVFrame.Command.advancedSettings,
                  response.data[0] == CIVFrame.AdvancedCode.filterWidth else {
                throw RigError.invalidResponse
            }
            return response.data[1]
        } else if response.command.count >= 2 && !response.data.isEmpty {
            // Standard format: command=[1A, 03], data=[value]
            guard response.command[0] == CIVFrame.Command.advancedSettings,
                  response.command[1] == CIVFrame.AdvancedCode.filterWidth else {
                throw RigError.invalidResponse
            }
            return response.data[0]
        } else {
            throw RigError.invalidResponse
        }
    }

    /// Set AGC time constant (IC-7600)
    /// Command: 0x1A 0x04 [time constant 0-13]
    public func setAGCTimeConstantIC7600(_ value: UInt8) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setAGCTimeConstantIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, CIVFrame.AdvancedCode.agcTimeConstant],
            data: [value]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("AGC time constant command rejected")
        }
    }

    /// Read AGC time constant (IC-7600)
    public func getAGCTimeConstantIC7600() async throws -> UInt8 {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getAGCTimeConstantIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, CIVFrame.AdvancedCode.agcTimeConstant],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2,
              response.command[0] == CIVFrame.Command.advancedSettings,
              response.command[1] == CIVFrame.AdvancedCode.agcTimeConstant,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    // MARK: - VFO Extended Commands (IC-7600 Specific)

    /// Exchange main/sub bands (IC-7600)
    /// Command: 0x07 0xB0
    public func exchangeBandsIC7600() async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("exchangeBandsIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectVFO],
            data: [CIVFrame.VFOSelect.exchangeBands]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Exchange bands rejected")
        }
    }

    /// Equalize main/sub bands (IC-7600)
    /// Command: 0x07 0xB1
    public func equalizeBandsIC7600() async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("equalizeBandsIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectVFO],
            data: [CIVFrame.VFOSelect.equalizeBands]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Equalize bands rejected")
        }
    }

    /// Set dualwatch (IC-7600)
    /// - Parameter enabled: true=ON, false=OFF
    public func setDualwatchIC7600(_ enabled: Bool) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setDualwatchIC7600 is only available on IC-7600")
        }
        let code = enabled ? CIVFrame.VFOSelect.dualwatchOn : CIVFrame.VFOSelect.dualwatchOff
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

    // MARK: - Miscellaneous Commands (IC-7600 Specific)

    /// Read band edge frequencies (IC-7600)
    /// Command: 0x02
    public func getBandEdgeIC7600() async throws -> (lower: UInt64, upper: UInt64) {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getBandEdgeIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.readBandEdge],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 1,
              response.command[0] == CIVFrame.Command.readBandEdge,
              response.data.count >= 10 else {
            throw RigError.invalidResponse
        }
        let lowerFreq = try BCDEncoding.decodeFrequency(Array(response.data[0..<5]))
        let upperFreq = try BCDEncoding.decodeFrequency(Array(response.data[5..<10]))
        return (lowerFreq, upperFreq)
    }

    // MARK: - Helper Methods (IC-7600 Specific)

    /// Set a level control value (IC-7600 internal helper)
    /// Command: 0x14 [sub-command] [value BCD]
    private func setLevelIC7600(_ subCommand: UInt8, value: Int) async throws {
        let clampedValue = min(max(value, 0), 255)
        let bcd = BCDEncoding.encodePower(clampedValue)
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.settings, subCommand],
            data: bcd
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Level control command rejected")
        }
    }

    /// Read a level control value (IC-7600 internal helper)
    private func getLevelIC7600(_ subCommand: UInt8) async throws -> Int {
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.settings, subCommand],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-7600 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 3 {
            // IC-7600/IC-7100 format: command=[14], data=[subCommand, value_bcd...]
            guard response.command[0] == CIVFrame.Command.settings,
                  response.data[0] == subCommand else {
                throw RigError.invalidResponse
            }
            return BCDEncoding.decodePower(Array(response.data[1...]))
        } else if response.command.count >= 2 && response.data.count >= 2 {
            // Standard format: command=[14, subCommand], data=[value_bcd...]
            guard response.command[0] == CIVFrame.Command.settings,
                  response.command[1] == subCommand else {
                throw RigError.invalidResponse
            }
            return BCDEncoding.decodePower(response.data)
        } else {
            throw RigError.invalidResponse
        }
    }

    /// Set a function on/off or to a specific value (IC-7600 internal helper)
    /// Command: 0x16 [sub-command] [value]
    private func setFunctionIC7600(_ subCommand: UInt8, value: UInt8) async throws {
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.function, subCommand],
            data: [value]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Function control command rejected")
        }
    }

    /// Read a function setting (IC-7600 internal helper)
    private func getFunctionIC7600(_ subCommand: UInt8) async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.function, subCommand],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-7600 may return subcommand in data field like IC-7100: command=[16], data=[subCommand value]
        // OR standard format: command=[16 subCommand], data=[value]

        if response.command.count == 1 && response.data.count == 2 {
            // IC-7600 format: subcommand in first data byte, value in second
            guard response.command[0] == CIVFrame.Command.function,
                  response.data[0] == subCommand else {
                throw RigError.invalidResponse
            }
            return response.data[1]
        } else if response.command.count >= 2 && response.data.count >= 1 {
            // Standard format: subcommand in command field
            guard response.command[0] == CIVFrame.Command.function,
                  response.command[1] == subCommand else {
                throw RigError.invalidResponse
            }
            return response.data[0]
        } else {
            throw RigError.invalidResponse
        }
    }

    // MARK: - DATA Mode Control (IC-7600 Specific)

    /// Set DATA mode and filter (IC-7600)
    /// Command: 0x1A 0x06 [data_mode][filter]
    ///
    /// - Parameters:
    ///   - dataMode: 0x00=OFF, 0x01=D1, 0x02=D2, 0x03=D3
    ///   - filter: 0x00=OFF, 0x01=FIL1, 0x02=FIL2, 0x03=FIL3
    public func setDataModeIC7600(dataMode: UInt8, filter: UInt8) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setDataModeIC7600 is only available on IC-7600")
        }
        guard dataMode <= 0x03 else {
            throw RigError.invalidParameter("Data mode must be 0x00-0x03")
        }
        guard filter <= 0x03 else {
            throw RigError.invalidParameter("Filter must be 0x00-0x03")
        }

        let frame = CIVFrame(
            to: civAddress,
            command: [0x1A, 0x06],
            data: [dataMode, filter]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("DATA mode command rejected")
        }
    }

    /// Get current DATA mode and filter setting (IC-7600)
    /// Returns tuple: (dataMode: 0x00-0x03, filter: 0x00-0x03)
    public func getDataModeIC7600() async throws -> (dataMode: UInt8, filter: UInt8) {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getDataModeIC7600 is only available on IC-7600")
        }

        let frame = CIVFrame(
            to: civAddress,
            command: [0x1A, 0x06],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.command.count >= 2,
              response.command[0] == 0x1A,
              response.command[1] == 0x06,
              response.data.count == 2 else {
            throw RigError.invalidResponse
        }

        return (dataMode: response.data[0], filter: response.data[1])
    }
}
