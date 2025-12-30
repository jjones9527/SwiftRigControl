import Foundation

/// IC-7100 specific CI-V protocol implementation
///
/// This extension adds IC-7100-specific commands that differ from the common CI-V protocol.
/// Common commands shared across all Icom radios are in `IcomCIVProtocol+CommonCommands.swift`.
///
/// ## Key IC-7100 Characteristics:
/// - CI-V Address: 0x88 (default, user-configurable)
/// - VFO Model: .currentOnly (must switch VFO before operations)
/// - Command Echo: YES (radio echoes commands before responses)
/// - Mode Filter: NO (does not require/accept filter byte in mode commands)
/// - Power Display: Percentage (0-100%), NOT watts
/// - DV Mode Support: YES (D-STAR digital voice)
/// - GPS Support: YES (built-in GPS)
/// - Multi-band: HF/VHF/UHF (0.030-470 MHz)
///
/// ## IC-7100 Specific Features:
/// - Memory channels: 1-109 (includes special channels for VHF/UHF)
/// - Memory banks: A-E
/// - Attenuator: 0dB or 12dB only
/// - Preamp: OFF, P.AMP1 (HF/50MHz), P.AMP2 (HF/50MHz), ON (144/430MHz)
/// - D-STAR digital voice (DV mode)
/// - DTCS and VSC squelch systems
/// - Built-in GPS
///
/// ## Hardware Verification
/// All commands verified against IC-7100 CI-V manual (December 2025)
extension IcomCIVProtocol {

    // MARK: - Memory Operations (IC-7100 Specific)

