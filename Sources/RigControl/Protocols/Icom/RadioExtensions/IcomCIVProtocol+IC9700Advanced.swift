import Foundation

/// IC-9700 advanced features: power control, satellite mode, VFO operations, and helper methods
///
/// This extension contains advanced IC-9700-specific commands.
/// See `IcomCIVProtocol+IC9700.swift` for memory, scan, attenuator/preamp, voice synthesizer,
/// and level controls. See `IcomCIVProtocol+IC9700Controls.swift` for meter readings and
/// function settings.
extension IcomCIVProtocol {

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
    func bcdToFrequencyIC9700(_ bcd: [UInt8]) -> UInt64 {
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
