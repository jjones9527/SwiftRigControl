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

        // Debug logging
        print("DEBUG [getPreampIC9700]: Response received")
        print("  Command bytes: \(response.command.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
        print("  Data bytes: \(response.data.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
        print("  Command count: \(response.command.count), Data count: \(response.data.count)")

        // IC-9700 returns: command=[0x16], data=[0x02, value]
        // The subcommand is in the data field, not command field!
        guard response.command.count == 1,
              response.command[0] == 0x16,
              response.data.count == 2,
              response.data[0] == 0x02 else {
            print("  ERROR: Invalid response format")
            throw RigError.invalidResponse
        }
        return response.data[1]  // Value is second byte in data
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


}
