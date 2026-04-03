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
/// - Attenuator: OFF (0x00) or ON/12dB (0x12) only - no 6dB or 24dB
/// - Preamp: OFF (0x00) or ON/P.AMP1 (0x01) only - no P.AMP2
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

        // Command 0x11 is a single-byte command (no subcommand)
        // Standard format: command=[11], data=[value]
        guard response.command.count >= 1, response.data.count >= 1 else {
            throw RigError.invalidResponse
        }
        guard response.command[0] == CIVFrame.Command.attenuator else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    /// Set preamp (IC-7100 specific)
    /// Command: 0x16 0x02 [preamp code]
    /// Codes: 0x00=OFF, 0x01=ON/P.AMP1 (P.AMP2 not supported on IC-7100)
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

}