    /// Select memory channel (IC-7100 specific: channels 1-109)
    /// Command: 0x08 [channel BCD]
    ///
    /// IC-7100 has extended memory channels:
    /// - 0001-0099: Standard memory channels (M-CH01 to M-CH99)
    /// - 0100: 1A (Program scan edge)
    /// - 0101: 1B (Program scan edge)
    /// - 0102: 2A (Program scan edge)
    /// - 0103: 2B (Program scan edge)
    /// - 0104: 3A (Program scan edge)
    /// - 0105: 3B (Program scan edge)
    /// - 0106: 144-C1 (144MHz call channel)
    /// - 0107: 144-C2 (144MHz call channel)
    /// - 0108: 430-C1 (430MHz call channel)
    /// - 0109: 430-C2 (430MHz call channel)
    public func selectMemoryChannelIC7100(_ channel: Int) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("selectMemoryChannelIC7100 is only available on IC-7100")
        }
        guard channel >= 1 && channel <= 109 else {
            throw RigError.invalidParameter("Memory channel must be 1-109 for IC-7100")
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

    /// Select memory bank (IC-7100 specific: banks A-E)
    /// Command: 0x08 0xA0 [bank]
    /// Banks: 01=A, 02=B, 03=C, 04=D, 05=E
    public func selectMemoryBankIC7100(_ bank: Int) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("selectMemoryBankIC7100 is only available on IC-7100")
        }
        guard bank >= 1 && bank <= 5 else {
            throw RigError.invalidParameter("Memory bank must be 1-5 (A-E)")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectMemory, 0xA0],
            data: [UInt8(bank)]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Memory bank selection rejected")
        }
    }

    // MARK: - Offset Frequency (0x0C-0x0D)

    /// Read offset frequency (IC-7100)
    /// Command: 0x0C
    public func getOffsetFrequencyIC7100() async throws -> UInt64 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getOffsetFrequencyIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x0C],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 1, response.data.count == 5 else {
            throw RigError.invalidResponse
        }
        return bcdToFrequencyIC7100(response.data)
    }

    /// Send offset frequency (IC-7100)
    /// Command: 0x0D [freq BCD]
    public func setOffsetFrequencyIC7100(_ hz: UInt64) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setOffsetFrequencyIC7100 is only available on IC-7100")
        }
        let bcd = frequencyToBCDIC7100(hz)
        let frame = CIVFrame(
            to: civAddress,
            command: [0x0D],
            data: bcd
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Offset frequency command rejected")
        }
    }

    // MARK: - Scan Operations (IC-7100 Specific Variants)

    /// Start ΔF scan (IC-7100 specific)
    /// Command: 0x0E 0x03
    public func startDeltaFScanIC7100() async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("startDeltaFScanIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.scan],
            data: [0x03]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("ΔF scan command rejected")
        }
    }

    /// Start fine programmed scan (IC-7100 specific)
    /// Command: 0x0E 0x12
    public func startFineProgrammedScanIC7100() async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("startFineProgrammedScanIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.scan],
            data: [0x12]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Fine programmed scan command rejected")
        }
    }

    /// Start select memory scan (IC-7100 specific)
    /// Command: 0x0E 0x23
    public func startSelectMemoryScanIC7100() async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("startSelectMemoryScanIC7100 is only available on IC-7100")
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

    /// Start mode select scan (IC-7100 specific)
    /// Command: 0x0E 0x24
    public func startModeSelectScanIC7100() async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("startModeSelectScanIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.scan],
            data: [0x24]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Mode select scan command rejected")
        }
    }

    /// Set ΔF scan span (IC-7100 specific)
    /// Command: 0x0E [span code]
    /// Spans: 0xA1=±5kHz, 0xA2=±10kHz, 0xA3=±20kHz, 0xA4=±50kHz,
    ///        0xA5=±100kHz, 0xA6=±500kHz, 0xA7=±1MHz
    public func setDeltaFScanSpanIC7100(_ spanCode: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setDeltaFScanSpanIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.scan],
            data: [spanCode]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("ΔF scan span command rejected")
        }
    }

    /// Set as non-select memory channel (IC-7100)
    /// Command: 0x0E 0xB0
    public func setNonSelectMemoryIC7100() async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setNonSelectMemoryIC7100 is only available on IC-7100")
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

    /// Set as select memory channel (IC-7100)
    /// Command: 0x0E 0xB1
    public func setSelectMemoryIC7100() async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setSelectMemoryIC7100 is only available on IC-7100")
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

    /// Set scan resume OFF (IC-7100)
    /// Command: 0x0E 0xD0
    public func setScanResumeOffIC7100() async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setScanResumeOffIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.scan],
            data: [0xD0]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Scan resume OFF command rejected")
        }
    }

    /// Set scan resume ON (IC-7100)
    /// Command: 0x0E 0xD3
    public func setScanResumeOnIC7100() async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setScanResumeOnIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.scan],
            data: [0xD3]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Scan resume ON command rejected")
        }
    }

    // MARK: - Split Operation (IC-7100 Specific)

    /// Read split operation status (IC-7100)
    /// Command: 0x0F
    /// Returns: 0x00=Split OFF, 0x01=Split ON, 0x10=Simplex, 0x11=DUP-, 0x12=DUP+
    public func readSplitStatusIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("readSplitStatusIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.split],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 1, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    // MARK: - Attenuator & Preamp (IC-7100 Specific)

    /// Set attenuator (IC-7100 specific: 0dB or 12dB only)
    /// Command: 0x11 [attenuation value]
    /// Values: 0x00=OFF, 0x12=12dB
    public func setAttenuatorIC7100(_ value: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setAttenuatorIC7100 is only available on IC-7100")
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

    /// Read attenuator setting (IC-7100)
    public func getAttenuatorIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getAttenuatorIC7100 is only available on IC-7100")
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

    /// Set preamp (IC-7100 specific)
    /// Command: 0x16 0x02 [preamp code]
    /// Codes: 0x00=OFF, 0x01=ON (144/430MHz) or P.AMP1 (HF/50MHz), 0x02=P.AMP2 (HF/50MHz)
    public func setPreampIC7100(_ code: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setPreampIC7100 is only available on IC-7100")
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

    /// Read preamp setting (IC-7100)
    public func getPreampIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getPreampIC7100 is only available on IC-7100")
        }
        return try await getFunctionIC7100(0x02)
    }

    // MARK: - Voice Synthesizer (0x13)

    /// Announce frequency, mode, and S-meter by voice (IC-7100)
    /// Command: 0x13 0x00
    public func announceFrequencyModeAndSignalIC7100() async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("announceFrequencyModeAndSignalIC7100 is only available on IC-7100")
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

    /// Announce frequency and S-meter by voice (IC-7100)
    /// Command: 0x13 0x01
    public func announceFrequencyAndSignalIC7100() async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("announceFrequencyAndSignalIC7100 is only available on IC-7100")
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

    /// Announce mode by voice (IC-7100)
    /// Command: 0x13 0x02
    public func announceModeIC7100() async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("announceModeIC7100 is only available on IC-7100")
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

    // MARK: - Level Controls (IC-7100 Specific, NOT in common)

    /// Set inner Twin PBT position (0-255) (IC-7100)
    /// Command: 0x14 0x07 [position BCD]
    /// Position: 0=Cut higher, 128=center, 255=Cut lower
    public func setInnerPBTIC7100(_ position: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setInnerPBTIC7100 is only available on IC-7100")
        }
        let bcdPosition = [UInt8(position % 10) | (UInt8(position / 10) << 4), UInt8(position / 100)]
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x07],
            data: bcdPosition
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Inner PBT command rejected")
        }
    }

    /// Read inner Twin PBT position (IC-7100)
    public func getInnerPBTIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getInnerPBTIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x07],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let lo = response.data[0] & 0x0F
        let hi = (response.data[0] >> 4) * 10
        let hund = response.data[1] * 100
        return hund + hi + lo
    }

    /// Set outer Twin PBT position (0-255) (IC-7100)
    /// Command: 0x14 0x08 [position BCD]
    public func setOuterPBTIC7100(_ position: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setOuterPBTIC7100 is only available on IC-7100")
        }
        let bcdPosition = [UInt8(position % 10) | (UInt8(position / 10) << 4), UInt8(position / 100)]
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x08],
            data: bcdPosition
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Outer PBT command rejected")
        }
    }

    /// Read outer Twin PBT position (IC-7100)
    public func getOuterPBTIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getOuterPBTIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x08],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let lo = response.data[0] & 0x0F
        let hi = (response.data[0] >> 4) * 10
        let hund = response.data[1] * 100
        return hund + hi + lo
    }

    /// Set notch position (0-255) (IC-7100)
    /// Command: 0x14 0x0D [position BCD]
    /// Position: 0=lowest, 128=center, 255=highest
    public func setNotchPositionIC7100(_ position: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setNotchPositionIC7100 is only available on IC-7100")
        }
        let bcdPosition = [UInt8(position % 10) | (UInt8(position / 10) << 4), UInt8(position / 100)]
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

    /// Read notch position (IC-7100)
    public func getNotchPositionIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getNotchPositionIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0D],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let lo = response.data[0] & 0x0F
        let hi = (response.data[0] >> 4) * 10
        let hund = response.data[1] * 100
        return hund + hi + lo
    }

    /// Set compression level (0-255) (IC-7100)
    /// Command: 0x14 0x0E [level BCD]
    /// Level: 0=0, 255=10
    public func setCompLevelIC7100(_ level: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setCompLevelIC7100 is only available on IC-7100")
        }
        let bcdLevel = [UInt8(level % 10) | (UInt8(level / 10) << 4), UInt8(level / 100)]
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0E],
            data: bcdLevel
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Compression level command rejected")
        }
    }

    /// Read compression level (IC-7100)
    public func getCompLevelIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getCompLevelIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0E],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let lo = response.data[0] & 0x0F
        let hi = (response.data[0] >> 4) * 10
        let hund = response.data[1] * 100
        return hund + hi + lo
    }

    /// Set break-in delay (0-255) (IC-7100)
    /// Command: 0x14 0x0F [delay BCD]
    /// Delay: 0=2.0d, 255=13.0d
    public func setBreakInDelayIC7100(_ delay: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setBreakInDelayIC7100 is only available on IC-7100")
        }
        let bcdDelay = [UInt8(delay % 10) | (UInt8(delay / 10) << 4), UInt8(delay / 100)]
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0F],
            data: bcdDelay
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Break-in delay command rejected")
        }
    }

    /// Read break-in delay (IC-7100)
    public func getBreakInDelayIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getBreakInDelayIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0F],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let lo = response.data[0] & 0x0F
        let hi = (response.data[0] >> 4) * 10
        let hund = response.data[1] * 100
        return hund + hi + lo
    }

    /// Set NB level (0-255) (IC-7100)
    /// Command: 0x14 0x12 [level BCD]
    public func setNBLevelIC7100(_ level: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setNBLevelIC7100 is only available on IC-7100")
        }
        let bcdLevel = [UInt8(level % 10) | (UInt8(level / 10) << 4), UInt8(level / 100)]
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x12],
            data: bcdLevel
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("NB level command rejected")
        }
    }

    /// Read NB level (IC-7100)
    public func getNBLevelIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getNBLevelIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x12],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let lo = response.data[0] & 0x0F
        let hi = (response.data[0] >> 4) * 10
        let hund = response.data[1] * 100
        return hund + hi + lo
    }

    /// Set monitor gain (0-255) (IC-7100)
    /// Command: 0x14 0x15 [gain BCD]
    public func setMonitorGainIC7100(_ gain: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setMonitorGainIC7100 is only available on IC-7100")
        }
        let bcdGain = [UInt8(gain % 10) | (UInt8(gain / 10) << 4), UInt8(gain / 100)]
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

    /// Read monitor gain (IC-7100)
    public func getMonitorGainIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getMonitorGainIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x15],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let lo = response.data[0] & 0x0F
        let hi = (response.data[0] >> 4) * 10
        let hund = response.data[1] * 100
        return hund + hi + lo
    }

    /// Set VOX gain (0-255) (IC-7100)
    /// Command: 0x14 0x16 [gain BCD]
    public func setVoxGainIC7100(_ gain: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setVoxGainIC7100 is only available on IC-7100")
        }
        let bcdGain = [UInt8(gain % 10) | (UInt8(gain / 10) << 4), UInt8(gain / 100)]
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

    /// Read VOX gain (IC-7100)
    public func getVoxGainIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getVoxGainIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x16],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let lo = response.data[0] & 0x0F
        let hi = (response.data[0] >> 4) * 10
        let hund = response.data[1] * 100
        return hund + hi + lo
    }

    /// Set anti-VOX gain (0-255) (IC-7100)
    /// Command: 0x14 0x17 [gain BCD]
    public func setAntiVoxGainIC7100(_ gain: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setAntiVoxGainIC7100 is only available on IC-7100")
        }
        let bcdGain = [UInt8(gain % 10) | (UInt8(gain / 10) << 4), UInt8(gain / 100)]
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

    /// Read anti-VOX gain (IC-7100)
    public func getAntiVoxGainIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getAntiVoxGainIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x17],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let lo = response.data[0] & 0x0F
        let hi = (response.data[0] >> 4) * 10
        let hund = response.data[1] * 100
        return hund + hi + lo
    }

    /// Set LCD contrast (0-255) (IC-7100)
    /// Command: 0x14 0x18 [contrast BCD]
    public func setLCDContrastIC7100(_ contrast: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setLCDContrastIC7100 is only available on IC-7100")
        }
        let bcdContrast = [UInt8(contrast % 10) | (UInt8(contrast / 10) << 4), UInt8(contrast / 100)]
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x18],
            data: bcdContrast
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("LCD contrast command rejected")
        }
    }

    /// Read LCD contrast (IC-7100)
    public func getLCDContrastIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getLCDContrastIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x18],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let lo = response.data[0] & 0x0F
        let hi = (response.data[0] >> 4) * 10
        let hund = response.data[1] * 100
        return hund + hi + lo
    }

    /// Set LCD backlight (0-255) (IC-7100)
    /// Command: 0x14 0x19 [backlight BCD]
    public func setLCDBacklightIC7100(_ backlight: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setLCDBacklightIC7100 is only available on IC-7100")
        }
        let bcdBacklight = [UInt8(backlight % 10) | (UInt8(backlight / 10) << 4), UInt8(backlight / 100)]
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x19],
            data: bcdBacklight
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("LCD backlight command rejected")
        }
    }

    /// Read LCD backlight (IC-7100)
    public func getLCDBacklightIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getLCDBacklightIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x19],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let lo = response.data[0] & 0x0F
        let hi = (response.data[0] >> 4) * 10
        let hund = response.data[1] * 100
        return hund + hi + lo
    }

    // MARK: - Meter Readings (IC-7100 Specific, NOT in common)

    /// Read squelch status (IC-7100)
    /// Command: 0x15 0x01
    /// Returns: 0x00=closed, 0x01=open
    public func getSquelchStatusIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getSquelchStatusIC7100 is only available on IC-7100")
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

    /// Read various SQL function status (IC-7100)
    /// Command: 0x15 0x05
    /// Returns: 0x00=closed, 0x01=open
    public func getVariousSQLStatusIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getVariousSQLStatusIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x15, 0x05],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Read PO meter level (IC-7100)
    /// Command: 0x15 0x11
    /// Returns: 0000=0%, 0143=50%, 0213=100%
    public func getPOMeterLevelIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getPOMeterLevelIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x15, 0x11],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        let lo = response.data[0] & 0x0F
        let hi = (response.data[0] >> 4) * 10
        let hund = response.data[1] * 100
        return hund + hi + lo
    }

    // MARK: - Function Settings (IC-7100 Specific, NOT in common)

    /// Set AGC (IC-7100)
    /// Command: 0x16 0x12 [AGC code]
    /// Codes: 0x01=FAST, 0x02=MID, 0x03=SLOW
    public func setAGCIC7100(_ code: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setAGCIC7100 is only available on IC-7100")
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

    /// Read AGC setting (IC-7100)
    public func getAGCIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getAGCIC7100 is only available on IC-7100")
        }
        return try await getFunctionIC7100(0x12)
    }

    /// Set monitor function (IC-7100)
    /// Command: 0x16 0x45 [MON code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setMonitorIC7100(_ enabled: Bool) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setMonitorIC7100 is only available on IC-7100")
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

    /// Read monitor function setting (IC-7100)
    public func getMonitorIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getMonitorIC7100 is only available on IC-7100")
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

    /// Set break-in function (IC-7100)
    /// Command: 0x16 0x47 [BK-IN code]
    /// Codes: 0x00=OFF, 0x01=Semi BK-IN, 0x02=Full BK-IN
    public func setBreakInIC7100(_ code: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setBreakInIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x47],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Break-in command rejected")
        }
    }

    /// Read break-in function setting (IC-7100)
    public func getBreakInIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getBreakInIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x47],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    /// Set manual notch (IC-7100)
    /// Command: 0x16 0x48 [notch code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setManualNotchIC7100(_ enabled: Bool) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setManualNotchIC7100 is only available on IC-7100")
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

    /// Read manual notch setting (IC-7100)
    public func getManualNotchIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getManualNotchIC7100 is only available on IC-7100")
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

    /// Set DTCS (IC-7100 specific)
    /// Command: 0x16 0x4B [DTCS code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setDTCSIC7100(_ enabled: Bool) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setDTCSIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x4B],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("DTCS command rejected")
        }
    }

    /// Read DTCS setting (IC-7100)
    public func getDTCSIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getDTCSIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x4B],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Set VSC (Voice Squelch Control) - IC-7100 specific
    /// Command: 0x16 0x4C [VSC code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setVSCIC7100(_ enabled: Bool) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setVSCIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x4C],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("VSC command rejected")
        }
    }

    /// Read VSC setting (IC-7100)
    public func getVSCIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getVSCIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x4C],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Set twin peak filter (IC-7100)
    /// Command: 0x16 0x4F [TPF code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setTwinPeakFilterIC7100(_ enabled: Bool) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setTwinPeakFilterIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x4F],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Twin peak filter command rejected")
        }
    }

    /// Read twin peak filter setting (IC-7100)
    public func getTwinPeakFilterIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getTwinPeakFilterIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x4F],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Set dial lock (IC-7100)
    /// Command: 0x16 0x50 [lock code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setDialLockIC7100(_ enabled: Bool) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setDialLockIC7100 is only available on IC-7100")
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

    /// Read dial lock setting (IC-7100)
    public func getDialLockIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getDialLockIC7100 is only available on IC-7100")
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

    /// Set DSP filter type (IC-7100)
    /// Command: 0x16 0x56 [filter code]
    /// Codes: 0x00=SHARP, 0x01=SOFT
    public func setDSPFilterTypeIC7100(_ code: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setDSPFilterTypeIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x56],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("DSP filter type command rejected")
        }
    }

    /// Read DSP filter type setting (IC-7100)
    public func getDSPFilterTypeIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getDSPFilterTypeIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x56],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    /// Set manual notch width (IC-7100)
    /// Command: 0x16 0x57 [width code]
    /// Codes: 0x00=WIDE, 0x01=MID, 0x02=NAR
    public func setManualNotchWidthIC7100(_ code: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setManualNotchWidthIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x57],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Manual notch width command rejected")
        }
    }

    /// Read manual notch width setting (IC-7100)
    public func getManualNotchWidthIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getManualNotchWidthIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x57],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    /// Set SSB transmit bandwidth (IC-7100)
    /// Command: 0x16 0x58 [bandwidth code]
    /// Codes: 0x00=WIDE, 0x01=MID, 0x02=NAR
    public func setSSBTransmitBandwidthIC7100(_ code: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setSSBTransmitBandwidthIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x58],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("SSB transmit bandwidth command rejected")
        }
    }

    /// Read SSB transmit bandwidth setting (IC-7100)
    public func getSSBTransmitBandwidthIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getSSBTransmitBandwidthIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x58],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    /// Set DSQL/CSQL (DV mode only) - IC-7100 specific
    /// Command: 0x16 0x5B [squelch code]
    /// Codes: 0x00=OFF, 0x01=DSQL ON, 0x02=CSQL ON
    public func setDigitalSquelchIC7100(_ code: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setDigitalSquelchIC7100 is only available on IC-7100")
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

    /// Read DSQL/CSQL setting (DV mode only) (IC-7100)
    public func getDigitalSquelchIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getDigitalSquelchIC7100 is only available on IC-7100")
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
        guard response.command.count >= 2, response.data.count == 3 else {
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
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
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
    private func frequencyToBCDIC7100(_ hz: UInt64) -> [UInt8] {
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
    private func bcdToFrequencyIC7100(_ bcd: [UInt8]) -> UInt64 {
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
    private func getFunctionIC7100(_ subCommand: UInt8) async throws -> UInt8 {
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
    private func getLevelIC7100(_ subCommand: UInt8) async throws -> Int {
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
    private func getAdvancedSettingIC7100(_ subCommand: UInt8) async throws -> UInt8 {
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
    private func getReadLevelIC7100(_ subCommand: UInt8) async throws -> Bool {
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
